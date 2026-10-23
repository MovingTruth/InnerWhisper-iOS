//
//  QuoteViewModelTests.swift
//  InnerWhisperTests
//
//  Created for InnerWhisper.
//

import XCTest
@testable import InnerWhisper

/// Unit tests for QuoteViewModel.
///
/// These tests verify quote navigation, error handling, loading states,
/// and accessibility features using a mock quote provider.
@MainActor
final class QuoteViewModelTests: XCTestCase {
    var sut: QuoteViewModel!
    var mockProvider: MockQuoteProvider!

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: UserQuoteBrowseSettings.browseUserQuotesOnlyKey)
        UserDefaults.standard.removeObject(forKey: "InnerWhisper.CurrentQuoteIndex")
        mockProvider = MockQuoteProvider()
    }

    override func tearDown() {
        sut = nil
        mockProvider = nil
        UserDefaults.standard.removeObject(forKey: UserQuoteBrowseSettings.browseUserQuotesOnlyKey)
        UserDefaults.standard.removeObject(forKey: "InnerWhisper.CurrentQuoteIndex")
        super.tearDown()
    }

    // MARK: - Loading Tests

    func testLoadQuotes_WithValidQuotes_LoadsSuccessfully() async {
        // Given
        mockProvider.quotes = [
            Quote(id: "test-quote-1", displayNumber: 1, text: "Quote 1", author: "Author 1"),
            Quote(id: "test-quote-2", displayNumber: 2, text: "Quote 2", author: "Author 2")
        ]
        sut = QuoteViewModel(quoteProvider: mockProvider)

        // When
        await sut.loadQuotes()

        // Then
        XCTAssertEqual(sut.totalCount, 2)
        XCTAssertTrue(sut.loadingState.isSuccess)
        XCTAssertEqual(sut.currentIndex, 0)
        XCTAssertNil(sut.errorMessage)
    }

    func testLoadQuotes_WithNoQuotes_ShowsError() async {
        // Given
        mockProvider.quotes = []
        sut = QuoteViewModel(quoteProvider: mockProvider)

        // When
        await sut.loadQuotes()

        // Then
        XCTAssertTrue(sut.loadingState.isFailure)
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertEqual(sut.totalCount, 0)
    }

    func testLoadQuotes_WithLoadError_ShowsError() async {
        // Given
        mockProvider.shouldThrowError = true
        mockProvider.errorToThrow = QuoteError.fileNotFound
        sut = QuoteViewModel(quoteProvider: mockProvider)

        // When
        await sut.loadQuotes()

        // Then
        XCTAssertTrue(sut.loadingState.isFailure)
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertEqual(sut.errorMessage, QuoteError.fileNotFound.errorDescription)
    }

    // MARK: - Navigation Tests

    func testGoToNext_IncreasesIndex() async {
        // Given
        mockProvider.quotes = createSampleQuotes(count: 3)
        sut = QuoteViewModel(quoteProvider: mockProvider)
        await sut.loadQuotes()
        XCTAssertEqual(sut.currentIndex, 0)

        // When
        sut.goToNext()
        await Task.yield()

        // Then
        XCTAssertEqual(sut.currentIndex, 1)
    }

    func testGoToNext_AtEnd_WrapsToBeginning() async {
        // Given
        mockProvider.quotes = createSampleQuotes(count: 3)
        sut = QuoteViewModel(quoteProvider: mockProvider)
        await sut.loadQuotes()
        sut.goToQuote(at: 2)
        await Task.yield()

        // When
        sut.goToNext()
        await Task.yield()

        // Then
        XCTAssertEqual(sut.currentIndex, 0, "Should wrap to first quote")
    }

    func testGoToNext_WithNoQuotes_DoesNothing() {
        // Given
        mockProvider.quotes = []
        sut = QuoteViewModel(quoteProvider: mockProvider)

        // When
        sut.goToNext()

        // Then
        XCTAssertEqual(sut.currentIndex, 0)
    }

    func testGoToPrevious_DecreasesIndex() async {
        // Given
        mockProvider.quotes = createSampleQuotes(count: 3)
        sut = QuoteViewModel(quoteProvider: mockProvider)
        await sut.loadQuotes()
        sut.goToQuote(at: 2)
        await Task.yield()

        // When
        sut.goToPrevious()
        await Task.yield()

        // Then
        XCTAssertEqual(sut.currentIndex, 1)
    }

    func testGoToPrevious_AtBeginning_WrapsToEnd() async {
        // Given
        mockProvider.quotes = createSampleQuotes(count: 3)
        sut = QuoteViewModel(quoteProvider: mockProvider)
        await sut.loadQuotes()
        XCTAssertEqual(sut.currentIndex, 0)

        // When
        sut.goToPrevious()
        await Task.yield()

        // Then
        XCTAssertEqual(sut.currentIndex, 2, "Should wrap to last quote")
    }

    func testGoToPrevious_WithNoQuotes_DoesNothing() {
        // Given
        mockProvider.quotes = []
        sut = QuoteViewModel(quoteProvider: mockProvider)

        // When
        sut.goToPrevious()

        // Then
        XCTAssertEqual(sut.currentIndex, 0)
    }

    func testGoToQuote_WithValidIndex_ReturnsTrue() async {
        // Given
        mockProvider.quotes = createSampleQuotes(count: 5)
        sut = QuoteViewModel(quoteProvider: mockProvider)
        await sut.loadQuotes()

        // When
        let result = sut.goToQuote(at: 3)
        await Task.yield()

        // Then
        XCTAssertTrue(result)
        XCTAssertEqual(sut.currentIndex, 3)
    }

    func testGoToQuote_WithInvalidIndex_ReturnsFalse() async {
        // Given
        mockProvider.quotes = createSampleQuotes(count: 3)
        sut = QuoteViewModel(quoteProvider: mockProvider)
        await sut.loadQuotes()

        // When
        let resultNegative = sut.goToQuote(at: -1)
        let resultTooHigh = sut.goToQuote(at: 10)

        // Then
        XCTAssertFalse(resultNegative)
        XCTAssertFalse(resultTooHigh)
        XCTAssertEqual(sut.currentIndex, 0, "Index should not change")
    }

    // MARK: - Current Quote Tests

    func testCurrentQuote_ReturnsCorrectQuote() async {
        // Given
        let quotes = createSampleQuotes(count: 3)
        mockProvider.quotes = quotes
        sut = QuoteViewModel(quoteProvider: mockProvider)
        await sut.loadQuotes()

        // When
        sut.goToQuote(at: 1)
        await Task.yield()

        // Then
        XCTAssertEqual(sut.currentQuote?.id, quotes[1].id)
        XCTAssertEqual(sut.currentQuote?.text, quotes[1].text)
    }

    // MARK: - Computed Properties Tests

    func testPositionText_WithQuotes_ReturnsCorrectFormat() async {
        // Given
        mockProvider.quotes = createSampleQuotes(count: 10)
        sut = QuoteViewModel(quoteProvider: mockProvider)
        await sut.loadQuotes()
        sut.goToQuote(at: 4)
        await Task.yield()

        // When
        let positionText = sut.positionText

        // Then
        XCTAssertEqual(positionText, "5 / 10")
    }

    func testPositionText_WithNoQuotes_ReturnsZero() {
        // Given
        mockProvider.quotes = []
        sut = QuoteViewModel(quoteProvider: mockProvider)

        // When
        let positionText = sut.positionText

        // Then
        XCTAssertEqual(positionText, "0 / 0")
    }

    func testPositionAccessibilityLabel_WithQuotes_ReturnsReadableText() async {
        // Given
        mockProvider.quotes = createSampleQuotes(count: 15)
        sut = QuoteViewModel(quoteProvider: mockProvider)
        await sut.loadQuotes()
        sut.goToQuote(at: 2)
        await Task.yield()

        // When
        let label = sut.positionAccessibilityLabel

        // Then
        XCTAssertEqual(label, "Quote 3 of 15")
    }

    func testPositionAccessibilityLabel_WithNoQuotes_ReturnsNoQuotesMessage() {
        // Given
        mockProvider.quotes = []
        sut = QuoteViewModel(quoteProvider: mockProvider)

        // When
        let label = sut.positionAccessibilityLabel

        // Then
        XCTAssertEqual(label, "No quotes available")
    }

    func testCanGoToNext_WithQuotes_ReturnsTrue() async {
        // Given
        mockProvider.quotes = createSampleQuotes(count: 3)
        sut = QuoteViewModel(quoteProvider: mockProvider)
        await sut.loadQuotes()

        // Then
        XCTAssertTrue(sut.canGoToNext)
    }

    func testCanGoToNext_WithNoQuotes_ReturnsFalse() {
        // Given
        mockProvider.quotes = []
        sut = QuoteViewModel(quoteProvider: mockProvider)

        // Then
        XCTAssertFalse(sut.canGoToNext)
    }

    func testCanGoToPrevious_WithQuotes_ReturnsTrue() async {
        // Given
        mockProvider.quotes = createSampleQuotes(count: 3)
        sut = QuoteViewModel(quoteProvider: mockProvider)
        await sut.loadQuotes()

        // Then
        XCTAssertTrue(sut.canGoToPrevious)
    }

    func testCanGoToPrevious_WithNoQuotes_ReturnsFalse() {
        // Given
        mockProvider.quotes = []
        sut = QuoteViewModel(quoteProvider: mockProvider)

        // Then
        XCTAssertFalse(sut.canGoToPrevious)
    }

    // MARK: - Retry Tests

    func testLoadQuotes_AfterFailure_CanRecover() async {
        // Given
        mockProvider.shouldThrowError = true
        sut = QuoteViewModel(quoteProvider: mockProvider)
        await sut.loadQuotes()
        XCTAssertTrue(sut.loadingState.isFailure)
        let callCountAfterFirstLoad = mockProvider.loadQuotesCallCount

        // When
        mockProvider.shouldThrowError = false
        mockProvider.quotes = createSampleQuotes(count: 3)
        await sut.loadQuotes()

        // Then
        XCTAssertEqual(mockProvider.loadQuotesCallCount, callCountAfterFirstLoad + 1)
        XCTAssertTrue(sut.loadingState.isSuccess)
        XCTAssertNil(sut.errorMessage)
    }

    // MARK: - Error Recoverability Tests

    func testIsErrorRecoverable_ForFileNotFound_ReturnsFalse() async {
        // Given
        mockProvider.shouldThrowError = true
        mockProvider.errorToThrow = QuoteError.fileNotFound
        sut = QuoteViewModel(quoteProvider: mockProvider)

        // When
        await sut.loadQuotes()

        // Then
        XCTAssertFalse(sut.isErrorRecoverable)
    }

    // MARK: - Browse filter (shared with notifications)

    func testFilterQuotesMatchingMainBrowser_WhenMyQuotesOnlyOff_ReturnsAll() {
        let bundled = Quote(
            id: "a",
            displayNumber: 1,
            text: "t",
            author: "x",
            category: "G",
            sourceFile: "Quotes_Default"
        )
        let user = Quote(
            id: "b",
            displayNumber: 1,
            text: "t",
            author: "y",
            category: "User Added",
            sourceFile: UserAddedQuotesStore.sourceFileName
        )
        let out = UserQuoteBrowseSettings.filterQuotesMatchingMainBrowser([bundled, user])
        XCTAssertEqual(out.count, 2)
    }

    func testFilterQuotesMatchingMainBrowser_WhenMyQuotesOnlyOn_ReturnsUserAddedOnly() {
        UserDefaults.standard.set(true, forKey: UserQuoteBrowseSettings.browseUserQuotesOnlyKey)
        let bundled = Quote(
            id: "a",
            displayNumber: 1,
            text: "t",
            author: "x",
            category: "G",
            sourceFile: "Quotes_Default"
        )
        let user = Quote(
            id: "b",
            displayNumber: 1,
            text: "t",
            author: "y",
            category: "User Added",
            sourceFile: UserAddedQuotesStore.sourceFileName
        )
        let out = UserQuoteBrowseSettings.filterQuotesMatchingMainBrowser([bundled, user])
        XCTAssertEqual(out.count, 1)
        XCTAssertEqual(out.first?.id, "b")
    }

    // MARK: - Helper Methods

    private func createSampleQuotes(count: Int) -> [Quote] {
        return (1...count).map { index in
            Quote(id: "test-quote-\(index)", displayNumber: index, text: "Quote \(index)", author: "Author \(index)")
        }
    }
}
