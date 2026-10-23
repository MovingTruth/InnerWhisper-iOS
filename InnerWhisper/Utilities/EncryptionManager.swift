//
//  EncryptionManager.swift
//  InnerWhisper
//
//  Created by Robin O'Brien on 2026-01-22.
//
//  Manages encryption and decryption of sensitive data using AES-256-GCM
//  via Apple's CryptoKit framework.
//

import Foundation
import CryptoKit
import SwiftUI

// MARK: - Keychain key constants
//
// Declared at file scope so they are accessible from nonisolated methods
// without crossing the @MainActor isolation boundary.
// Global `let` constants are Sendable and safe in any concurrency context.
private let _encryptionKeyKeychainID     = "com.innerwhisper.encryption.key"
private let _encryptionEnabledKeychainID = "com.innerwhisper.encryption.enabled"
private let _welcomeShownKeychainID      = "com.innerwhisper.welcome.shown"
private let _cloudSyncKeychainID         = "com.innerwhisper.encryption.cloudsync"

/// Manages encryption and decryption of sensitive app data.
///
/// Uses AES-256-GCM (Galois/Counter Mode) for authenticated encryption,
/// providing both confidentiality and integrity protection.
///
/// ## Security Design
/// - AES-256 key, enabled-state, and welcome flag are all stored in Keychain,
///   not UserDefaults, so they cannot be trivially tampered with on jailbroken devices.
/// - iCloud Keychain sync defaults to **disabled** to prevent nonce-reuse risk:
///   if the same AES-GCM key were used independently on two devices, a random
///   nonce collision (however rare) would break GCM's authenticity guarantees.
/// - `encrypt()` returns `nil` on failure rather than plain data, so a crypto
///   error never silently produces an unencrypted write.
/// - `encrypt()` / `decrypt()` are `nonisolated` for call-site flexibility (e.g.
///   background saves). They are safe because they only read file-scope constants
///   and the thread-safe Keychain — no `@MainActor` state is touched.
///
/// ## Usage
/// ```swift
/// let encrypted = EncryptionManager.shared.encrypt(data: sensitiveData)
/// let decrypted = EncryptionManager.shared.decrypt(encryptedData: encrypted)
/// ```
@MainActor
@Observable
final class EncryptionManager {

    // MARK: - Singleton

    static let shared = EncryptionManager()

    // MARK: - Observable State

    /// Whether encryption is currently enabled. Backed by Keychain.
    ///
    /// All mutations go through `enableEncryption()` / `disableEncryption()`, which
    /// write to Keychain **before** updating this property. There is no `didSet` here
    /// to avoid a redundant double-write on every assignment.
    private(set) var isEncryptionEnabled: Bool

    /// Whether the first-launch security welcome screen has already been shown.
    /// Backed by Keychain so it cannot be reset by clearing UserDefaults.
    private(set) var hasShownWelcome: Bool

    // MARK: - Initialization

    private init() {
        // ── Encryption enabled state ──────────────────────────────────────────
        if let stored = KeychainManager.shared.getKeychainData(for: _encryptionEnabledKeychainID),
           !stored.isEmpty {
            self.isEncryptionEnabled = stored.first == 1
        } else if let legacy = UserDefaults.standard.object(forKey: "EncryptionEnabled") as? Bool {
            // One-time migration from the old UserDefaults location
            self.isEncryptionEnabled = legacy
            KeychainManager.shared.saveKeychainData(Data([legacy ? 1 : 0]),
                                                    for: _encryptionEnabledKeychainID,
                                                    synchronizable: false)
            UserDefaults.standard.removeObject(forKey: "EncryptionEnabled")
        } else {
            // First-ever launch: enable encryption by default
            self.isEncryptionEnabled = true
            KeychainManager.shared.saveKeychainData(Data([1]),
                                                    for: _encryptionEnabledKeychainID,
                                                    synchronizable: false)
        }

        // ── Welcome screen shown flag ─────────────────────────────────────────
        if let stored = KeychainManager.shared.getKeychainData(for: _welcomeShownKeychainID),
           !stored.isEmpty {
            self.hasShownWelcome = stored.first == 1
        } else if UserDefaults.standard.bool(forKey: "HasShownEncryptionWelcome") {
            // One-time migration from the old UserDefaults location
            self.hasShownWelcome = true
            KeychainManager.shared.saveKeychainData(Data([1]),
                                                    for: _welcomeShownKeychainID,
                                                    synchronizable: false)
            UserDefaults.standard.removeObject(forKey: "HasShownEncryptionWelcome")
        } else {
            self.hasShownWelcome = false
        }

        // Pre-warm the key so the first encrypt() call doesn't block
        if isEncryptionEnabled {
            _ = getOrCreateEncryptionKey()
        }
    }

    // MARK: - First-Launch Welcome

    /// `true` until the security welcome screen has been dismissed once.
    var isFirstLaunch: Bool { !hasShownWelcome }

    /// Call when the security welcome screen is dismissed.
    func markEncryptionWelcomeShown() {
        KeychainManager.shared.saveKeychainData(Data([1]),
                                                for: _welcomeShownKeychainID,
                                                synchronizable: false)
        hasShownWelcome = true
    }

    // MARK: - Encryption Control

    /// Enables encryption. Generates and stores a key if one doesn't exist yet.
    ///
    /// Writes to Keychain **before** updating `isEncryptionEnabled`
    /// to close the race window between the in-memory flag and the Keychain state
    /// that background `encrypt()` callers read via `encryptionEnabledFromKeychain()`.
    ///
    /// - Returns: `true` on success.
    func enableEncryption() -> Bool {
        guard !isEncryptionEnabled else { return true }
        guard getOrCreateEncryptionKey() != nil else {
            #if DEBUG
            print("EncryptionManager: Failed to create encryption key")
            #endif
            return false
        }
        // Write Keychain first so nonisolated callers see the new state immediately,
        // then update the property to notify observers.
        KeychainManager.shared.saveKeychainData(Data([1]), for: _encryptionEnabledKeychainID, synchronizable: false)
        isEncryptionEnabled = true
        return true
    }

    /// Disables encryption. The key is retained in Keychain so re-enabling
    /// can decrypt previously encrypted data.
    ///
    /// - Returns: `true` on success.
    func disableEncryption() -> Bool {
        guard isEncryptionEnabled else { return true }
        // Write Keychain first (same race-closing rationale as enableEncryption).
        KeychainManager.shared.saveKeychainData(Data([0]), for: _encryptionEnabledKeychainID, synchronizable: false)
        isEncryptionEnabled = false
        return true
    }

    // MARK: - Encryption Operations

    /// Encrypts data using AES-256-GCM.
    ///
    /// - Parameter data: The plaintext data to encrypt.
    /// - Returns: Encrypted data, the original data if encryption is disabled,
    ///            or **`nil`** if encryption is enabled but fails.
    ///            Callers must treat `nil` as a hard failure and must not persist the data.
    nonisolated func encrypt(data: Data?) -> Data? {
        guard let data, !data.isEmpty else { return data }
        guard encryptionEnabledFromKeychain() else { return data }

        guard let key = getOrCreateEncryptionKey() else {
            #if DEBUG
            print("EncryptionManager: Failed to get encryption key — write aborted")
            #endif
            return nil
        }

        do {
            let sealedBox = try AES.GCM.seal(data, using: key)

            // Layout: [nonce 12 B][ciphertext][tag 16 B]
            var out = Data()
            out.append(sealedBox.nonce.withUnsafeBytes { Data($0) })
            out.append(sealedBox.ciphertext)
            out.append(sealedBox.tag.withUnsafeBytes { Data($0) })
            return out
        } catch {
            #if DEBUG
            print("EncryptionManager: Encryption failed — write aborted: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    /// Decrypts AES-256-GCM encrypted data.
    ///
    /// Returns the original bytes on decryption failure to support reading
    /// legacy unencrypted records gracefully.
    ///
    /// - Parameter encryptedData: The ciphertext produced by `encrypt(data:)`.
    /// - Returns: Decrypted data, or the input unchanged if encryption is disabled
    ///            or the data does not appear to be encrypted.
    nonisolated func decrypt(encryptedData: Data?) -> Data? {
        guard let encryptedData, !encryptedData.isEmpty else { return encryptedData }
        guard encryptionEnabledFromKeychain() else { return encryptedData }

        guard let key = getOrCreateEncryptionKey() else {
            #if DEBUG
            print("EncryptionManager: Failed to get encryption key")
            #endif
            return encryptedData
        }

        // Minimum valid size: nonce (12 B) + tag (16 B) = 28 B
        guard encryptedData.count >= 28 else { return encryptedData }

        do {
            let nonceData  = encryptedData.prefix(12)
            let tagData    = encryptedData.suffix(16)
            let ciphertext = encryptedData.dropFirst(12).dropLast(16)

            guard let nonce = try? AES.GCM.Nonce(data: nonceData) else {
                return encryptedData
            }

            let sealedBox = try AES.GCM.SealedBox(nonce: nonce,
                                                   ciphertext: Data(ciphertext),
                                                   tag: tagData)
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            // Graceful fallback: data was likely stored before encryption was enabled
            #if DEBUG
            print("EncryptionManager: Decryption failed (possibly unencrypted record): \(error.localizedDescription)")
            #endif
            return encryptedData
        }
    }

    /// Encrypts a UTF-8 string.
    nonisolated func encrypt(string: String) -> Data? {
        guard let data = string.data(using: .utf8) else { return nil }
        return encrypt(data: data)
    }

    /// Decrypts data and returns it as a UTF-8 string.
    nonisolated func decryptToString(encryptedData: Data?) -> String? {
        guard let decrypted = decrypt(encryptedData: encryptedData) else { return nil }
        return String(data: decrypted, encoding: .utf8)
    }

    // MARK: - Key Management

    /// Loads the encryption key from Keychain, or generates and stores a new one.
    ///
    /// This method is `nonisolated` and only accesses the thread-safe Keychain
    /// and file-scope `let` constants — no actor-isolated state is read.
    ///
    /// iCloud Keychain sync defaults to **disabled** to prevent nonce-reuse across
    /// devices. Enable it explicitly via the CloudSync Keychain flag only if the
    /// app has a coordinated, per-device encryption scheme.
    ///
    /// - Note: A theoretical race exists if two background threads both call this
    ///   before the key exists. In practice it cannot happen because the singleton
    ///   `init` (on MainActor) pre-warms the key before any background caller runs.
    nonisolated private func getOrCreateEncryptionKey() -> SymmetricKey? {
        if let keyData = KeychainManager.shared.getKeychainData(for: _encryptionKeyKeychainID) {
            return SymmetricKey(data: keyData)
        }

        let newKey  = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }

        // Read sync preference from Keychain; default to false (safest).
        // iCloud sync is opt-in because the same AES-GCM key used on multiple
        // devices raises nonce-reuse risk.
        let syncData  = KeychainManager.shared.getKeychainData(for: _cloudSyncKeychainID)
        let cloudSync = syncData?.first == 1   // defaults to false when not set

        guard KeychainManager.shared.saveKeychainData(keyData,
                                                      for: _encryptionKeyKeychainID,
                                                      synchronizable: cloudSync,
                                                      label: "InnerWhisper Encryption Key") else {
            #if DEBUG
            print("EncryptionManager: Failed to save encryption key to Keychain")
            #endif
            return nil
        }

        return newKey
    }

    /// Reads the encryption-enabled flag from Keychain.
    /// Safe to call from any thread; no actor-isolated state is accessed.
    nonisolated private func encryptionEnabledFromKeychain() -> Bool {
        guard let data = KeychainManager.shared.getKeychainData(for: _encryptionEnabledKeychainID) else {
            return false
        }
        return data.first == 1
    }

    // MARK: - Status Helpers

    var encryptionStatus: EncryptionStatus {
        isEncryptionEnabled ? .enabled : .disabled
    }

    var encryptionStatusDescription: String {
        switch encryptionStatus {
        case .enabled:
            return "Encryption is enabled. Your data is encrypted using AES-256-GCM."
        case .disabled:
            return "Encryption is disabled. Data is protected only by iOS Data Protection when the device is locked."
        }
    }
}

// MARK: - Encryption Status

enum EncryptionStatus {
    case enabled
    case disabled

    var displayName: String {
        switch self {
        case .enabled:  return "Enabled"
        case .disabled: return "Disabled"
        }
    }

    var icon: String {
        switch self {
        case .enabled:  return "lock.fill"
        case .disabled: return "lock.open.fill"
        }
    }

    var color: Color {
        switch self {
        case .enabled:  return .green
        case .disabled: return .orange
        }
    }
}
