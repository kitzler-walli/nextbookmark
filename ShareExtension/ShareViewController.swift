//
//  ShareViewController.swift
//  ShareExtension
//
//  Created by Kai on 30.08.19.
//  Copyright © 2019 Kai. All rights reserved.
//

import UIKit
import SwiftUI

@objc(ShareViewController)
class ShareViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        CredentialsStore.clearStaleKeychainAfterReinstallIfNeeded()
        CredentialsStore.migrateFromUserDefaultsIfNeeded()

        view.backgroundColor = .systemGroupedBackground

        let spinner = UIActivityIndicatorView(style: .large)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        view.addSubview(spinner)
        spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
    }
        
    override func viewWillAppear(_: Bool) {
        let item = extensionContext?.inputItems.first as? NSExtensionItem
        ShareURLExtractor.extractURL(from: item) { shareURL in
            DispatchQueue.main.async {
                guard let shareURL = shareURL else {
                    self.fail(message: NSLocalizedString("No link was found to save.", comment: "Share extension error when nothing shareable was found in the shared item"))
                    return
                }
                self.showForm(url: shareURL, title: Self.pageTitle(of: item, url: shareURL))
            }
        }
    }

    /// Browsers pass the page title as the item's content text. Ignore it
    /// when it's just the link again (e.g. a plain text share).
    static func pageTitle(of item: NSExtensionItem?, url: String) -> String {
        let candidates = [item?.attributedContentText?.string, item?.attributedTitle?.string]
        for candidate in candidates {
            let text = candidate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !text.isEmpty && text != url && !text.hasPrefix("http") {
                return text
            }
        }
        return ""
    }

    private func showForm(url: String, title: String) {
        let form = ShareBookmarkForm(url: url, title: title) { [weak self] saved in
            if saved {
                self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            } else {
                self?.extensionContext?.cancelRequest(withError: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError))
            }
        }
        let host = UIHostingController(rootView: form)
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
    }

    private func fail(message: String) {
        let alert = UIAlertController(title: NSLocalizedString("Couldn't Save Bookmark", comment: "Share extension alert title when saving a bookmark fails"), message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Share extension alert dismiss button"), style: .default) { _ in
            self.extensionContext?.cancelRequest(withError: NSError(
                domain: "at.kw.nextbookmark.ShareExtension",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: message]
            ))
        })
        present(alert, animated: true)
    }
}

/// Loads the folder tree so the shared link can be filed into a folder.
final class ShareFolderLoader: ObservableObject {
    @Published var folders: [Folder] = []
    @Published var isLoading = true

    init() {
        let client = CallNextcloud()
        client.requestFolderHierarchy { [weak self] json in
            self?.folders = json.map { client.makeFolders(json: $0) } ?? []
            self?.isLoading = false
        }
    }
}

/// The app's bookmark form, prefilled with the shared link and page title.
struct ShareBookmarkForm: View {
    let url: String
    let title: String
    let onFinish: (Bool) -> Void
    @StateObject private var loader = ShareFolderLoader()

    var body: some View {
        BookmarkEditView(
            bookmark: nil,
            folders: loader.folders,
            defaultFolderId: -1,
            initialURL: url,
            initialTitle: title,
            isLoadingFolders: loader.isLoading,
            allowsOpeningURL: false,
            onSave: { draft, completion in
                CallNextcloud().createBookmark(url: draft.url, title: draft.title, tags: draft.tags, folders: draft.folderIds) { bookmark, error in
                    completion(error == nil && bookmark != nil)
                }
            },
            onFinish: onFinish
        )
    }
}
