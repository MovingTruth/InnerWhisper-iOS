//
//  MockQuoteProvider.swift
//  InnerWhisperTests
//
//  Created for InnerWhisper.
//

import Foundation
@testable import InnerWhisper

/// Mock implementation of QuoteProvider for testing.
///
/// This mock allows tests to control quote data and simulate various scenarios
/// including success, failure, and edge cases without relying on file I/O.
///
/// ## Usage Example
/// ```swift
/// let mock = MockQuoteProvider()
/// mock.quotes = [Quote(id: "test-quote-1", displayNumber: 1, text: "Test", author: "Tester")]
/// let viewModel = QuoteViewModel(quoteProvider: mock)
/// XCTAssertEqual(viewModel.totalCount, 1)
/// ```
final class MockQuoteProvider: QuoteProvider {
    /// The quotes to return from this mock.
    var quotes: [Quote] = []

    /// Whether loadQuotes() should throw an error.
    var shouldThrowError = false

    /// The error to throw if shouldThrowError is true.
    var errorToThrow: Error = QuoteError.fileNotFound

    /// Number of times loadQuotes() was called.
    var loadQuotesCallCount = 0

    func getQuote(at index: Int) -> Quote? {
        guard index >= 0 && index < quotes.count else {
            return nil
        }
        return quotes[index]
    }

    func getAllQuotes() -> [Quote] {
        return quotes
    }

    func quoteCount() -> Int {
        return quotes.count
    }

    func loadQuotes() async throws {
        loadQuotesCallCount += 1

        if shouldThrowError {
            throw errorToThrow
        }
    }

    func refreshQuotesFromSources() async throws {
        try await loadQuotes()
    }
}
