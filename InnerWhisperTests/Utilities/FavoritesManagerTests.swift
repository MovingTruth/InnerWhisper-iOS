//
//  FavoritesManagerTests.swift
//  InnerWhisperTests
//
//  Created for InnerWhisper.
//

import XCTest
@testable import InnerWhisper

/// Unit tests for FavoritesManager.
///
/// Each test creates its own FavoritesManager instance (not .shared) to avoid
/// cross-test state. UserDefaults is cleared for the storage key in setUp/tearDown.
///
/// iCloud (NSUbiquitousKeyValueStore) integration is not tested here — it is
/// unavailable in the test environment. Tests exercise only the UserDefaults-backed behavior.
@MainActor
final class FavoritesManagerTests: XCTestCase {
    /// The UserDefaults key used by FavoritesManager for local storage.
    private static let storageKey = "InnerWhisper.FavoriteQuoteIds"

    override func setUp() async throws {
        try await super.setUp()
        // Start each test with a clean slate
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
    }

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func makeSUT() -> FavoritesManager {
        FavoritesManager(syncsWithICloud: false)
    }

    // MARK: - Initial State

    func testInitialState_NoFavorites_FavoriteIdsIsEmpty() {
        let sut = makeSUT()
        XCTAssertTrue(sut.favoriteIds.isEmpty, "Fresh manager should have no favorites")
    }

    func testIsFavorite_UnknownQuote_ReturnsFalse() {
        let sut = makeSUT()
        XCTAssertFalse(sut.isFavorite("unknown-id"), "Unknown quote should not be a favorite")
    }

    // MARK: - toggleFavorite — add

    func testToggleFavorite_NewQuote_AddedToFavorites() {
        // Given
        let sut = makeSUT()

        // When
        sut.toggleFavorite("quote-001")

        // Then
        XCTAssertTrue(sut.isFavorite("quote-001"))
    }

    func testToggleFavorite_NewQuote_FavoriteIdsCountIncreases() {
        let sut = makeSUT()
        let before = sut.favoriteIds.count

        sut.toggleFavorite("quote-002")

        XCTAssertEqual(sut.favoriteIds.count, before + 1)
    }

    // MARK: - toggleFavorite — remove

    func testToggleFavorite_ExistingQuote_RemovedFromFavorites() {
        // Given
        let sut = makeSUT()
        sut.toggleFavorite("quote-001")
        XCTAssertTrue(sut.isFavorite("quote-001"))

        // When
        sut.toggleFavorite("quote-001")

        // Then
        XCTAssertFalse(sut.isFavorite("quote-001"), "Toggling an existing favorite should remove it")
    }

    func testToggleFavorite_ToggleTwice_RestoresOriginalState() {
        let sut = makeSUT()
        sut.toggleFavorite("quote-001")
        sut.toggleFavorite("quote-001")
        XCTAssertFalse(sut.isFavorite("quote-001"), "Two toggles should leave the quote unfavorited")
        XCTAssertTrue(sut.favoriteIds.isEmpty)
    }

    // MARK: - Multiple favorites

    func testToggleFavorite_MultipleQuotes_AllTrackedIndependently() {
        let sut = makeSUT()
        sut.toggleFavorite("quote-A")
        sut.toggleFavorite("quote-B")
        sut.toggleFavorite("quote-C")

        XCTAssertTrue(sut.isFavorite("quote-A"))
        XCTAssertTrue(sut.isFavorite("quote-B"))
        XCTAssertTrue(sut.isFavorite("quote-C"))
        XCTAssertEqual(sut.favoriteIds.count, 3)
    }

    func testToggleFavorite_RemoveOneOfMany_OthersUnaffected() {
        let sut = makeSUT()
        sut.toggleFavorite("quote-A")
        sut.toggleFavorite("quote-B")
        sut.toggleFavorite("quote-C")

        // Remove B
        sut.toggleFavorite("quote-B")

        XCTAssertTrue(sut.isFavorite("quote-A"), "quote-A should still be favorited")
        XCTAssertFalse(sut.isFavorite("quote-B"), "quote-B should have been removed")
        XCTAssertTrue(sut.isFavorite("quote-C"), "quote-C should still be favorited")
        XCTAssertEqual(sut.favoriteIds.count, 2)
    }

    // MARK: - Persistence via UserDefaults

    func testToggleFavorite_PersistedToUserDefaults() {
        let sut = makeSUT()
        sut.toggleFavorite("quote-persistent")

        // Read directly from UserDefaults to verify persistence
        let stored = UserDefaults.standard.stringArray(forKey: Self.storageKey) ?? []
        XCTAssertTrue(stored.contains("quote-persistent"), "Favorite should be persisted to UserDefaults")
    }

    func testNewInstance_LoadsFavoritesFromUserDefaults() {
        // Given: save some favorites with one instance
        let first = makeSUT()
        first.toggleFavorite("quote-persisted-1")
        first.toggleFavorite("quote-persisted-2")

        // When: create a new instance (simulates app restart)
        let second = makeSUT()

        // Then: favorites are restored from UserDefaults
        XCTAssertTrue(second.isFavorite("quote-persisted-1"), "Favorites should survive a new manager instance")
        XCTAssertTrue(second.isFavorite("quote-persisted-2"))
    }

    // MARK: - @Published property

    func testFavoriteIds_ContainsAddedQuote() {
        let sut = makeSUT()
        sut.toggleFavorite("quote-pub")
        XCTAssertTrue(sut.favoriteIds.contains("quote-pub"))
    }

    func testFavoriteIds_DoesNotContainRemovedQuote() {
        let sut = makeSUT()
        sut.toggleFavorite("quote-pub")
        sut.toggleFavorite("quote-pub")
        XCTAssertFalse(sut.favoriteIds.contains("quote-pub"))
    }
}
