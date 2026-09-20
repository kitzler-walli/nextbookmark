//
//  CredentialsStoreTests.swift
//  nextBookmarkTests
//
//  KeychainStore is generic (any key), so it's safe to test directly with a
//  key that can't collide with anything real. CredentialsStore itself is
//  deliberately NOT tested here: nextBookmarkTests is host-app-launched
//  (TEST_HOST), so it runs inside the real nextBookmark.app process and
//  shares its actual Keychain items and UserDefaults suite. CredentialsStore
//  always reads/writes the app's real "loginName"/"appPassword" keys, so
//  calling .save()/.clear() from a test would overwrite whatever account is
//  actually logged in on this device/simulator.
//

import XCTest
@testable import nextBookmark

final class KeychainStoreTests: XCTestCase {
    private let key = "KeychainStoreTests.testKey"

    override func tearDown() {
        KeychainStore.delete(forKey: key)
        super.tearDown()
    }

    func testSetAndReadString() {
        KeychainStore.set("hello", forKey: key)
        XCTAssertEqual(KeychainStore.string(forKey: key), "hello")
    }

    func testReadMissingKeyReturnsNil() {
        XCTAssertNil(KeychainStore.string(forKey: "KeychainStoreTests.neverSet"))
    }

    func testSetNilDeletesTheValue() {
        KeychainStore.set("hello", forKey: key)
        KeychainStore.set(nil, forKey: key)
        XCTAssertNil(KeychainStore.string(forKey: key))
    }

    func testOverwritingAnExistingKeyUpdatesInPlace() {
        KeychainStore.set("first", forKey: key)
        KeychainStore.set("second", forKey: key)
        XCTAssertEqual(KeychainStore.string(forKey: key), "second")
    }
}
