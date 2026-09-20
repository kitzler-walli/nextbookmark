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
                    self.fail(message: "No link was found to save.")
                    return
                }
                CallNextcloud().postURL(url: shareURL) { _, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            self.fail(message: "Couldn't save the bookmark: \(error.localizedDescription)")
                        } else {
                            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                        }
                    }
                }
            }
        }
    }

    private func fail(message: String) {
        let alert = UIAlertController(title: "Couldn't Save Bookmark", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            self.extensionContext?.cancelRequest(withError: NSError(
                domain: "at.kw.nextbookmark.ShareExtension",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: message]
            ))
        })
        present(alert, animated: true)
    }
}
