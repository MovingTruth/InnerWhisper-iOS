//
//  UserAddedQuotesStore.swift
//  InnerWhisper
//
//  Persists user-authored quotes as AES-256-GCM encrypted JSON, stored in the
//  iCloud Documents container when available, otherwise Application Support.
//

import CryptoKit
import Foundation

// MARK: - Encryption (dedicated key, iCloud Keychain–synced for multi-device decrypt)

private let _userAddedQuotesKeychainAccount = "com.innerwhisper.useraddedquotes.aeskey"

enum UserAddedQuotesEncryption {

    /// AES-256-GCM with a dedicated key. Independent of the app-wide EncryptionManager toggle.
    static func encrypt(_ plaintext: Data) -> Data? {
        guard let key = getOrCreateKey() else { return nil }
        do {
            let sealed = try AES.GCM.seal(plaintext, using: key)
            var out = Data()
            out.append(sealed.nonce.withUnsafeBytes { Data($0) })
            out.append(sealed.ciphertext)
            out.append(sealed.tag.withUnsafeBytes { Data($0) })
            return out
        } catch {
            #if DEBUG
            print("UserAddedQuotesEncryption: encrypt failed — \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    static func decrypt(_ ciphertext: Data) -> Data? {
        guard ciphertext.count >= 28 else { return nil }
        // Use getExistingKey() — NOT getOrCreateKey() — so we never create a fresh key
        // while iCloud Keychain is still delivering the original one. Creating a new key
        // here would overwrite the Keychain slot, making every retry use the wrong key
        // and permanently blocking decryption of the cloud file.
        guard let key = getExistingKey() else { return nil }
        do {
            let nonceData = ciphertext.prefix(12)
            let tagData = ciphertext.suffix(16)
            let ct = ciphertext.dropFirst(12).dropLast(16)
            guard let nonce = try? AES.GCM.Nonce(data: nonceData) else { return nil }
            let box = try AES.GCM.SealedBox(nonce: nonce, ciphertext: Data(ct), tag: tagData)
            return try AES.GCM.open(box, using: key)
        } catch {
            #if DEBUG
            print("UserAddedQuotesEncryption: decrypt failed — \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    /// Fetches the key from Keychain only — never creates one.
    /// Used by `decrypt()` so that a missing key (iCloud Keychain still syncing on a new device)
    /// returns `nil` and allows the retry loop to try again, rather than generating a new wrong key
    /// that would overwrite the Keychain slot and make all retries fail with the same bad key.
    private static func getExistingKey() -> SymmetricKey? {
        guard let data = KeychainManager.shared.getKeychainData(for: _userAddedQuotesKeychainAccount) else {
            return nil
        }
        return SymmetricKey(data: data)
    }

    /// iCloud Keychain sync is **enabled** for this key so each device can decrypt the
    /// ciphertext file synced via the iCloud Documents container. Nonces are unique per encrypt.
    private static func getOrCreateKey() -> SymmetricKey? {
        if let data = KeychainManager.shared.getKeychainData(for: _userAddedQuotesKeychainAccount) {
            return SymmetricKey(data: data)
        }
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }
        guard KeychainManager.shared.saveKeychainData(
            keyData,
            for: _userAddedQuotesKeychainAccount,
            synchronizable: true,
            label: "InnerWhisper User Quotes Key"
        ) else { return nil }
        return key
    }
}

// MARK: - Store

/// Owns user-added quotes: encrypted storage, optional iCloud Documents path, merge with aggregator.
@MainActor
@Observable
final class UserAddedQuotesStore {

    static let shared = UserAddedQuotesStore()

    /// Synthetic `sourceFile` value — not a bundle resource.
    static let sourceFileName = "Quotes_UserAdded"

    static let categoryDisplayName = "User Added"

    private static let encryptedFileName = "user_added_quotes.enc"
    private static let iCloudContainerIdentifier = "iCloud.com.example.InnerWhisperPortfolio"

    /// Maximum lengths to keep payloads reasonable for sync and UI.
    static let maxQuoteLength = 4_000
    static let maxAuthorLength = 200

    private(set) var quotes: [Quote] = []

    /// True while a cloud `.enc` file exists that this device cannot decrypt.
    /// Exposed so the UI can offer a reset action.
    private(set) var syncBlocked = false

    /// True when an encrypted file exists but could not be decrypted (usually iCloud Keychain still syncing the AES key on a new device). Prevents overwriting cloud data with a newly generated key.
    private var cannotDecryptExistingCloudFile = false {
        didSet { syncBlocked = cannotDecryptExistingCloudFile }
    }

    private init() {}

    // MARK: - Load / sync

    /// Reads from disk (and migrates local → iCloud when the container becomes available).
    func loadFromDisk() async {
        let maxAttempts = 5
        for attempt in 1...maxAttempts {
            do {
                let url = try Self.resolvedStorageURL()
                guard FileManager.default.fileExists(atPath: url.path) else {
                    cannotDecryptExistingCloudFile = false
                    quotes = []
                    return
                }
                Self.ensureUbiquitousDownloadIfNeeded(at: url)
                let raw = try Data(contentsOf: url)
                guard !raw.isEmpty else {
                    cannotDecryptExistingCloudFile = false
                    quotes = []
                    return
                }
                if let decrypted = UserAddedQuotesEncryption.decrypt(raw) {
                    let collection = try JSONDecoder().decode(QuoteCollection.self, from: decrypted)
                    cannotDecryptExistingCloudFile = false
                    quotes = collection.quotes.map(Self.tagQuote)
                    #if DEBUG
                    print("[UserAddedQuotesStore] Loaded \(quotes.count) user quote(s) from \(url.path)")
                    #endif
                    return
                }
                if attempt < maxAttempts {
                    try await Task.sleep(nanoseconds: 1_500_000_000)
                    continue
                }
                cannotDecryptExistingCloudFile = true
                quotes = []
                #if DEBUG
                print("[UserAddedQuotesStore] Decrypt failed after retries — key may still be syncing via iCloud Keychain")
                #endif
                return
            } catch {
                if attempt < maxAttempts {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    continue
                }
                cannotDecryptExistingCloudFile = false
                quotes = []
                #if DEBUG
                print("[UserAddedQuotesStore] load failed — \(error.localizedDescription)")
                #endif
                return
            }
        }
    }

    /// Deletes all stored quotes (local and iCloud), removes the encryption key from Keychain,
    /// and unblocks saves. Use when the encrypted file cannot be decrypted and the user
    /// chooses to start fresh rather than wait for iCloud Keychain to sync.
    func resetStorage() async {
        if let local = try? Self.localStorageURL() {
            try? FileManager.default.removeItem(at: local)
        }
        if let uDir = Self.ubiquityDocumentsDirectoryURL() {
            let cloud = uDir.appendingPathComponent(Self.encryptedFileName)
            try? FileManager.default.removeItem(at: cloud)
        }
        KeychainManager.shared.deleteKeychainData(for: _userAddedQuotesKeychainAccount)
        cannotDecryptExistingCloudFile = false
        quotes = []
        AggregatingQuoteProvider.shared.reloadUserQuotes()
    }

    /// Call when the app becomes active so another device’s writes can appear (last writer wins for the file).
    func synchronizeFromCloud() {
        Task { @MainActor in
            await loadFromDisk()
            AggregatingQuoteProvider.shared.reloadUserQuotes()
            NotificationCenter.default.post(name: .userAddedQuotesDidChange, object: nil)
        }
    }

    // MARK: - CRUD

    func addQuote(text: String, author: String) throws {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let a = author.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !a.isEmpty else {
            throw UserAddedQuoteError.emptyFields
        }
        guard t.count <= Self.maxQuoteLength, a.count <= Self.maxAuthorLength else {
            throw UserAddedQuoteError.tooLong
        }
        if quotes.contains(where: { Self.sameContent($0, text: t, author: a) }) {
            throw UserAddedQuoteError.duplicateQuote
        }
        let nextNumber = (quotes.map(\.displayNumber).max() ?? 0) + 1
        let q = Self.tagQuote(Quote(
            id: UUID().uuidString,
            displayNumber: nextNumber,
            text: t,
            author: a,
            category: Self.categoryDisplayName,
            sourceFile: Self.sourceFileName
        ))
        let snapshot = quotes
        quotes.append(q)
        do {
            try persist()
        } catch {
            quotes = snapshot
            throw error
        }
        AggregatingQuoteProvider.shared.reloadUserQuotes()
    }

    func updateQuote(id: String, text: String, author: String) throws {
        guard let idx = quotes.firstIndex(where: { $0.id == id }) else {
            throw UserAddedQuoteError.notFound
        }
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let a = author.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !a.isEmpty else {
            throw UserAddedQuoteError.emptyFields
        }
        guard t.count <= Self.maxQuoteLength, a.count <= Self.maxAuthorLength else {
            throw UserAddedQuoteError.tooLong
        }
        if quotes.contains(where: { $0.id != id && Self.sameContent($0, text: t, author: a) }) {
            throw UserAddedQuoteError.duplicateQuote
        }
        let old = quotes[idx]
        let updated = Quote(
            id: old.id,
            displayNumber: old.displayNumber,
            text: t,
            author: a,
            category: Self.categoryDisplayName,
            sourceFile: Self.sourceFileName
        )
        let snapshot = quotes
        quotes[idx] = Self.tagQuote(updated)
        do {
            try persist()
        } catch {
            quotes = snapshot
            throw error
        }
        AggregatingQuoteProvider.shared.reloadUserQuotes()
    }

    func deleteQuote(id: String) throws {
        let before = quotes.count
        let snapshot = quotes
        quotes.removeAll { $0.id == id }
        guard quotes.count < before else { throw UserAddedQuoteError.notFound }
        do {
            try persist()
        } catch {
            quotes = snapshot
            throw error
        }
        AggregatingQuoteProvider.shared.reloadUserQuotes()
    }

    // MARK: - Persistence

    private func persist() throws {
        if cannotDecryptExistingCloudFile {
            throw UserAddedQuoteError.iCloudKeychainPending
        }
        let url = try Self.resolvedStorageURL()
        let collection = QuoteCollection(quotes: quotes)
        let data = try JSONEncoder().encode(collection)
        guard let encrypted = UserAddedQuotesEncryption.encrypt(data) else {
            throw UserAddedQuoteError.encryptionFailed
        }
        try encrypted.write(to: url, options: .atomic)
        #if DEBUG
        print("[UserAddedQuotesStore] Wrote \(quotes.count) quote(s) (\(encrypted.count) bytes) → \(url.path)")
        #endif
    }

    private static func tagQuote(_ q: Quote) -> Quote {
        var copy = q
        copy.category = categoryDisplayName
        copy.sourceFile = sourceFileName
        return copy
    }

    /// Same quote body as another entry (trimmed fields; case-insensitive text and author).
    private static func sameContent(_ q: Quote, text: String, author: String) -> Bool {
        q.text.caseInsensitiveCompare(text) == .orderedSame
            && q.author.caseInsensitiveCompare(author) == .orderedSame
    }

    // MARK: - URLs

    private static func localStorageURL() throws -> URL {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw UserAddedQuoteError.storageUnavailable
        }
        let dir = appSupport.appendingPathComponent("InnerWhisper", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(encryptedFileName)
    }

    /// Resolves the ubiquity container off the main queue — `url(forUbiquityContainerIdentifier:)` can block and is not recommended on the main thread.
    private static func ubiquityDocumentsDirectoryURL() -> URL? {
        DispatchQueue.global(qos: .utility).sync {
            guard let base = FileManager.default.url(forUbiquityContainerIdentifier: iCloudContainerIdentifier) else {
                return nil
            }
            return base.appendingPathComponent("Documents", isDirectory: true)
        }
    }

    private static func ensureUbiquitousDownloadIfNeeded(at url: URL) {
        let keys: Set<URLResourceKey> = [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey]
        guard let vals = try? url.resourceValues(forKeys: keys), vals.isUbiquitousItem == true else { return }
        if vals.ubiquitousItemDownloadingStatus == .notDownloaded {
            try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        }
    }

    /// Prefers iCloud `Documents` when the container is available; migrates an existing local file into iCloud once.
    private static func resolvedStorageURL() throws -> URL {
        let local = try localStorageURL()
        guard let uDir = ubiquityDocumentsDirectoryURL() else { return local }

        try FileManager.default.createDirectory(at: uDir, withIntermediateDirectories: true)
        let cloud = uDir.appendingPathComponent(encryptedFileName)
        let fm = FileManager.default

        if fm.fileExists(atPath: cloud.path) {
            return cloud
        }
        if fm.fileExists(atPath: local.path) {
            try? fm.copyItem(at: local, to: cloud)
            try? fm.removeItem(at: local)
        }
        return cloud
    }
}

enum UserAddedQuoteError: LocalizedError {
    case emptyFields
    case tooLong
    case notFound
    case duplicateQuote
    case encryptionFailed
    case storageUnavailable
    /// Encrypted data is present but the AES key has not arrived from iCloud Keychain yet (common on a new device).
    case iCloudKeychainPending

    var errorDescription: String? {
        switch self {
        case .emptyFields:
            return "Quote text and author are required."
        case .tooLong:
            return "Quote or author is too long."
        case .notFound:
            return "That quote could not be found."
        case .duplicateQuote:
            return "You already have this quote with the same author."
        case .encryptionFailed:
            return "Could not save your quote securely. Please try again."
        case .storageUnavailable:
            return "Storage is not available."
        case .iCloudKeychainPending:
            return "Your quotes are still syncing. Ensure iCloud Keychain is on in Settings, wait a few minutes, then open the app again. This protects your existing quotes from being overwritten."
        }
    }
}

extension Notification.Name {
    static let userAddedQuotesDidChange = Notification.Name("InnerWhisper.userAddedQuotesDidChange")
}
