//
//  QuoteErrorTests.swift
//  InnerWhisperTests
//
//  Created for InnerWhisper.
//

import XCTest
@testable import InnerWhisper

/// Unit tests for QuoteError.
///
/// Verifies error descriptions, recoverability flags, and failure reasons
/// for all five error cases.
final class QuoteErrorTests: XCTestCase {

    // MARK: - errorDescription

    func testErrorDescription_FileNotFound_IsNonEmpty() {
        XCTAssertNotNil(QuoteError.fileNotFound.errorDescription)
        XCTAssertFalse(QuoteError.fileNotFound.errorDescription!.isEmpty)
    }

    func testErrorDescription_InvalidJSON_IsNonEmpty() {
        XCTAssertNotNil(QuoteError.invalidJSON.errorDescription)
        XCTAssertFalse(QuoteError.invalidJSON.errorDescription!.isEmpty)
    }

    func testErrorDescription_NoQuotesLoaded_IsNonEmpty() {
        XCTAssertNotNil(QuoteError.noQuotesLoaded.errorDescription)
        XCTAssertFalse(QuoteError.noQuotesLoaded.errorDescription!.isEmpty)
    }

    func testErrorDescription_QuoteNotFound_ContainsHumanReadableIndex() {
        // Given: index 4 (0-based) → should display as "5"
        let error = QuoteError.quoteNotFound(index: 4)

        // Then
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(
            error.errorDescription!.contains("5"),
            "Error description should display 1-based index (5), got: \(error.errorDescription!)"
        )
    }

    func testErrorDescription_QuoteNotFound_IndexZero_DisplaysOne() {
        let error = QuoteError.quoteNotFound(index: 0)
        XCTAssertTrue(
            error.errorDescription!.contains("1"),
            "Index 0 should display as '1' in description"
        )
    }

    func testErrorDescription_StorageUnavailable_IsNonEmpty() {
        XCTAssertNotNil(QuoteError.storageUnavailable.errorDescription)
        XCTAssertFalse(QuoteError.storageUnavailable.errorDescription!.isEmpty)
    }

    // MARK: - isRecoverable

    func testIsRecoverable_FileNotFound_ReturnsFalse() {
        XCTAssertFalse(QuoteError.fileNotFound.isRecoverable)
    }

    func testIsRecoverable_InvalidJSON_ReturnsFalse() {
        XCTAssertFalse(QuoteError.invalidJSON.isRecoverable)
    }

    func testIsRecoverable_NoQuotesLoaded_ReturnsFalse() {
        XCTAssertFalse(QuoteError.noQuotesLoaded.isRecoverable)
    }

    func testIsRecoverable_QuoteNotFound_ReturnsTrue() {
        XCTAssertTrue(QuoteError.quoteNotFound(index: 0).isRecoverable)
    }

    func testIsRecoverable_StorageUnavailable_ReturnsTrue() {
        XCTAssertTrue(QuoteError.storageUnavailable.isRecoverable)
    }

    // MARK: - failureReason

    func testFailureReason_FileNotFound_IsNonEmpty() {
        XCTAssertNotNil(QuoteError.fileNotFound.failureReason)
        XCTAssertFalse(QuoteError.fileNotFound.failureReason!.isEmpty)
    }

    func testFailureReason_InvalidJSON_IsNonEmpty() {
        XCTAssertNotNil(QuoteError.invalidJSON.failureReason)
        XCTAssertFalse(QuoteError.invalidJSON.failureReason!.isEmpty)
    }

    func testFailureReason_NoQuotesLoaded_IsNonEmpty() {
        XCTAssertNotNil(QuoteError.noQuotesLoaded.failureReason)
        XCTAssertFalse(QuoteError.noQuotesLoaded.failureReason!.isEmpty)
    }

    func testFailureReason_QuoteNotFound_ContainsIndex() {
        let error = QuoteError.quoteNotFound(index: 7)
        XCTAssertNotNil(error.failureReason)
        XCTAssertTrue(
            error.failureReason!.contains("7"),
            "Failure reason should contain the raw index"
        )
    }

    func testFailureReason_StorageUnavailable_IsNonEmpty() {
        XCTAssertNotNil(QuoteError.storageUnavailable.failureReason)
        XCTAssertFalse(QuoteError.storageUnavailable.failureReason!.isEmpty)
    }

    // MARK: - LocalizedError conformance

    func testAllCases_ConformToLocalizedError() {
        let errors: [QuoteError] = [
            .fileNotFound, .invalidJSON, .noQuotesLoaded,
            .quoteNotFound(index: 0), .storageUnavailable
        ]
        for error in errors {
            XCTAssertNotNil(error.errorDescription, "\(error) should have an errorDescription")
            XCTAssertNotNil(error.failureReason, "\(error) should have a failureReason")
        }
    }
}
