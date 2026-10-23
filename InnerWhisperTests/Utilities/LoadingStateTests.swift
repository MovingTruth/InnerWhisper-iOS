//
//  LoadingStateTests.swift
//  InnerWhisperTests
//
//  Created for InnerWhisper.
//

import XCTest
@testable import InnerWhisper

/// Unit tests for the LoadingState<T> enum.
///
/// Verifies that all computed properties correctly reflect each state
/// and that data/error extraction works as expected.
final class LoadingStateTests: XCTestCase {

    // MARK: - Idle State

    func testIdle_IsLoadingFalse() {
        let state: LoadingState<[Quote]> = .idle
        XCTAssertFalse(state.isLoading)
    }

    func testIdle_IsSuccessFalse() {
        let state: LoadingState<[Quote]> = .idle
        XCTAssertFalse(state.isSuccess)
    }

    func testIdle_IsFailureFalse() {
        let state: LoadingState<[Quote]> = .idle
        XCTAssertFalse(state.isFailure)
    }

    func testIdle_DataIsNil() {
        let state: LoadingState<[Quote]> = .idle
        XCTAssertNil(state.data)
    }

    func testIdle_ErrorIsNil() {
        let state: LoadingState<[Quote]> = .idle
        XCTAssertNil(state.error)
    }

    // MARK: - Loading State

    func testLoading_IsLoadingTrue() {
        let state: LoadingState<[Quote]> = .loading
        XCTAssertTrue(state.isLoading)
    }

    func testLoading_IsSuccessFalse() {
        let state: LoadingState<[Quote]> = .loading
        XCTAssertFalse(state.isSuccess)
    }

    func testLoading_IsFailureFalse() {
        let state: LoadingState<[Quote]> = .loading
        XCTAssertFalse(state.isFailure)
    }

    func testLoading_DataIsNil() {
        let state: LoadingState<[Quote]> = .loading
        XCTAssertNil(state.data)
    }

    func testLoading_ErrorIsNil() {
        let state: LoadingState<[Quote]> = .loading
        XCTAssertNil(state.error)
    }

    // MARK: - Success State

    func testSuccess_IsSuccessTrue() {
        let quotes = [Quote(id: "q1", displayNumber: 1, text: "Test", author: "Tester")]
        let state: LoadingState<[Quote]> = .success(quotes)
        XCTAssertTrue(state.isSuccess)
    }

    func testSuccess_IsLoadingFalse() {
        let state: LoadingState<[Quote]> = .success([])
        XCTAssertFalse(state.isLoading)
    }

    func testSuccess_IsFailureFalse() {
        let state: LoadingState<[Quote]> = .success([])
        XCTAssertFalse(state.isFailure)
    }

    func testSuccess_DataMatchesSuppliedValue() {
        // Given
        let quotes = [
            Quote(id: "q1", displayNumber: 1, text: "Quote 1", author: "Author 1"),
            Quote(id: "q2", displayNumber: 2, text: "Quote 2", author: "Author 2")
        ]

        // When
        let state: LoadingState<[Quote]> = .success(quotes)

        // Then
        XCTAssertEqual(state.data?.count, 2)
        XCTAssertEqual(state.data?.first?.id, "q1")
    }

    func testSuccess_ErrorIsNil() {
        let state: LoadingState<[Quote]> = .success([])
        XCTAssertNil(state.error)
    }

    // MARK: - Failure State

    func testFailure_IsFailureTrue() {
        let state: LoadingState<[Quote]> = .failure(QuoteError.fileNotFound)
        XCTAssertTrue(state.isFailure)
    }

    func testFailure_IsSuccessFalse() {
        let state: LoadingState<[Quote]> = .failure(QuoteError.fileNotFound)
        XCTAssertFalse(state.isSuccess)
    }

    func testFailure_IsLoadingFalse() {
        let state: LoadingState<[Quote]> = .failure(QuoteError.fileNotFound)
        XCTAssertFalse(state.isLoading)
    }

    func testFailure_DataIsNil() {
        let state: LoadingState<[Quote]> = .failure(QuoteError.fileNotFound)
        XCTAssertNil(state.data)
    }

    func testFailure_ErrorMatchesSuppliedError() {
        // Given
        let expectedError = QuoteError.invalidJSON

        // When
        let state: LoadingState<[Quote]> = .failure(expectedError)

        // Then
        XCTAssertNotNil(state.error)
        XCTAssertEqual(state.error?.localizedDescription, expectedError.localizedDescription)
    }

    // MARK: - Generic Type Flexibility

    func testSuccess_WithStringType_DataAvailable() {
        let state: LoadingState<String> = .success("hello")
        XCTAssertEqual(state.data, "hello")
        XCTAssertTrue(state.isSuccess)
    }
}
