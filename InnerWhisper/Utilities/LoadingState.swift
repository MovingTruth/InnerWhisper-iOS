//
//  LoadingState.swift
//  InnerWhisper
//
//  Created for InnerWhisper.
//

import Foundation

/// A generic type representing the loading state of an asynchronous operation.
///
/// Use this enum to track and represent different states of data loading:
/// - `idle`: Initial state before any loading begins
/// - `loading`: Currently fetching or processing data
/// - `success`: Operation completed successfully with data
/// - `failure`: Operation failed with an error
///
/// ## Usage Example
/// ```swift
/// var quotesState: LoadingState<[Quote]> = .idle
///
/// func loadQuotes() async {
///     quotesState = .loading
///     do {
///         let quotes = try await fetchQuotes()
///         quotesState = .success(quotes)
///     } catch {
///         quotesState = .failure(error)
///     }
/// }
/// ```
/// `@unchecked Sendable` is used instead of conditional `Sendable` because `Error`
/// does not itself conform to `Sendable`, making `case failure(any Error & Sendable)`
/// too restrictive — concrete error types such as `QuoteError` may not declare
/// `Sendable`. In practice all mutations happen on `@MainActor`, so the relaxed
/// annotation is safe: the enum is never shared across isolation boundaries
/// without passing through an actor hop that serialises access.
enum LoadingState<T>: @unchecked Sendable {
    case idle
    case loading
    case success(T)
    case failure(Error)

    /// Returns the successful data if available, otherwise nil.
    var data: T? {
        if case .success(let value) = self {
            return value
        }
        return nil
    }

    /// Returns the error if the state is failure, otherwise nil.
    var error: Error? {
        if case .failure(let error) = self {
            return error
        }
        return nil
    }

    /// Returns true if the state is currently loading.
    var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }

    /// Returns true if the operation was successful.
    var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }

    /// Returns true if the operation failed.
    var isFailure: Bool {
        if case .failure = self {
            return true
        }
        return false
    }
}
