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
    @State var server = sharedUserDefaults?.string(forKey: SharedUserDefaults.Keys.url) ?? ""
    @State var username = sharedUserDefaults?.string(forKey: SharedUserDefaults.Keys.username) ?? ""
    @State var password = sharedUserDefaults?.string(forKey: SharedUserDefaults.Keys.password) ?? ""
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

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
                        self.saveSettings()
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
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    func saveSettings() {
        sharedUserDefaults?.set(server, forKey: SharedUserDefaults.Keys.url)
        sharedUserDefaults?.set(username, forKey: SharedUserDefaults.Keys.username)
        sharedUserDefaults?.set(password, forKey: SharedUserDefaults.Keys.password)
        hello_world()
        
        // Post notification to refresh bookmarks view
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            NotificationCenter.default.post(name: Notification.Name("SettingsUpdated"), object: nil)
        }
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
                        
                        self.alertTitle = "✅ Success"
                        self.alertMessage = "Successfully connected to Nextcloud Bookmarks! Your settings have been saved and bookmarks will now load automatically."
                        self.showingAlert = true
                        
                        sharedUserDefaults?.set(true, forKey: SharedUserDefaults.Keys.valid)
                        
                    case .failure(let error):
                        print("ERROR: Connection test failed: \(error)")
                        
                        self.alertTitle = "❌ Connection Failed"
                        self.alertMessage = "Cannot connect to Nextcloud Bookmarks.\n\nPlease check:\n• Server URL is correct\n• Username and password are valid\n• Network connection is available"
                        self.showingAlert = true
                        
                        sharedUserDefaults?.set(false, forKey: SharedUserDefaults.Keys.valid)
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
