//
//  CredentialsStore.swift
//  nextBookmark
//
//  Where the app's Nextcloud login name and app password live: the
//  Keychain, not UserDefaults. The server URL itself isn't secret and stays
//  in the shared UserDefaults suite alongside the "valid" flag.
//

import Foundation

enum CredentialsStore {
    private enum Keys {
        static let loginName = "loginName"
        static let appPassword = "appPassword"
        static let migratedToKeychain = "credentialsMigratedToKeychain"
        static let hasLaunchedSinceInstall = "hasLaunchedSinceInstall"
    }

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: SharedUserDefaults.suiteName)
    }

    static var loginName: String? { KeychainStore.string(forKey: Keys.loginName) }
    static var appPassword: String? { KeychainStore.string(forKey: Keys.appPassword) }
    static var isLoggedIn: Bool { loginName != nil && appPassword != nil }

    /// Stores the result of a successful login (Login Flow v2, or the manual
    /// fallback) and marks the connection valid.
    static func save(server: String, loginName: String, appPassword: String) {
        defaults?.set(server, forKey: SharedUserDefaults.Keys.url)
        KeychainStore.set(loginName, forKey: Keys.loginName)
        KeychainStore.set(appPassword, forKey: Keys.appPassword)
        defaults?.set(true, forKey: SharedUserDefaults.Keys.valid)
    }

    /// Logs the app out: clears the stored credentials and the "valid" flag.
    /// Leaves the server URL in place so it's still there next time you log in.
    static func clear() {
        KeychainStore.delete(forKey: Keys.loginName)
        KeychainStore.delete(forKey: Keys.appPassword)
        defaults?.set(false, forKey: SharedUserDefaults.Keys.valid)
    }

    /// Keychain items survive app deletion, but this app's own UserDefaults
    /// (including the shared App Group suite the URL/"valid" flag live in)
    /// don't. Without this, reinstalling after a previous install had logged
    /// in starts up "logged in" from stale Keychain credentials with no
    /// server URL to match them — Settings shows "Log Out" with no way back
    /// to the login button, and no bookmarks load. Clears any pre-existing
    /// Keychain credentials the first time this install launches. Safe to
    /// call on every launch; only acts once per install.
    static func clearStaleKeychainAfterReinstallIfNeeded() {
        guard defaults?.bool(forKey: Keys.hasLaunchedSinceInstall) != true else { return }
        KeychainStore.delete(forKey: Keys.loginName)
        KeychainStore.delete(forKey: Keys.appPassword)
        defaults?.set(true, forKey: Keys.hasLaunchedSinceInstall)
    }

    /// One-time move of any pre-existing username/password from UserDefaults
    /// (where earlier versions of this app stored them) into the Keychain.
    /// Safe to call on every launch; only does anything the first time.
    static func migrateFromUserDefaultsIfNeeded() {
        guard defaults?.bool(forKey: Keys.migratedToKeychain) != true else { return }

        if let legacyUsername = defaults?.string(forKey: SharedUserDefaults.Keys.username), !legacyUsername.isEmpty,
           let legacyPassword = defaults?.string(forKey: SharedUserDefaults.Keys.password), !legacyPassword.isEmpty {
            KeychainStore.set(legacyUsername, forKey: Keys.loginName)
            KeychainStore.set(legacyPassword, forKey: Keys.appPassword)
        }

        defaults?.removeObject(forKey: SharedUserDefaults.Keys.username)
        defaults?.removeObject(forKey: SharedUserDefaults.Keys.password)
        defaults?.set(true, forKey: Keys.migratedToKeychain)
    }
}
