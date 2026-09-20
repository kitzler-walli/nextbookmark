//
//  ShareURLExtractor.swift
//  nextBookmark
//
//  URL-extraction logic used by the Share Extension. It lives in the shared
//  middleware/ folder (built into both the nextBookmark and ShareExtension
//  targets, like CallNextcloud.swift) so it can be exercised from
//  nextBookmarkTests, which only links against the nextBookmark target.
//

import Foundation

extension NSItemProvider {
    var isText: Bool {
        canLoadObject(ofClass: NSString.self)
    }

    var isURL: Bool {
        canLoadObject(ofClass: URL.self)
    }

    func getUrl(completion: @escaping (String?) -> Void) {
        _ = loadObject(ofClass: URL.self) { url, _ in
            completion(url?.absoluteString)
        }
    }

    func getText(completion: @escaping (String?) -> Void) {
        _ = loadObject(ofClass: NSString.self) { text, _ in
            completion(text as? String)
        }
    }
}

enum ShareURLExtractor {
    /// Finds the first shareable URL among an extension item's attachments:
    /// URL-typed attachments are used directly, text attachments only if
    /// they look like a URL. Calls back with nil (never hangs) if nothing
    /// usable is found.
    static func extractURL(from item: NSExtensionItem?, completion: @escaping (String?) -> Void) {
        guard let attachments = item?.attachments, !attachments.isEmpty else {
            completion(nil)
            return
        }

        var pending = attachments.count
        var result: String?
        var didComplete = false

        func finish(_ candidate: String?) {
            if result == nil {
                result = candidate
            }
            pending -= 1
            if pending == 0 && !didComplete {
                didComplete = true
                completion(result)
            }
        }

        for attachment in attachments {
            if attachment.isURL {
                attachment.getUrl { finish($0) }
            } else if attachment.isText {
                attachment.getText { text in
                    finish(text?.hasPrefix("http") == true ? text : nil)
                }
            } else {
                finish(nil)
            }
        }
    }
}
