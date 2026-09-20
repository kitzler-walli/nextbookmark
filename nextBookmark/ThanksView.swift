//
//  ThanksView.swift
//  nextBookmark
//
//  Created by Kai on 24.02.20.
//  Copyright © 2020 Kai. All rights reserved.
//
//  Pushed from SettingsView, which already provides the enclosing
//  NavigationView (BookmarksView's, at the root) — this view must not wrap
//  itself in another one, or the navigation bar ends up with two back
//  buttons instead of one.
//

import SwiftUI

struct ThanksView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image("AboutAppIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(radius: 1)

                Text("nextBookmark")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("An open-source iOS client for Nextcloud Bookmarks.", comment: "About screen tagline under the app name")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 8) {
                    Text("Feedback, Issues, Features, Code?...")
                    Button(action: {
                        openURL("https://github.com/kitzler-walli/nextbookmark")
                    }) {
                        Text("Visit me!")
                    }
                }

                Button(action: {
                    openURL("https://github.com/kitzler-walli/nextbookmark/blob/master/privacy_policy.md")
                }) {
                    Text("Privacy Policy")
                }

                VStack(spacing: 8) {
                    Text("Originally created by Kai, the original maintainer.", comment: "About screen credit for the app's original author")
                        .multilineTextAlignment(.center)
                    Button(action: {
                        openURL("https://gitlab.com/altepizza/nextbookmark")
                    }) {
                        Text("Original Project", comment: "Link label to the original maintainer's project")
                    }
                }
                .padding(.top)

                Spacer()

                VStack {
                    Text("Also thanks to...")
                    Button(action: {
                        openURL("https://github.com/Alamofire/Alamofire")
                    }) {
                        Text("Alamofire")
                    }

                    Button(action: {
                        openURL("https://nextcloud.com/")
                    }) {
                        Text("Nextcloud")
                    }

                    Button(action: {
                        openURL("https://github.com/nextcloud/bookmarks")
                    }) {
                        Text("Nextcloud Bookmarks")
                    }

                    Button(action: {
                        openURL("https://github.com/Daltron/NotificationBanner")
                    }) {
                        Text("NotificationBanner")
                    }

                    Button(action: {
                        openURL("https://github.com/siteline/SwiftUIRefresh")
                    }) {
                        Text("SwiftUI-Refresh")
                    }

                    Button(action: {
                        openURL("https://github.com/SwiftyJSON/SwiftyJSON")
                    }) {
                        Text("SwiftyJSON")
                    }
                }.padding()
            }
            .padding()
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func openURL(_ string: String) {
        guard let url = URL(string: string) else { return }
        UIApplication.shared.open(url)
    }
}



struct ThanksView_Previews: PreviewProvider {
    static var previews: some View {
        ThanksView()
    }
}
