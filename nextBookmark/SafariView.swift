//
//  SafariView.swift
//  nextBookmark
//
//  Wraps SFSafariViewController so the Login Flow v2 URL opens in a real
//  browser context. Nextcloud's login flow explicitly rejects embedded
//  WKWebViews (to stop a malicious app from presenting a fake login page),
//  so this can't be a plain SwiftUI WebView.
//

import SwiftUI
import SafariServices

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
