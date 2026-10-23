//
//  QuoteModelTests.swift
//  InnerWhisperTests
//
//  Created for InnerWhisper.
//

import XCTest
@testable import InnerWhisper

/// Unit tests for the Quote model and its extensions.
///
/// Tests shareableText formatting and normalizedContentKey logic —
/// both are pure functions with no external dependencies.
final class QuoteModelTests: XCTestCase {

    // MARK: - Test Helpers

    private func makeQuote(id: String = "test-id", text: String, author: String) -> Quote {
        Quote(id: id, displayNumber: 1, text: text, author: author)
    }

    // MARK: - shareableText

    func testShareableText_ContainsQuoteText() {
        let quote = makeQuote(text: "Be the change you wish to see.", author: "Gandhi")
        XCTAssertTrue(quote.shareableText.contains("Be the change you wish to see."))
    }

    func testShareableText_ContainsAuthor() {
        let quote = makeQuote(text: "Some quote", author: "Eleanor Roosevelt")
        XCTAssertTrue(quote.shareableText.contains("Eleanor Roosevelt"))
    }

    func testShareableText_ContainsAppAttribution() {
        let quote = makeQuote(text: "Any quote", author: "Any Author")
        XCTAssertTrue(
            quote.shareableText.contains("Inner Whisper"),
            "Shareable text should include app attribution"
        )
    }

    func testShareableText_AuthorPrecededByDash() {
        let quote = makeQuote(text: "Quote", author: "Author")
        XCTAssertTrue(
            quote.shareableText.contains("— Author"),
            "Author should be preceded by an em-dash"
        )
    }

    // MARK: - normalizedContentKey — whitespace

    func testNormalizedContentKey_TrimsLeadingAndTrailingWhitespace() {
        let key = Quote.normalizedContentKey(forText: "  Hello world  ")
        XCTAssertEqual(key, Quote.normalizedContentKey(forText: "Hello world"))
    }

    func testNormalizedContentKey_CollapsesInternalWhitespace() {
        let multiSpace = Quote.normalizedContentKey(forText: "Hello   world")
        let singleSpace = Quote.normalizedContentKey(forText: "Hello world")
        XCTAssertEqual(multiSpace, singleSpace)
    }

    func testNormalizedContentKey_CollapsesTabsAndNewlines() {
        let withWhitespace = Quote.normalizedContentKey(forText: "Hello\t\nworld")
        let normal = Quote.normalizedContentKey(forText: "Hello world")
        XCTAssertEqual(withWhitespace, normal)
    }

    // MARK: - normalizedContentKey — Unicode quote normalization

    func testNormalizedContentKey_NormalizesLeftSingleQuote() {
        let unicode = Quote.normalizedContentKey(forText: "\u{2018}Hello\u{2019}")
        let ascii   = Quote.normalizedContentKey(forText: "'Hello'")
        XCTAssertEqual(unicode, ascii, "Left/right single quotes should normalize to ASCII apostrophe")
    }

    func testNormalizedContentKey_NormalizesLeftDoubleQuote() {
        let unicode = Quote.normalizedContentKey(forText: "\u{201C}Hello\u{201D}")
        let ascii   = Quote.normalizedContentKey(forText: "\"Hello\"")
        XCTAssertEqual(unicode, ascii, "Left/right double quotes should normalize to ASCII double-quote")
    }

    // MARK: - normalizedContentKey — case and diacritic folding

    func testNormalizedContentKey_IsCaseInsensitive() {
        let upper = Quote.normalizedContentKey(forText: "HELLO WORLD")
        let lower = Quote.normalizedContentKey(forText: "hello world")
        XCTAssertEqual(upper, lower)
    }

    func testNormalizedContentKey_IsDiacriticInsensitive() {
        let accented = Quote.normalizedContentKey(forText: "café résumé")
        let plain    = Quote.normalizedContentKey(forText: "cafe resume")
        XCTAssertEqual(accented, plain)
    }

    // MARK: - normalizedContentKey — deduplication semantics

    func testNormalizedContentKey_SameQuoteDifferentFormatting_ProducesSameKey() {
        // Simulates the same quote appearing in two different source files with minor formatting differences
        let variant1 = Quote.normalizedContentKey(forText: "  \u{201C}Be yourself\u{201D}  ")
        let variant2 = Quote.normalizedContentKey(forText: "\"Be yourself\"")
        XCTAssertEqual(variant1, variant2)
    }

    func testNormalizedContentKey_DifferentQuotes_ProduceDifferentKeys() {
        let key1 = Quote.normalizedContentKey(forText: "Quote one")
        let key2 = Quote.normalizedContentKey(forText: "Quote two")
        XCTAssertNotEqual(key1, key2)
    }
}
