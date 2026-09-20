//
//  ShareViewController.swift
//  ShareExtension
//
//  Created by Kai on 30.08.19.
//  Copyright © 2019 Kai. All rights reserved.
//

import UIKit
import Social

@objc(ShareViewController)
class ShareViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        CredentialsStore.migrateFromUserDefaultsIfNeeded()

        let blurEffect = UIBlurEffect(style: .dark)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = self.view.bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.insertSubview(blurEffectView, at: 0)
        
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
                CallNextcloud().postURL(url: shareURL) { _, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            self.fail(message: String(format: NSLocalizedString("Couldn't save the bookmark: %@", comment: "Share extension error when saving to Nextcloud fails, %@ is the underlying error description"), error.localizedDescription))
                        } else {
                            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                        }
                    }
                }
            }
        }
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
