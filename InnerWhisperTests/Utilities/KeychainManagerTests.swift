//
//  KeychainManagerTests.swift
//  InnerWhisperTests
//
//  Created for InnerWhisper.
//

import XCTest
@testable import InnerWhisper

/// Unit tests for KeychainManager.
///
/// Each test uses a unique Keychain key to avoid cross-test pollution.
/// All test keys are deleted in tearDown to keep the Keychain clean.
final class KeychainManagerTests: XCTestCase {
    var sut: KeychainManager!
    /// Keys created during each test, cleaned up in tearDown.
    var testKeys: [String] = []

    override func setUp() {
        super.setUp()
        sut = KeychainManager.shared
        testKeys = []
    }

    override func tearDown() {
        for key in testKeys {
            sut.deleteKeychainData(for: key)
        }
        testKeys = []
        sut = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeKey() -> String {
        let key = "test.keychain.\(UUID().uuidString)"
        testKeys.append(key)
        return key
    }

    // MARK: - Save & Retrieve

    func testSaveAndGet_Roundtrip() {
        // Given
        let key = makeKey()
        let data = Data("Hello, Keychain!".utf8)

        // When
        let saved = sut.saveKeychainData(data, for: key, synchronizable: false)
        let retrieved = sut.getKeychainData(for: key)

        // Then
        XCTAssertTrue(saved, "Save should succeed")
        XCTAssertEqual(retrieved, data, "Retrieved data should match saved data")
    }

    func testSaveAndGet_BinaryData_Roundtrip() {
        // Given
        let key = makeKey()
        let data = Data([0x00, 0x01, 0x7F, 0xFF, 0xAB, 0xCD])

        // When
        sut.saveKeychainData(data, for: key, synchronizable: false)
        let retrieved = sut.getKeychainData(for: key)

        // Then
        XCTAssertEqual(retrieved, data, "Binary data should survive a Keychain roundtrip")
    }

    func testGet_UnknownKey_ReturnsNil() {
        // Given: a key that was never saved
        let key = makeKey()

        // When
        let result = sut.getKeychainData(for: key)

        // Then
        XCTAssertNil(result, "Reading an unknown key should return nil")
    }

    // MARK: - Overwrite (Upsert)

    func testSave_OverwritesExistingValue() {
        // Given
        let key = makeKey()
        let original = Data("original".utf8)
        let updated  = Data("updated".utf8)

        sut.saveKeychainData(original, for: key, synchronizable: false)

        // When
        sut.saveKeychainData(updated, for: key, synchronizable: false)
        let retrieved = sut.getKeychainData(for: key)

        // Then
        XCTAssertEqual(retrieved, updated, "Second save should overwrite the first")
    }

    // MARK: - Delete

    func testDelete_ExistingItem_ReturnsTrue() {
        // Given
        let key = makeKey()
        sut.saveKeychainData(Data("value".utf8), for: key, synchronizable: false)

        // When
        let result = sut.deleteKeychainData(for: key)

        // Then
        XCTAssertTrue(result, "Deleting an existing item should return true")
    }

    func testDelete_NonExistentKey_ReturnsTrue() {
        // Given: a key that was never saved
        let key = makeKey()

        // When
        let result = sut.deleteKeychainData(for: key)

        // Then
        XCTAssertTrue(result, "Deleting a non-existent key should still return true (idempotent)")
    }

    func testGet_AfterDelete_ReturnsNil() {
        // Given
        let key = makeKey()
        sut.saveKeychainData(Data("value".utf8), for: key, synchronizable: false)

        // When
        sut.deleteKeychainData(for: key)
        let result = sut.getKeychainData(for: key)

        // Then
        XCTAssertNil(result, "Reading a deleted key should return nil")
    }

    func testDelete_TwiceInARow_BothReturnTrue() {
        // Given
        let key = makeKey()
        sut.saveKeychainData(Data("val".utf8), for: key, synchronizable: false)

        // When
        let first  = sut.deleteKeychainData(for: key)
        let second = sut.deleteKeychainData(for: key)

        // Then
        XCTAssertTrue(first,  "First delete should return true")
        XCTAssertTrue(second, "Second delete (already gone) should also return true")
    }

    // MARK: - Synchronizable flag

    func testSave_NonSynchronizable_ReturnsTrue() {
        let key = makeKey()
        let result = sut.saveKeychainData(Data("s".utf8), for: key, synchronizable: false)
        XCTAssertTrue(result)
    }

    // MARK: - Label (metadata)

    func testSave_WithLabel_DataStillRetrievable() {
        // Given: label is purely informational, should not affect data retrieval
        let key = makeKey()
        let data = Data("labeled".utf8)

        // When
        sut.saveKeychainData(data, for: key, synchronizable: false, label: "Test Label")
        let retrieved = sut.getKeychainData(for: key)

        // Then
        XCTAssertEqual(retrieved, data, "Label should not interfere with data retrieval")
    }

    // MARK: - Singleton

    func testShared_ReturnsSameInstance() {
        let a = KeychainManager.shared
        let b = KeychainManager.shared
        XCTAssertTrue(a === b)
    }
}
