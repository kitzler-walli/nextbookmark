//
//  SettingsView.swift
//  nextBookmark
//
//  Created by Kai on 20.10.19.
//  Copyright © 2019 Kai. All rights reserved.
//

import SwiftUI
import Alamofire
import Combine

let sharedUserDefaults = UserDefaults(suiteName: SharedUserDefaults.suiteName)


struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State var server = sharedUserDefaults?.string(forKey: SharedUserDefaults.Keys.url) ?? ""
    @State var username = ""
    @State var password = ""
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var dismissOnAlertOK = false

    @StateObject private var loginCoordinator = LoginFlowV2Coordinator()
    @State private var isLoggedIn = CredentialsStore.isLoggedIn
    @State private var loggedInAs = CredentialsStore.loginName
    @State private var showManualLogin = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nextcloud URL")
                            .font(.headline)
                        TextField("https://your-nextcloud.instance", text: $server)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }

                    if isLoggedIn {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Connected as \(loggedInAs ?? "?")")
                                .font(.headline)
                            Button(action: logOut) {
                                Text("Log Out")
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.red)
                                    .cornerRadius(10)
                            }
                        }
                    } else {
                        Button(action: {
                            loginCoordinator.start(serverURL: server, client: NextcloudLoginFlowClient())
                        }) {
                            Text("Log In With Nextcloud")
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                    }

                    Button(action: { showManualLogin.toggle() }) {
                        Text(showManualLogin ? "Hide manual login" : "Or log in with username & password")
                            .font(.footnote)
                    }

                    if showManualLogin {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Nextcloud Username")
                                .font(.headline)
                            TextField("Username", text: $username)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Nextcloud Password")
                                .font(.headline)
                            SecureField("Password", text: $password)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }

                        Button(action: {
                            self.saveManualSettings()
                        }) {
                            Text("Save And Test Settings")
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        .padding(.top, 20)
                    }
                }
                .padding()
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: ThanksView()) {
                        Text("About")
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK") {
                if dismissOnAlertOK {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: Binding(
            get: {
                if case .waitingForBrowser = loginCoordinator.state { return true }
                return false
            },
            set: { isPresented in
                if !isPresented { loginCoordinator.cancel() }
            }
        )) {
            if case .waitingForBrowser(let loginURL) = loginCoordinator.state {
                SafariView(url: loginURL)
            }
        }
        .onChange(of: loginCoordinator.state) { _, newState in
            switch newState {
            case .success(let loginName):
                isLoggedIn = true
                loggedInAs = loginName
                alertTitle = NSLocalizedString("✅ Success", comment: "Alert title after successfully connecting to Nextcloud")
                alertMessage = String(format: NSLocalizedString("Successfully connected to Nextcloud Bookmarks as %@! Bookmarks will now load automatically.", comment: "Alert message after Login Flow v2 succeeds, %@ is the Nextcloud username"), loginName)
                dismissOnAlertOK = true
                showingAlert = true
                NotificationCenter.default.post(name: Notification.Name("SettingsUpdated"), object: nil)
                loginCoordinator.cancel()
            case .failure(let message):
                alertTitle = NSLocalizedString("❌ Login Failed", comment: "Alert title when Login Flow v2 fails")
                alertMessage = message
                dismissOnAlertOK = false
                showingAlert = true
                loginCoordinator.cancel()
            case .idle, .waitingForBrowser:
                break
            }
        }
    }

    func logOut() {
        CredentialsStore.clear()
        isLoggedIn = false
        loggedInAs = nil
        NotificationCenter.default.post(name: Notification.Name("SettingsUpdated"), object: nil)
    }

    func saveManualSettings() {
        sharedUserDefaults?.set(server, forKey: SharedUserDefaults.Keys.url)
        hello_world()
    }

    func hello_world() {
        print("DEBUG: Testing connection to Nextcloud...")

        let headers: HTTPHeaders = [
            .authorization(username: self.username, password: self.password),
            .accept("application/json")
        ]

        AF.request(self.server + "/index.php/apps/bookmarks/public/rest/v2/bookmark?page=0", headers: headers)
            .validate(statusCode: 200..<300)
            .responseJSON { response in
                DispatchQueue.main.async {
                    switch response.result {
                    case .success( _):
                        print("DEBUG: Connection test successful")

                        CredentialsStore.save(server: self.server, loginName: self.username, appPassword: self.password)
                        self.isLoggedIn = true
                        self.loggedInAs = self.username
                        self.password = ""

                        self.alertTitle = NSLocalizedString("✅ Success", comment: "Alert title after successfully connecting to Nextcloud")
                        self.alertMessage = NSLocalizedString("Successfully connected to Nextcloud Bookmarks! Your settings have been saved and bookmarks will now load automatically.", comment: "Alert message after manually testing/saving Nextcloud settings succeeds")
                        self.dismissOnAlertOK = true
                        self.showingAlert = true

                        NotificationCenter.default.post(name: Notification.Name("SettingsUpdated"), object: nil)

                    case .failure(let error):
                        print("ERROR: Connection test failed: \(error)")

                        self.alertTitle = NSLocalizedString("❌ Connection Failed", comment: "Alert title when the manual Nextcloud settings test fails")
                        self.alertMessage = NSLocalizedString("Cannot connect to Nextcloud Bookmarks.\n\nPlease check:\n• Server URL is correct\n• Username and password are valid\n• Network connection is available", comment: "Alert message when the manual Nextcloud settings test fails")
                        self.dismissOnAlertOK = false
                        self.showingAlert = true
                    }
                }
            }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(server: "defaultURL", username: "defaultUser", password: "defaultPassword")
    }
}
