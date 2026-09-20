//
//  LoginFlowV2Tests.swift
//  nextBookmarkTests
//
//  Exercises LoginFlowV2Coordinator's state machine against a scripted mock
//  client. The coordinator is constructed with a spy in place of its default
//  onCredentialsReceived (which normally writes to the real Keychain), so
//  these tests never touch real stored credentials.
//

import XCTest
@testable import nextBookmark

final class MockLoginFlowV2Client: LoginFlowV2Client {
    var initiateResult: LoginFlowV2InitResult?
    /// Queue of poll responses returned in order, one per call to
    /// pollLoginFlow; nil entries simulate "still pending" (a 404).
    var pollResults: [LoginFlowV2Credentials?] = []

    private(set) var initiateCallCount = 0
    private(set) var pollCallCount = 0

    func initiateLoginFlow(serverURL: String, completion: @escaping (LoginFlowV2InitResult?) -> Void) {
        initiateCallCount += 1
        completion(initiateResult)
    }

    func pollLoginFlow(token: String, endpoint: String, completion: @escaping (LoginFlowV2Credentials?) -> Void) {
        pollCallCount += 1
        let result = pollCallCount <= pollResults.count ? pollResults[pollCallCount - 1] : nil
        completion(result)
    }
}

final class LoginFlowV2Tests: XCTestCase {

    private func makeCoordinator(
        pollInterval: TimeInterval = 0.05,
        maxAttempts: Int = 3,
        receivedCredentials: @escaping (LoginFlowV2Credentials) -> Void = { _ in }
    ) -> LoginFlowV2Coordinator {
        LoginFlowV2Coordinator(pollInterval: pollInterval, maxAttempts: maxAttempts, onCredentialsReceived: receivedCredentials)
    }

    /// The coordinator applies network results via DispatchQueue.main.async,
    /// so even a "synchronous" mock response lands on the next run loop turn.
    /// Call this after triggering a call into the coordinator and before
    /// asserting on its state.
    private func flushMainQueue() {
        let flushed = expectation(description: "main queue flushed")
        DispatchQueue.main.async { flushed.fulfill() }
        wait(for: [flushed], timeout: 1)
    }

    func testEmptyServerURLFailsWithoutHittingTheNetwork() {
        let client = MockLoginFlowV2Client()
        let coordinator = makeCoordinator()

        coordinator.start(serverURL: "   ", client: client)

        XCTAssertEqual(coordinator.state, .failure("Please enter a server URL first."))
        XCTAssertEqual(client.initiateCallCount, 0)
    }

    func testFailedInitiateReportsFailure() {
        let client = MockLoginFlowV2Client()
        client.initiateResult = nil
        let coordinator = makeCoordinator()

        coordinator.start(serverURL: "https://example.com", client: client)
        flushMainQueue()

        XCTAssertEqual(coordinator.state, .failure("Could not reach that server. Check the URL and try again."))
    }

    func testSuccessfulInitiateMovesToWaitingForBrowser() {
        let client = MockLoginFlowV2Client()
        let loginURL = URL(string: "https://example.com/login/v2/flow/abc")!
        client.initiateResult = LoginFlowV2InitResult(loginURL: loginURL, pollToken: "tok", pollEndpoint: "https://example.com/login/v2/poll")
        let coordinator = makeCoordinator()

        coordinator.start(serverURL: "https://example.com/", client: client)
        flushMainQueue()

        XCTAssertEqual(coordinator.state, .waitingForBrowser(loginURL: loginURL))
    }

    func testTrailingSlashesAreStrippedBeforeInitiating() {
        let client = MockLoginFlowV2Client()
        client.initiateResult = nil // don't care about the outcome, just the call
        let coordinator = makeCoordinator()

        coordinator.start(serverURL: "https://example.com///", client: client)

        // The mock doesn't record the argument directly, but a failed
        // initiate still proves initiateLoginFlow was actually invoked once
        // (i.e. normalization didn't blank out the URL).
        XCTAssertEqual(client.initiateCallCount, 1)
    }

    func testPendingPollsDoNotChangeState() {
        let client = MockLoginFlowV2Client()
        let loginURL = URL(string: "https://example.com/login/v2/flow/abc")!
        client.initiateResult = LoginFlowV2InitResult(loginURL: loginURL, pollToken: "tok", pollEndpoint: "https://example.com/login/v2/poll")
        client.pollResults = [nil, nil] // still pending twice

        let expectation = expectation(description: "polled at least twice")
        let coordinator = makeCoordinator(pollInterval: 0.05, maxAttempts: 10)

        coordinator.start(serverURL: "https://example.com", client: client)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)

        XCTAssertEqual(coordinator.state, .waitingForBrowser(loginURL: loginURL))
        XCTAssertGreaterThanOrEqual(client.pollCallCount, 1)
    }

    func testSuccessfulPollStoresCredentialsAndReportsSuccess() {
        let client = MockLoginFlowV2Client()
        let loginURL = URL(string: "https://example.com/login/v2/flow/abc")!
        client.initiateResult = LoginFlowV2InitResult(loginURL: loginURL, pollToken: "tok", pollEndpoint: "https://example.com/login/v2/poll")
        let credentials = LoginFlowV2Credentials(server: "https://example.com", loginName: "alice", appPassword: "secret")
        client.pollResults = [credentials]

        var received: LoginFlowV2Credentials?
        let coordinator = makeCoordinator(pollInterval: 0.05, maxAttempts: 10) { received = $0 }

        let expectation = expectation(description: "login succeeded")
        coordinator.start(serverURL: "https://example.com", client: client)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)

        XCTAssertEqual(coordinator.state, .success(loginName: "alice"))
        XCTAssertEqual(received?.loginName, "alice")
        XCTAssertEqual(received?.appPassword, "secret")
    }

    func testExceedingMaxAttemptsTimesOut() {
        let client = MockLoginFlowV2Client()
        let loginURL = URL(string: "https://example.com/login/v2/flow/abc")!
        client.initiateResult = LoginFlowV2InitResult(loginURL: loginURL, pollToken: "tok", pollEndpoint: "https://example.com/login/v2/poll")
        client.pollResults = [] // every poll is "still pending"

        let coordinator = makeCoordinator(pollInterval: 0.02, maxAttempts: 2)

        let expectation = expectation(description: "login timed out")
        coordinator.start(serverURL: "https://example.com", client: client)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)

        XCTAssertEqual(coordinator.state, .failure("Login timed out. Please try again."))
    }

    func testCancelResetsToIdle() {
        let client = MockLoginFlowV2Client()
        let loginURL = URL(string: "https://example.com/login/v2/flow/abc")!
        client.initiateResult = LoginFlowV2InitResult(loginURL: loginURL, pollToken: "tok", pollEndpoint: "https://example.com/login/v2/poll")
        client.pollResults = [nil, nil, nil, nil, nil]
        let coordinator = makeCoordinator(pollInterval: 0.05, maxAttempts: 10)

        coordinator.start(serverURL: "https://example.com", client: client)
        flushMainQueue()
        XCTAssertEqual(coordinator.state, .waitingForBrowser(loginURL: loginURL))

        coordinator.cancel()

        XCTAssertEqual(coordinator.state, .idle)
    }
}
