//
//  QuoteManagerTests.swift
//  InnerWhisperTests
//
//  Created for InnerWhisper.
//

import XCTest
@testable import InnerWhisper

/// Unit tests for QuoteManager.
///
/// These tests verify quote loading, retrieval, and error handling.
/// Note: These tests use the actual Quotes_Default.json file from the bundle.
@MainActor
final class QuoteManagerTests: XCTestCase {
    var sut: QuoteManager!

    override func setUp() {
        super.setUp()
        sut = QuoteManager.shared
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Loading Tests

    func testLoadQuotes_WithValidJSON_LoadsSuccessfully() async throws {
        // When
        try await sut.loadQuotes()

        // Then
        XCTAssertGreaterThan(sut.quoteCount(), 0, "Should load at least one quote")
    }

    func testQuoteCount_AfterLoading_ReturnsCorrectCount() async throws {
        // Given
        try await sut.loadQuotes()

        // When
        let count = sut.quoteCount()

        // Then
        XCTAssertGreaterThanOrEqual(count, 1, "Should load at least one quote from Quotes_Default.json")
    }

    // MARK: - Retrieval Tests

    func testGetQuote_WithValidIndex_ReturnsQuote() async throws {
        // Given
        try await sut.loadQuotes()

        // When
        let quote = sut.getQuote(at: 0)

        // Then
        XCTAssertNotNil(quote, "Should return a quote at valid index")
        XCTAssertFalse(quote!.text.isEmpty, "Quote text should not be empty")
        XCTAssertFalse(quote!.author.isEmpty, "Quote author should not be empty")
    }

    func testGetQuote_WithNegativeIndex_ReturnsNil() async throws {
        // Given
        try await sut.loadQuotes()

        // When
        let quote = sut.getQuote(at: -1)

        // Then
        XCTAssertNil(quote, "Should return nil for negative index")
    }

    func testGetQuote_WithOutOfBoundsIndex_ReturnsNil() async throws {
        // Given
        try await sut.loadQuotes()
        let count = sut.quoteCount()

        // When
        let quote = sut.getQuote(at: count + 10)

        // Then
        XCTAssertNil(quote, "Should return nil for out of bounds index")
    }

    func testGetAllQuotes_ReturnsAllLoadedQuotes() async throws {
        // Given
        try await sut.loadQuotes()

        // When
        let allQuotes = sut.getAllQuotes()

        // Then
        XCTAssertGreaterThanOrEqual(allQuotes.count, 1, "Should return at least one quote")
        XCTAssertTrue(allQuotes.allSatisfy { !$0.text.isEmpty }, "All quotes should have text")
        XCTAssertTrue(allQuotes.allSatisfy { !$0.author.isEmpty }, "All quotes should have authors")
    }

    func testGetQuote_AtLastValidIndex_ReturnsQuote() async throws {
        // Given
        try await sut.loadQuotes()
        let count = sut.quoteCount()

        // When
        let lastQuote = sut.getQuote(at: count - 1)

        // Then
        XCTAssertNotNil(lastQuote, "Should return a quote at the last valid index")
        XCTAssertFalse(lastQuote!.text.isEmpty, "Quote at last index should have text")
    }

    // MARK: - Quote Content Validation Tests

    func testLoadedQuotes_HaveUniqueIDs() async throws {
        // Given
        try await sut.loadQuotes()
        let quotes = sut.getAllQuotes()

        // When
        let uniqueIDs = Set(quotes.map { $0.id })

        // Then
        XCTAssertEqual(uniqueIDs.count, quotes.count, "All quote IDs should be unique")
    }

    func testLoadedQuotes_HaveExpectedAuthors() async throws {
        // Given
        try await sut.loadQuotes()
        let quotes = sut.getAllQuotes()

        // When/Then: Verify the public sample catalogue is present.
        let authors = quotes.map { $0.author }
        XCTAssertTrue(authors.contains("Inner Whisper"), "Should contain a portfolio sample quote")
    }

    // MARK: - Singleton Tests

    func testShared_ReturnsSameInstance() {
        // Given
        let instance1 = QuoteManager.shared
        let instance2 = QuoteManager.shared

        // Then
        XCTAssertTrue(instance1 === instance2, "shared should return the same instance")
    }
}
