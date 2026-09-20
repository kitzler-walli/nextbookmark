//
//  KeychainStore.swift
//  nextBookmark
//
//  Minimal Keychain-backed key/value storage for credentials. Shared by the
//  main app and the Share Extension via the keychain-access-groups
//  entitlement (both targets list the same single group, so it's also each
//  target's default access group and doesn't need to be specified per-call).
//

import Foundation
import Security

enum KeychainStore {
    private static let service = "de.altepizza.nextBookmark.credentials"

    static func set(_ value: String?, forKey key: String) {
        guard let value = value, let data = value.data(using: .utf8) else {
            delete(forKey: key)
            return
        }

        let query = baseQuery(forKey: key)

        if SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess {
            SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        } else {
            var newItem = query
            newItem[kSecValueData as String] = data
            newItem[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(newItem as CFDictionary, nil)
        }
    }

    static func string(forKey key: String) -> String? {
        var query = baseQuery(forKey: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(forKey key: String) {
        SecItemDelete(baseQuery(forKey: key) as CFDictionary)
    }

    private static func baseQuery(forKey key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
    }
}
