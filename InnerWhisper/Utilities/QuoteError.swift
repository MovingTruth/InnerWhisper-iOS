//
//  QuoteError.swift
//  InnerWhisper
//
//  Created for InnerWhisper.
//

import Foundation

/// Errors that can occur when loading or accessing quotes.
///
/// This enum provides user-friendly error messages through `LocalizedError`,
/// making it easy to display errors to users in the UI.
///
/// ## Usage Example
/// ```swift
/// do {
///     try loadQuotes()
/// } catch let error as QuoteError {
///     showError(error.errorDescription ?? "Unknown error")
/// }
/// ```
enum QuoteError: LocalizedError {
    /// The Quotes_Default.json (or bundle quote file) could not be found in the app bundle.
    case fileNotFound

    /// The JSON data is malformed or doesn't match the expected structure.
    case invalidJSON

    /// No quotes were loaded (empty collection).
    case noQuotesLoaded

    /// A quote at the requested index doesn't exist.
    case quoteNotFound(index: Int)

    /// The system storage directory (Application Support) is unavailable.
    case storageUnavailable

    /// User-friendly error description for display in UI.
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return String(localized: "Could not find quotes file. Please reinstall the app.")
        case .invalidJSON:
            return String(localized: "Quote data is corrupted. Please reinstall the app.")
        case .noQuotesLoaded:
            return String(localized: "No quotes are available at this time.")
        case .quoteNotFound(let index):
            return String(format: String(localized: "Quote #%lld is not available."), index + 1)
        case .storageUnavailable:
            return String(localized: "Device storage is temporarily unavailable. Please try again.")
        }
    }

    /// Whether retrying the operation could fix this error.
    ///
    /// Bundle-level errors (missing file, corrupt JSON, empty file) cannot be
    /// resolved by the user tapping "Retry" — they require an app update or
    /// reinstall. Only index-level errors are potentially transient.
    var isRecoverable: Bool {
        switch self {
        case .fileNotFound, .invalidJSON, .noQuotesLoaded:
            return false
        case .quoteNotFound, .storageUnavailable:
            return true
        }
    }

    /// Technical failure reason for debugging.
    var failureReason: String? {
        switch self {
        case .fileNotFound:
            return "Quotes_Default.json not found in Bundle.main"
        case .invalidJSON:
            return "JSONDecoder failed to decode QuoteCollection"
        case .noQuotesLoaded:
            return "Quotes array is empty after loading"
        case .quoteNotFound(let index):
            return "Index \(index) is out of bounds"
        case .storageUnavailable:
            return "FileManager could not locate Application Support directory"
        }
    }
}
