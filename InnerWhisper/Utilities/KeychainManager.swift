//
//  KeychainManager.swift
//  InnerWhisper
//
//  Created by Robin O'Brien on 2026-03-05.
//
//  Provides a simple, thread-safe interface for reading and writing
//  sensitive data to the iOS Keychain. Supports optional iCloud
//  Keychain sync for cross-device key availability.
//

import Foundation
import Security

/// Manages secure storage and retrieval of data in the iOS Keychain.
///
/// ## Usage
/// ```swift
/// // Save data
/// KeychainManager.shared.saveKeychainData(keyData, for: "my.key", synchronizable: true)
///
/// // Retrieve data
/// if let data = KeychainManager.shared.getKeychainData(for: "my.key") { ... }
/// ```
final class KeychainManager {

    // MARK: - Singleton

    static let shared = KeychainManager()
    private init() {}

    // MARK: - Read

    /// Retrieves data from the Keychain for the given key.
    ///
    /// Uses `kSecAttrSynchronizableAny` so it finds both iCloud-synced
    /// and device-local items without needing to know which was used at save time.
    ///
    /// - Parameter key: The account key used when the item was saved
    /// - Returns: The stored `Data`, or `nil` if not found
    func getKeychainData(for key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String:               kSecClassGenericPassword,
            kSecAttrAccount as String:         key,
            kSecAttrSynchronizable as String:  kSecAttrSynchronizableAny,
            kSecReturnData as String:          true,
            kSecMatchLimit as String:          kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            if status != errSecItemNotFound {
                #if DEBUG
                print("KeychainManager: Read failed for key '\(key)': OSStatus \(status)")
                #endif
            }
            return nil
        }
        return data
    }

    // MARK: - Write

    /// Saves data to the Keychain for the given key.
    ///
    /// Any existing item with the same key is deleted before writing
    /// so this method acts as an upsert.
    ///
    /// - Parameters:
    ///   - data: The data to store securely
    ///   - key: A unique identifier for this item
    ///   - synchronizable: When `true`, the item syncs across devices via iCloud Keychain
    ///   - label: Human-readable label shown in Keychain debugging tools. Pass `nil` to omit.
    /// - Returns: `true` if the item was saved successfully
    @discardableResult
    func saveKeychainData(_ data: Data, for key: String, synchronizable: Bool, label: String? = nil) -> Bool {
        // Remove any existing item (both synced and local) before writing
        deleteKeychainData(for: key)

        // Choose the most restrictive accessibility that is still compatible
        // with the requested sync behaviour:
        // • Local-only items: WhenUnlockedThisDeviceOnly — most secure; key is
        //   inaccessible to background processes and is excluded from iCloud/backups.
        // • Synced items: WhenUnlocked — device must be unlocked; compatible with
        //   kSecAttrSynchronizable. (ThisDeviceOnly variants reject sync requests.)
        let accessibility: CFString = synchronizable
            ? kSecAttrAccessibleWhenUnlocked
            : kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        var attributes: [String: Any] = [
            kSecClass as String:               kSecClassGenericPassword,
            kSecAttrAccount as String:         key,
            kSecValueData as String:           data,
            kSecAttrAccessible as String:      accessibility,
            kSecAttrSynchronizable as String:  NSNumber(value: synchronizable)
        ]

        // Provide a human-readable label for Keychain debugging tools (optional).
        if let label {
            attributes[kSecAttrLabel as String] = label
        }

        let status = SecItemAdd(attributes as CFDictionary, nil)

        if status != errSecSuccess {
            #if DEBUG
            print("KeychainManager: Save failed for key '\(key)': OSStatus \(status)")
            #endif
        }
        return status == errSecSuccess
    }

    // MARK: - Delete

    /// Deletes all Keychain items (synced and local) matching the given key.
    ///
    /// - Parameter key: The account key of the item to remove
    /// - Returns: `true` if the item was deleted or did not exist
    @discardableResult
    func deleteKeychainData(for key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String:               kSecClassGenericPassword,
            kSecAttrAccount as String:         key,
            kSecAttrSynchronizable as String:  kSecAttrSynchronizableAny
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
