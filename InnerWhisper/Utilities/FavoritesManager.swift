//
//  FavoritesManager.swift
//  InnerWhisper
//
//  Created for InnerWhisper.
//

import Foundation

/// Manages the user's favorite quotes, syncing them across devices via iCloud
/// Key-Value Store with UserDefaults as the local cache/fallback.
///
/// **Sync strategy:**
/// - On launch: local and remote sets are unioned so no favorites are lost
///   when iCloud activates for the first time.
/// - On toggle: written to both stores immediately.
/// - On external push: unioned with the current in-memory set (so an unfavorite
///   on one device won't silently vanish on another during the same session).
///
/// **Prerequisite:** the app target must have the iCloud → Key-value storage
/// capability enabled in Xcode Signing & Capabilities.
@MainActor
@Observable
final class FavoritesManager {

    /// The shared singleton instance.
    static let shared = FavoritesManager()

    private static let storageKey = "InnerWhisper.FavoriteQuoteIds"
    private let iCloud = NSUbiquitousKeyValueStore.default
    private let userDefaults: UserDefaults
    private let syncsWithICloud: Bool

    /// The set of favorited quote UUIDs. Observed automatically by any view that reads it.
    var favoriteIds: Set<String>

    /// `true` if iCloud Key-Value Store is available and accepted the last sync request.
    private(set) var iCloudAvailable = false

    /// Retained token from the block-based NotificationCenter observer.
    /// nonisolated(unsafe) so deinit (which is implicitly nonisolated) can access it.
    /// @ObservationIgnored because it is bookkeeping, not UI state.
    @ObservationIgnored
    nonisolated(unsafe) private var iCloudObserverToken: NSObjectProtocol?

    init(
        userDefaults: UserDefaults = .standard,
        syncsWithICloud: Bool = true
    ) {
        self.userDefaults = userDefaults
        self.syncsWithICloud = syncsWithICloud
        #if DEBUG
        print("[FavoritesManager] Initialising...")
        #endif

        // Merge local and remote on startup so neither device loses favorites.
        let local = Set(userDefaults.stringArray(forKey: Self.storageKey) ?? [])
        let remote = syncsWithICloud
            ? Set(iCloud.array(forKey: Self.storageKey) as? [String] ?? [])
            : []
        favoriteIds = local.union(remote)
        #if DEBUG
        print("[FavoritesManager] Startup — local: \(local.count), iCloud: \(remote.count), merged: \(favoriteIds.count)")
        #endif

        // Activate iCloud sync.
        #if DEBUG
        print("[FavoritesManager] Requesting iCloud sync...")
        #endif
        iCloudAvailable = syncsWithICloud && iCloud.synchronize()
        #if DEBUG
        print("[FavoritesManager] iCloud available: \(iCloudAvailable)")
        #endif

        // Write the merged set back to both stores immediately.
        if !favoriteIds.isEmpty {
            #if DEBUG
            print("[FavoritesManager] Writing merged set back to both stores")
            #endif
            writeToStores(favoriteIds)
        }

        // Listen for changes pushed from other devices.
        // The returned token is stored in iCloudObserverToken so the observation
        // stays active for the lifetime of this instance and can be cleaned up on deinit.
        if syncsWithICloud {
            iCloudObserverToken = NotificationCenter.default.addObserver(
                forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                object: iCloud,
                queue: .main
            ) { [weak self] notification in
                // Notification is posted on the main queue, but wrap in a Task
                // to satisfy @MainActor isolation.
                Task { @MainActor [weak self] in
                    self?.handleExternalChange(notification)
                }
            }
        }

        #if DEBUG
        print("[FavoritesManager] Observer registered for iCloud change notifications")
        #endif
    }

    deinit {
        if let token = iCloudObserverToken {
            NotificationCenter.default.removeObserver(token)
        }
    }

    // MARK: - Public Interface

    /// Returns whether the given quote UUID is currently favorited.
    func isFavorite(_ quoteId: String) -> Bool {
        favoriteIds.contains(quoteId)
    }

    /// Adds the quote to favorites if not present; removes it if already favorited.
    func toggleFavorite(_ quoteId: String) {
        let wasAdded = !favoriteIds.contains(quoteId)
        if wasAdded {
            favoriteIds.insert(quoteId)
        } else {
            favoriteIds.remove(quoteId)
        }
        #if DEBUG
        print("[FavoritesManager] \(wasAdded ? "Added" : "Removed") quote \(quoteId) — total: \(favoriteIds.count)")
        #endif
        writeToStores(favoriteIds)
    }

    /// Asks iCloud to push/pull the latest data. Call when the app becomes active.
    func synchronize() {
        guard syncsWithICloud else { return }
        #if DEBUG
        print("[FavoritesManager] Sync requested (app foregrounded)...")
        #endif
        let success = iCloud.synchronize()
        iCloudAvailable = success
        #if DEBUG
        print("[FavoritesManager] Sync \(success ? "accepted by iCloud" : "FAILED — iCloud unavailable")")
        #endif
    }

    // MARK: - Private

    /// Handles a push notification from iCloud (changes made on another device).
    private func handleExternalChange(_ notification: Notification) {
        guard let reason = notification.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else {
            #if DEBUG
            print("[FavoritesManager] External change notification received with no reason — ignoring")
            #endif
            return
        }

        let reasonLabel: String
        switch reason {
        case NSUbiquitousKeyValueStoreServerChange:       reasonLabel = "ServerChange"
        case NSUbiquitousKeyValueStoreInitialSyncChange:  reasonLabel = "InitialSyncChange"
        case NSUbiquitousKeyValueStoreQuotaViolationChange: reasonLabel = "QuotaViolation"
        case NSUbiquitousKeyValueStoreAccountChange:      reasonLabel = "AccountChange"
        default:                                          reasonLabel = "Unknown(\(reason))"
        }
        #if DEBUG
        print("[FavoritesManager] External change received — reason: \(reasonLabel)")
        #endif

        switch reason {
        case NSUbiquitousKeyValueStoreQuotaViolationChange:
            #if DEBUG
            print("[FavoritesManager] ERROR: iCloud KV quota exceeded — favorites will not sync until space is freed")
            #endif
            return

        case NSUbiquitousKeyValueStoreAccountChange:
            // iCloud account changed; replace entirely with whatever is in iCloud now.
            let remote = Set(iCloud.array(forKey: Self.storageKey) as? [String] ?? [])
            #if DEBUG
            print("[FavoritesManager] Account changed — replacing \(favoriteIds.count) local favorites with \(remote.count) from new account")
            #endif
            favoriteIds = remote
            userDefaults.set(Array(favoriteIds), forKey: Self.storageKey)
            return

        case NSUbiquitousKeyValueStoreServerChange, NSUbiquitousKeyValueStoreInitialSyncChange:
            break

        default:
            #if DEBUG
            print("[FavoritesManager] Unhandled change reason \(reason) — ignoring")
            #endif
            return
        }

        // Only act if our specific key was among those that changed.
        let changedKeys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? []
        #if DEBUG
        print("[FavoritesManager] Changed keys: \(changedKeys)")
        #endif
        guard changedKeys.contains(Self.storageKey) else {
            #if DEBUG
            print("[FavoritesManager] Our key not in changed set — nothing to do")
            #endif
            return
        }

        let remote = Set(iCloud.array(forKey: Self.storageKey) as? [String] ?? [])
        let before = favoriteIds.count
        // Union: remote additions appear locally; local unfavorites are preserved
        // within the current session. A deliberate unfavorite on the other device
        // will propagate on the next app launch via the startup merge.
        favoriteIds = favoriteIds.union(remote)
        userDefaults.set(Array(favoriteIds), forKey: Self.storageKey)
        #if DEBUG
        print("[FavoritesManager] Merge complete — remote: \(remote.count), local before: \(before), after: \(favoriteIds.count)")
        #endif
    }

    /// Writes the given set to both UserDefaults (local cache) and iCloud KV Store.
    private func writeToStores(_ ids: Set<String>) {
        #if DEBUG
        print("[FavoritesManager] Writing \(ids.count) favorites to UserDefaults and iCloud...")
        #endif
        let array = Array(ids)
        userDefaults.set(array, forKey: Self.storageKey)
        guard syncsWithICloud else { return }
        iCloud.set(array, forKey: Self.storageKey)
        let success = iCloud.synchronize()
        #if DEBUG
        print("[FavoritesManager] Write \(success ? "succeeded" : "FAILED — iCloud sync returned false")")
        #endif
    }
}
