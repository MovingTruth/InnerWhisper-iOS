//
//  EncryptionManagerTests.swift
//  InnerWhisperTests
//
//  Created for InnerWhisper.
//

import XCTest
@testable import InnerWhisper

/// Unit tests for EncryptionManager.
///
/// Tests verify AES-256-GCM encrypt/decrypt correctness, enable/disable state
/// management, and string convenience helpers.
///
/// These tests use the real Keychain (via the shared EncryptionManager) and
/// restore the original encryption state in tearDown so they are non-destructive.
@MainActor
final class EncryptionManagerTests: XCTestCase {
    var sut: EncryptionManager!
    /// Tracks the encryption state before tests so tearDown can restore it.
    var wasEncryptionEnabledBeforeTest = false

    override func setUp() async throws {
        try await super.setUp()
        sut = EncryptionManager.shared
        wasEncryptionEnabledBeforeTest = sut.isEncryptionEnabled
        // Ensure encryption is enabled for the majority of tests
        if !sut.isEncryptionEnabled {
            _ = sut.enableEncryption()
        }
    }

    override func tearDown() async throws {
        // Restore original encryption state to avoid affecting other tests
        if wasEncryptionEnabledBeforeTest {
            _ = sut.enableEncryption()
        } else {
            _ = sut.disableEncryption()
        }
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Nil / Empty Input

    func testEncrypt_NilData_ReturnsNil() {
        XCTAssertNil(sut.encrypt(data: nil), "Encrypting nil should return nil")
    }

    func testEncrypt_EmptyData_ReturnsEmptyData() {
        let result = sut.encrypt(data: Data())
        XCTAssertEqual(result, Data(), "Encrypting empty Data should return empty Data unchanged")
    }

    func testDecrypt_NilData_ReturnsNil() {
        XCTAssertNil(sut.decrypt(encryptedData: nil))
    }

    func testDecrypt_EmptyData_ReturnsEmptyData() {
        XCTAssertEqual(sut.decrypt(encryptedData: Data()), Data())
    }

    // MARK: - Encrypt / Decrypt Roundtrip

    func testEncryptDecrypt_Roundtrip_WithEncryptionEnabled() {
        // Given
        let original = Data("The quick brown fox".utf8)

        // When
        let encrypted = sut.encrypt(data: original)
        let decrypted = sut.decrypt(encryptedData: encrypted)

        // Then
        XCTAssertNotNil(encrypted, "Encrypted output should not be nil")
        XCTAssertNotEqual(encrypted, original, "Ciphertext should differ from plaintext")
        XCTAssertEqual(decrypted, original, "Decrypted data should match original plaintext")
    }

    func testEncryptDecrypt_LargeData_Roundtrip() {
        // Given: 10 KB of test data
        let original = Data(repeating: 0xAB, count: 10_240)

        // When
        let encrypted = sut.encrypt(data: original)
        let decrypted = sut.decrypt(encryptedData: encrypted)

        // Then
        XCTAssertEqual(decrypted, original, "Large data should survive encrypt/decrypt roundtrip")
    }

    func testEncrypt_ProducesUniqueOutputEachCall() {
        // AES-GCM uses a random nonce; same plaintext should produce different ciphertexts
        let data = Data("Same plaintext".utf8)
        let first  = sut.encrypt(data: data)
        let second = sut.encrypt(data: data)
        XCTAssertNotEqual(first, second, "Each encryption should produce a unique ciphertext (random nonce)")
    }

    // MARK: - Disabled Encryption — passthrough behavior

    func testEncrypt_WhenEncryptionDisabled_ReturnsOriginalData() {
        // Given
        _ = sut.disableEncryption()
        let original = Data("plaintext".utf8)

        // When
        let result = sut.encrypt(data: original)

        // Then
        XCTAssertEqual(result, original, "When disabled, encrypt should return original data unchanged")
    }

    func testDecrypt_WhenEncryptionDisabled_ReturnsOriginalData() {
        // Given
        _ = sut.disableEncryption()
        let data = Data("not encrypted".utf8)

        // When
        let result = sut.decrypt(encryptedData: data)

        // Then
        XCTAssertEqual(result, data, "When disabled, decrypt should return original data unchanged")
    }

    // MARK: - Decrypt edge cases

    func testDecrypt_TooShortData_ReturnsSameData() {
        // Minimum valid AES-GCM: 12 (nonce) + 16 (tag) = 28 bytes; anything shorter is unencrypted
        _ = sut.enableEncryption()
        let shortData = Data(repeating: 0x00, count: 10)
        let result = sut.decrypt(encryptedData: shortData)
        XCTAssertEqual(result, shortData, "Data shorter than 28 bytes should be returned unchanged")
    }

    // MARK: - String Helpers

    func testEncryptString_DecryptToString_Roundtrip() {
        // Given
        let original = "Be the change you wish to see."

        // When
        let encrypted = sut.encrypt(string: original)
        let decrypted = sut.decryptToString(encryptedData: encrypted)

        // Then
        XCTAssertNotNil(encrypted)
        XCTAssertEqual(decrypted, original)
    }

    func testEncryptString_EmptyString_ReturnsNilOrEmpty() {
        // Empty string encodes to empty Data, which returns empty Data (not nil)
        let result = sut.encrypt(string: "")
        // Either nil or empty Data is acceptable for an empty string
        XCTAssertTrue(result == nil || result == Data())
    }

    // MARK: - Enable / Disable State

    func testDisableEncryption_WhenAlreadyDisabled_ReturnsTrue() {
        _ = sut.disableEncryption()
        let result = sut.disableEncryption()
        XCTAssertTrue(result, "disableEncryption() should be idempotent and return true")
    }

    func testEnableEncryption_WhenAlreadyEnabled_ReturnsTrue() {
        _ = sut.enableEncryption()
        let result = sut.enableEncryption()
        XCTAssertTrue(result, "enableEncryption() should be idempotent and return true")
    }

    func testToggle_EnableThenDisable_StateChanges() {
        _ = sut.enableEncryption()
        XCTAssertTrue(sut.isEncryptionEnabled)

        _ = sut.disableEncryption()
        XCTAssertFalse(sut.isEncryptionEnabled)
    }

    func testToggle_DisableThenEnable_StateChanges() {
        _ = sut.disableEncryption()
        XCTAssertFalse(sut.isEncryptionEnabled)

        _ = sut.enableEncryption()
        XCTAssertTrue(sut.isEncryptionEnabled)
    }

    // MARK: - Encryption Status

    func testEncryptionStatus_WhenEnabled_IsEnabled() {
        _ = sut.enableEncryption()
        XCTAssertEqual(sut.encryptionStatus, .enabled)
    }

    func testEncryptionStatus_WhenDisabled_IsDisabled() {
        _ = sut.disableEncryption()
        XCTAssertEqual(sut.encryptionStatus, .disabled)
    }

    func testEncryptionStatusDescription_IsNonEmpty() {
        XCTAssertFalse(sut.encryptionStatusDescription.isEmpty)
    }

    // MARK: - Welcome / First Launch

    func testMarkEncryptionWelcomeShown_SetsHasShownWelcome() {
        // Note: we can't easily reset hasShownWelcome without Keychain manipulation,
        // so we only verify the post-call state is consistent.
        sut.markEncryptionWelcomeShown()
        XCTAssertTrue(sut.hasShownWelcome, "After marking welcome shown, hasShownWelcome should be true")
        XCTAssertFalse(sut.isFirstLaunch, "isFirstLaunch should be false after welcome is shown")
    }

    // MARK: - EncryptionStatus enum

    func testEncryptionStatus_Enabled_DisplayName() {
        XCTAssertFalse(EncryptionStatus.enabled.displayName.isEmpty)
    }

    func testEncryptionStatus_Disabled_DisplayName() {
        XCTAssertFalse(EncryptionStatus.disabled.displayName.isEmpty)
    }

    func testEncryptionStatus_Enabled_Icon() {
        XCTAssertFalse(EncryptionStatus.enabled.icon.isEmpty)
    }

    func testEncryptionStatus_Disabled_Icon() {
        XCTAssertFalse(EncryptionStatus.disabled.icon.isEmpty)
    }
}
