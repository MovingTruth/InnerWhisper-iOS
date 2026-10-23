//
//  MockQuoteSource.swift
//  InnerWhisperTests
//
//  Created for InnerWhisper.
//

import Foundation
@testable import InnerWhisper

/// Mock implementation of QuoteSource for testing AggregatingQuoteProvider in isolation.
///
/// Allows tests to supply specific quotes or simulate errors without any file I/O or networking.
final class MockQuoteSource: QuoteSource {
    /// Quotes to return from fetchQuotes(). Defaults to empty.
    var quotesToReturn: [Quote] = []

    /// When true, fetchQuotes() throws errorToThrow instead of returning quotes.
    var shouldThrow = false

    /// The error thrown when shouldThrow is true.
    var errorToThrow: Error = QuoteError.fileNotFound

    /// Number of times fetchQuotes() has been called.
    var fetchCallCount = 0

    func fetchQuotes() async throws -> [Quote] {
        fetchCallCount += 1
        if shouldThrow {
            throw errorToThrow
        }
        return quotesToReturn
    }
}
