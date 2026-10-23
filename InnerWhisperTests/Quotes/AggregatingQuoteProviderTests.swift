//
//  AggregatingQuoteProviderTests.swift
//  InnerWhisperTests
//
//  Created for InnerWhisper.
//

import XCTest
@testable import InnerWhisper

/// Unit tests for AggregatingQuoteProvider.
///
/// Each test creates its own provider instance with MockQuoteSource objects
/// so no real file I/O or networking is required.
///
/// Note: loadQuotes() writes a cache file to Application Support. tearDown
/// removes this file so each test begins with a clean cache.
///
/// `InnerWhisper.LastQuoteRefreshDate` is set to **now** in setUp so
/// `refreshInBackgroundIfStale()` does not spawn a network fetch after every
/// cache hit (removing the key makes the cache always “stale” and can slow or
/// confuse tests). Run these tests from Xcode or a normal terminal so
/// CoreSimulatorService is available; a broken simulator connection can make
/// `xcodebuild test` appear to hang indefinitely.
@MainActor
final class AggregatingQuoteProviderTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        deleteCacheFile()
        UserDefaults.standard.set(Date(), forKey: "InnerWhisper.LastQuoteRefreshDate")
        UserDefaults.standard.removeObject(forKey: "InnerWhisper.BrowseQuoteOrderIds")
    }

    override func tearDown() async throws {
        deleteCacheFile()
        UserDefaults.standard.removeObject(forKey: "InnerWhisper.LastQuoteRefreshDate")
        UserDefaults.standard.removeObject(forKey: "InnerWhisper.BrowseQuoteOrderIds")
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func makeSUT(sources: [any QuoteSource]) -> AggregatingQuoteProvider {
        AggregatingQuoteProvider(sources: sources)
    }

    private func makeSource(quotes: [Quote], shouldThrow: Bool = false) -> MockQuoteSource {
        let source = MockQuoteSource()
        source.quotesToReturn = quotes
        source.shouldThrow = shouldThrow
        return source
    }

    private func makeQuotes(count: Int, idPrefix: String = "q") -> [Quote] {
        (1...count).map { i in
            Quote(id: "\(idPrefix)-\(i)", displayNumber: i, text: "Quote \(idPrefix)-\(i)", author: "Author \(i)")
        }
    }

    private func deleteCacheFile() {
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first else { return }
        let inner = appSupport.appendingPathComponent("InnerWhisper", isDirectory: true)
        let aggregated = inner.appendingPathComponent("aggregated_quotes.json")
        let userAdded = inner.appendingPathComponent("user_added_quotes.enc")
        try? FileManager.default.removeItem(at: aggregated)
        try? FileManager.default.removeItem(at: userAdded)
    }

    // MARK: - Single Source

    func testLoadQuotes_SingleSource_PopulatesQuotes() async throws {
        // Given
        let source = makeSource(quotes: makeQuotes(count: 3))
        let sut = makeSUT(sources: [source])

        // When
        try await sut.loadQuotes()

        // Then
        XCTAssertEqual(sut.quoteCount(), 3)
    }

    func testLoadQuotes_SingleSource_GetQuoteReturnsCorrectQuote() async throws {
        // Given
        let quotes = makeQuotes(count: 2)
        let sut = makeSUT(sources: [makeSource(quotes: quotes)])

        // When
        try await sut.loadQuotes()

        // Then: At least one valid quote is retrievable at index 0
        XCTAssertNotNil(sut.getQuote(at: 0))
        XCTAssertFalse(sut.getQuote(at: 0)!.text.isEmpty)
    }

    func testGetAllQuotes_ReturnsAllLoadedQuotes() async throws {
        // Given
        let sut = makeSUT(sources: [makeSource(quotes: makeQuotes(count: 5))])
        try await sut.loadQuotes()

        // When
        let all = sut.getAllQuotes()

        // Then
        XCTAssertEqual(all.count, 5)
    }

    // MARK: - Multiple Sources

    func testLoadQuotes_TwoSources_MergesQuotesFromBoth() async throws {
        // Given
        let source1 = makeSource(quotes: makeQuotes(count: 3, idPrefix: "a"))
        let source2 = makeSource(quotes: makeQuotes(count: 4, idPrefix: "b"))
        let sut = makeSUT(sources: [source1, source2])

        // When
        try await sut.loadQuotes()

        // Then: All 7 unique quotes are available
        XCTAssertEqual(sut.quoteCount(), 7)
    }

    // MARK: - Partial Source Failure

    func testLoadQuotes_OneSourceFails_StillLoadsFromOtherSource() async throws {
        // Given
        let failingSource  = makeSource(quotes: [], shouldThrow: true)
        let workingSource  = makeSource(quotes: makeQuotes(count: 3, idPrefix: "ok"))
        let sut = makeSUT(sources: [failingSource, workingSource])

        // When
        try await sut.loadQuotes()

        // Then: Partial success — quotes from the working source are loaded
        XCTAssertEqual(sut.quoteCount(), 3)
    }

    func testLoadQuotes_AllSourcesFail_ThrowsNoQuotesLoaded() async {
        // Given
        let sut = makeSUT(sources: [
            makeSource(quotes: [], shouldThrow: true),
            makeSource(quotes: [], shouldThrow: true)
        ])

        // When / Then
        do {
            try await sut.loadQuotes()
            XCTFail("Should have thrown QuoteError.noQuotesLoaded")
        } catch QuoteError.noQuotesLoaded {
            // Expected
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - Deduplication

    func testLoadQuotes_DuplicateIDs_OnlyOneKept() async throws {
        // Given: two sources return quotes with the same id
        let dup1 = Quote(id: "dup-1", displayNumber: 1, text: "Unique text A", author: "Author A")
        let dup2 = Quote(id: "dup-1", displayNumber: 2, text: "Unique text B", author: "Author B")
        let sut = makeSUT(sources: [
            makeSource(quotes: [dup1]),
            makeSource(quotes: [dup2])
        ])

        // When
        try await sut.loadQuotes()

        // Then: Only one of the two duplicate-ID quotes survives
        XCTAssertEqual(sut.quoteCount(), 1, "Duplicate IDs should be deduplicated to one quote")
    }

    func testLoadQuotes_DuplicateContent_OnlyOneKept() async throws {
        // Given: two quotes with different IDs but the same text (after normalization)
        let q1 = Quote(id: "content-1", displayNumber: 1, text: "Be the change.", author: "Gandhi")
        let q2 = Quote(id: "content-2", displayNumber: 2, text: "Be the change.", author: "Gandhi")
        let sut = makeSUT(sources: [makeSource(quotes: [q1, q2])])

        // When
        try await sut.loadQuotes()

        // Then
        XCTAssertEqual(sut.quoteCount(), 1, "Duplicate content should be deduplicated")
    }

    func testLoadQuotes_UniqueQuotes_NoneDropped() async throws {
        // Given
        let q1 = Quote(id: "u-1", displayNumber: 1, text: "First unique quote", author: "A")
        let q2 = Quote(id: "u-2", displayNumber: 2, text: "Second unique quote", author: "B")
        let q3 = Quote(id: "u-3", displayNumber: 3, text: "Third unique quote", author: "C")
        let sut = makeSUT(sources: [makeSource(quotes: [q1, q2, q3])])

        // When
        try await sut.loadQuotes()

        // Then
        XCTAssertEqual(sut.quoteCount(), 3, "Unique quotes should not be dropped")
    }

    // MARK: - Index Bounds

    func testGetQuote_ValidIndex_ReturnsQuote() async throws {
        let sut = makeSUT(sources: [makeSource(quotes: makeQuotes(count: 3))])
        try await sut.loadQuotes()
        XCTAssertNotNil(sut.getQuote(at: 0))
        XCTAssertNotNil(sut.getQuote(at: sut.quoteCount() - 1))
    }

    func testGetQuote_NegativeIndex_ReturnsNil() async throws {
        let sut = makeSUT(sources: [makeSource(quotes: makeQuotes(count: 3))])
        try await sut.loadQuotes()
        XCTAssertNil(sut.getQuote(at: -1))
    }

    func testGetQuote_OutOfBoundsIndex_ReturnsNil() async throws {
        let sut = makeSUT(sources: [makeSource(quotes: makeQuotes(count: 3))])
        try await sut.loadQuotes()
        XCTAssertNil(sut.getQuote(at: sut.quoteCount()))
    }

    // MARK: - Force Refresh

    func testRefreshFromSources_UpdatesQuoteCount() async throws {
        // Given: load with 2 quotes
        let source = makeSource(quotes: makeQuotes(count: 2))
        let sut = makeSUT(sources: [source])
        try await sut.loadQuotes()
        XCTAssertEqual(sut.quoteCount(), 2)

        // When: add more quotes and force refresh
        source.quotesToReturn = makeQuotes(count: 5)
        try await sut.refreshQuotesFromSources()

        // Then
        XCTAssertEqual(sut.quoteCount(), 5)
    }
    func testMergedStable_CombinesBundledAndUser_SortedById() {
        let bundled = [
            Quote(id: "b1", displayNumber: 1, text: "Bundled A", author: "A", category: "G", sourceFile: "Quotes_Default"),
        ]
        let user = [
            Quote(id: "u1", displayNumber: 1, text: "User B", author: "Me", category: "User Added", sourceFile: UserAddedQuotesStore.sourceFileName),
        ]
        let merged = AggregatingQuoteProvider.mergedStable(bundled: bundled, user: user)
        XCTAssertEqual(merged.count, 2)
        XCTAssertEqual(merged.map(\.id), ["b1", "u1"])
    }

    func testMergedAndShuffled_CombinesBundledAndUser() {
        let bundled = [
            Quote(id: "b1", displayNumber: 1, text: "Bundled A", author: "A", category: "G", sourceFile: "Quotes_Default"),
        ]
        let user = [
            Quote(id: "u1", displayNumber: 1, text: "User B", author: "Me", category: "User Added", sourceFile: UserAddedQuotesStore.sourceFileName),
        ]
        let merged = AggregatingQuoteProvider.mergedAndShuffled(bundled: bundled, user: user)
        XCTAssertEqual(merged.count, 2)
        let ids = Set(merged.map(\.id))
        XCTAssertEqual(ids, ["b1", "u1"])
    }

    // MARK: - Browse order persistence

    func testLoadQuotes_Twice_PreservesBrowseOrder() async throws {
        let source = makeSource(quotes: makeQuotes(count: 5))
        let sut = makeSUT(sources: [source])
        try await sut.loadQuotes()
        let firstOrder = sut.getAllQuotes().map(\.id)

        try await sut.loadQuotes()
        let secondOrder = sut.getAllQuotes().map(\.id)

        XCTAssertEqual(firstOrder, secondOrder)
    }

    func testRefreshFromSources_NewQuotes_ReshufflesMembership() async throws {
        let source = makeSource(quotes: makeQuotes(count: 2, idPrefix: "a"))
        let sut = makeSUT(sources: [source])
        try await sut.loadQuotes()
        XCTAssertEqual(Set(sut.getAllQuotes().map(\.id)), Set((1...2).map { "a-\($0)" }))

        source.quotesToReturn = makeQuotes(count: 3, idPrefix: "a")
        try await sut.refreshQuotesFromSources()

        XCTAssertEqual(sut.quoteCount(), 3)
        XCTAssertEqual(Set(sut.getAllQuotes().map(\.id)), Set((1...3).map { "a-\($0)" }))
    }

}
