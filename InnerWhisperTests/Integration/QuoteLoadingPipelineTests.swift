//
//  QuoteLoadingPipelineTests.swift
//  InnerWhisperTests
//
//  Created for InnerWhisper.
//

import XCTest
@testable import InnerWhisper

/// Integration tests verifying the end-to-end quote loading pipeline:
///
///   MockQuoteSource → AggregatingQuoteProvider → QuoteViewModel
///
/// Unlike unit tests, these tests exercise all three layers together to catch
/// integration bugs that isolated unit tests would not surface.
@MainActor
final class QuoteLoadingPipelineTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        deleteCacheFile()
        UserDefaults.standard.removeObject(forKey: "InnerWhisper.LastQuoteRefreshDate")
        UserDefaults.standard.removeObject(forKey: UserQuoteBrowseSettings.browseUserQuotesOnlyKey)
    }

    override func tearDown() async throws {
        deleteCacheFile()
        UserDefaults.standard.removeObject(forKey: "InnerWhisper.LastQuoteRefreshDate")
        UserDefaults.standard.removeObject(forKey: UserQuoteBrowseSettings.browseUserQuotesOnlyKey)
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func makePipeline(quotes: [Quote]) -> (provider: AggregatingQuoteProvider, viewModel: QuoteViewModel) {
        let source = MockQuoteSource()
        source.quotesToReturn = quotes
        let provider = AggregatingQuoteProvider(sources: [source])
        let viewModel = QuoteViewModel(quoteProvider: provider)
        return (provider, viewModel)
    }

    private func makePipeline(sources: [any QuoteSource]) -> (provider: AggregatingQuoteProvider, viewModel: QuoteViewModel) {
        let provider = AggregatingQuoteProvider(sources: sources)
        let viewModel = QuoteViewModel(quoteProvider: provider)
        return (provider, viewModel)
    }

    private func makeQuotes(count: Int, idPrefix: String = "p") -> [Quote] {
        (1...count).map { i in
            Quote(id: "\(idPrefix)-\(i)", displayNumber: i, text: "Pipeline quote \(idPrefix)-\(i)", author: "Author \(i)")
        }
    }

    private func deleteCacheFile() {
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first else { return }
        let url = appSupport
            .appendingPathComponent("InnerWhisper")
            .appendingPathComponent("aggregated_quotes.json")
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Happy path

    func testPipeline_QuotesLoadFromSource_ViewModelDisplaysCorrectCount() async {
        // Given
        let quotes = makeQuotes(count: 5)
        let (_, viewModel) = makePipeline(quotes: quotes)

        // When
        await viewModel.loadQuotes()

        // Then
        XCTAssertTrue(viewModel.loadingState.isSuccess, "ViewModel should be in success state")
        XCTAssertEqual(viewModel.totalCount, 5, "ViewModel should reflect the 5 quotes from the source")
        XCTAssertNil(viewModel.errorMessage)
    }

    func testPipeline_QuotesLoadFromSource_FirstQuoteAccessible() async {
        // Given
        let (_, viewModel) = makePipeline(quotes: makeQuotes(count: 3))

        // When
        await viewModel.loadQuotes()

        // Then
        XCTAssertNotNil(viewModel.currentQuote, "A current quote should be accessible after loading")
        XCTAssertFalse(viewModel.currentQuote!.text.isEmpty)
    }

    // MARK: - Two sources merged

    func testPipeline_TwoSources_AllQuotesAccessibleViaNavigation() async {
        // Given
        let source1 = MockQuoteSource()
        source1.quotesToReturn = makeQuotes(count: 3, idPrefix: "s1")
        let source2 = MockQuoteSource()
        source2.quotesToReturn = makeQuotes(count: 2, idPrefix: "s2")
        let (_, viewModel) = makePipeline(sources: [source1, source2])

        // When
        await viewModel.loadQuotes()

        // Then
        XCTAssertEqual(viewModel.totalCount, 5, "All quotes from both sources should be merged")

        // Navigate through all quotes to verify they are reachable
        var seenIds = Set<String>()
        for i in 0..<viewModel.totalCount {
            _ = viewModel.goToQuote(at: i)
            await Task.yield()
            if let id = viewModel.currentQuote?.id {
                seenIds.insert(id)
            }
        }
        XCTAssertEqual(seenIds.count, 5, "All 5 unique quotes should be navigable")
    }

    // MARK: - Error propagation

    func testPipeline_AllSourcesFail_ViewModelShowsErrorState() async {
        // Given
        let failSource = MockQuoteSource()
        failSource.shouldThrow = true
        failSource.errorToThrow = QuoteError.fileNotFound
        let (_, viewModel) = makePipeline(sources: [failSource])

        // When
        await viewModel.loadQuotes()

        // Then
        XCTAssertTrue(viewModel.loadingState.isFailure, "ViewModel should be in failure state")
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.totalCount, 0)
    }

    func testPipeline_PartialSourceFailure_ViewModelShowsAvailableQuotes() async {
        // Given
        let failSource = MockQuoteSource()
        failSource.shouldThrow = true
        let workingSource = MockQuoteSource()
        workingSource.quotesToReturn = makeQuotes(count: 4, idPrefix: "ok")
        let (_, viewModel) = makePipeline(sources: [failSource, workingSource])

        // When
        await viewModel.loadQuotes()

        // Then: partial success — 4 quotes from the working source are displayed
        XCTAssertTrue(viewModel.loadingState.isSuccess, "Partial source failure should still result in success state")
        XCTAssertEqual(viewModel.totalCount, 4)
    }

    // MARK: - Deduplication reaches ViewModel

    func testPipeline_DuplicateQuotes_ViewModelCountReflectsDeduplicated() async {
        // Given: both sources return the same two quotes
        let quotes = makeQuotes(count: 2, idPrefix: "dup")
        let source1 = MockQuoteSource()
        source1.quotesToReturn = quotes
        let source2 = MockQuoteSource()
        source2.quotesToReturn = quotes  // exact duplicates
        let (_, viewModel) = makePipeline(sources: [source1, source2])

        // When
        await viewModel.loadQuotes()

        // Then: ViewModel sees deduplicated count, not 4
        XCTAssertEqual(viewModel.totalCount, 2, "Duplicate quotes should be deduplicated before reaching ViewModel")
    }
}
