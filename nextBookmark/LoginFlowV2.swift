//
//  LoginFlowV2.swift
//  nextBookmark
//
//  Nextcloud "Login Flow v2": the app asks the server for a login URL and a
//  poll token, opens that URL in a real browser (never an embedded WKWebView
//  — Nextcloud blocks those for login flow as a phishing protection) so the
//  user authenticates on the server itself (2FA and all), then polls until
//  the server hands back a scoped app password.
//  https://docs.nextcloud.com/server/latest/developer_manual/client_apis/LoginFlow/index.html
//

import Foundation
import Alamofire

struct LoginFlowV2InitResult {
    let loginURL: URL
    let pollToken: String
    let pollEndpoint: String
}

struct LoginFlowV2Credentials {
    let server: String
    let loginName: String
    let appPassword: String
}

/// What LoginFlowV2Coordinator needs from the network. Lets tests script the
/// whole flow (including "still pending") without a real server.
protocol LoginFlowV2Client {
    func initiateLoginFlow(serverURL: String, completion: @escaping (LoginFlowV2InitResult?) -> Void)
    /// `completion(nil)` means "not done yet" (the server returns 404 while
    /// the user hasn't finished logging in) as well as any real error —
    /// both cases mean the coordinator should just keep polling.
    func pollLoginFlow(token: String, endpoint: String, completion: @escaping (LoginFlowV2Credentials?) -> Void)
}

struct NextcloudLoginFlowClient: LoginFlowV2Client {
    private struct InitResponse: Decodable {
        struct Poll: Decodable { let token: String; let endpoint: String }
        let poll: Poll
        let login: String
    }

    private struct PollResponse: Decodable {
        let server: String
        let loginName: String
        let appPassword: String
    }

    func initiateLoginFlow(serverURL: String, completion: @escaping (LoginFlowV2InitResult?) -> Void) {
        AF.request(serverURL + "/index.php/login/v2", method: .post)
            .validate(statusCode: 200..<300)
            .responseDecodable(of: InitResponse.self) { response in
                guard let value = response.value, let loginURL = URL(string: value.login) else {
                    completion(nil)
                    return
                }
                completion(LoginFlowV2InitResult(loginURL: loginURL, pollToken: value.poll.token, pollEndpoint: value.poll.endpoint))
            }
    }

    func pollLoginFlow(token: String, endpoint: String, completion: @escaping (LoginFlowV2Credentials?) -> Void) {
        AF.request(endpoint, method: .post, parameters: ["token": token], encoding: URLEncoding.default)
            .validate(statusCode: 200..<300)
            .responseDecodable(of: PollResponse.self) { response in
                completion(response.value.map {
                    LoginFlowV2Credentials(server: $0.server, loginName: $0.loginName, appPassword: $0.appPassword)
                })
            }
    }
}

final class LoginFlowV2Coordinator: ObservableObject {
    enum State: Equatable {
        case idle
        case waitingForBrowser(loginURL: URL)
        case success(loginName: String)
        case failure(String)
    }

    @Published private(set) var state: State = .idle

    private let pollInterval: TimeInterval
    private let maxAttempts: Int
    /// Where successful credentials get persisted. Defaults to the real
    /// Keychain-backed store; tests inject a no-op/spy instead so they don't
    /// touch whatever account is actually logged in on the test host.
    private let onCredentialsReceived: (LoginFlowV2Credentials) -> Void
    private var pollToken: String?
    private var pollEndpoint: String?
    private var pollTimer: Timer?
    private var attempts = 0

    init(
        pollInterval: TimeInterval = 2,
        maxAttempts: Int = 300,
        onCredentialsReceived: @escaping (LoginFlowV2Credentials) -> Void = { credentials in
            CredentialsStore.save(server: credentials.server, loginName: credentials.loginName, appPassword: credentials.appPassword)
        }
    ) {
        self.pollInterval = pollInterval
        self.maxAttempts = maxAttempts
        self.onCredentialsReceived = onCredentialsReceived
    }

    func start(serverURL: String, client: LoginFlowV2Client) {
        let normalized = Self.normalize(serverURL)
        guard !normalized.isEmpty else {
            state = .failure(NSLocalizedString("Please enter a server URL first.", comment: "Login Flow v2 error when the server URL field is empty"))
            return
        }

        client.initiateLoginFlow(serverURL: normalized) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                guard let result = result else {
                    self.state = .failure(NSLocalizedString("Could not reach that server. Check the URL and try again.", comment: "Login Flow v2 error when initiating the login flow fails"))
                    return
                }
                self.pollToken = result.pollToken
                self.pollEndpoint = result.pollEndpoint
                self.state = .waitingForBrowser(loginURL: result.loginURL)
                self.beginPolling(client: client)
            }
        }
    }

    /// Called when the user dismisses the login browser sheet themselves,
    /// or after a terminal success/failure state to reset for next time.
    func cancel() {
        pollTimer?.invalidate()
        pollTimer = nil
        pollToken = nil
        pollEndpoint = nil
        if state != .idle {
            state = .idle
        }
    }

    private static func normalize(_ url: String) -> String {
        var trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        return trimmed
    }

    private func beginPolling(client: LoginFlowV2Client) {
        attempts = 0
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.poll(client: client)
        }
    }

    private func poll(client: LoginFlowV2Client) {
        guard let token = pollToken, let endpoint = pollEndpoint else { return }

        attempts += 1
        if attempts > maxAttempts {
            pollTimer?.invalidate()
            pollTimer = nil
            state = .failure(NSLocalizedString("Login timed out. Please try again.", comment: "Login Flow v2 error after polling exceeds the maximum attempts"))
            return
        }

        client.pollLoginFlow(token: token, endpoint: endpoint) { [weak self] credentials in
            DispatchQueue.main.async {
                guard let self = self, let credentials = credentials else { return } // still pending
                self.pollTimer?.invalidate()
                self.pollTimer = nil
                self.onCredentialsReceived(credentials)
                self.state = .success(loginName: credentials.loginName)
            }
        }
    }
}
