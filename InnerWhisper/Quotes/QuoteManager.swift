//
//  Quote.swift
//  InnerWhisper
//
//  Created by Robin O'Brien on 2026-03-04.
//

import Foundation

/// A model representing a single inspirational quote.
///
/// Each quote contains the text of the quote, attribution to its author,
/// and a unique identifier for indexing and navigation purposes.
struct Quote: Codable, Identifiable {
    /// A stable UUID string that permanently identifies this quote across all users and app versions.
    /// Used as the `Identifiable` identity and as the key for storing favorites.
    let id: String

    /// User-facing quote number (1-based). Shown to users as "Quote #N".
    /// Preserved from the source JSON and never reassigned by the aggregator.
    let displayNumber: Int

    /// The text content of the quote.
    let text: String

    /// The name of the person who said or wrote the quote.
    let author: String

    /// The category or theme of the quote. Defaults to "Default" if not specified.
    var category: String? = "Default"

    /// The source bundle file name (without extension) this quote was loaded from.
    /// Set at load time by BundleMultiQuoteSource; nil for quotes loaded from cache
    /// before this field was introduced, or from remote sources.
    var sourceFile: String? = nil
}

// MARK: - Shareable

extension Quote {
    /// Text formatted for sharing (e.g. Messages, Mail). Includes quote, author, and app attribution.
    var shareableText: String {
        "\(text)\n— \(author)\n\nFrom Moving Truth · Inner Whisper"
    }

    /// Normalized quote body for deduplication: trims, collapses whitespace, maps common Unicode quotes to ASCII,
    /// then case- and diacritic-insensitive folding so the same line is not shown twice from different files or author spellings.
    static func normalizedContentKey(forText text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let unicodeQuotePairs: [(String, String)] = [
            ("\u{2018}", "'"), ("\u{2019}", "'"), ("\u{201c}", "\""), ("\u{201d}", "\"")
        ]
        for (unicode, ascii) in unicodeQuotePairs {
            s = s.replacingOccurrences(of: unicode, with: ascii)
        }
        if let regex = try? NSRegularExpression(pattern: "\\s+", options: []) {
            let range = NSRange(s.startIndex..., in: s)
            s = regex.stringByReplacingMatches(in: s, options: [], range: range, withTemplate: " ")
        }
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }
}

/// A container structure for decoding a collection of quotes from JSON.
///
/// This structure matches the JSON format where quotes are stored
/// under a "quotes" key as an array.
struct QuoteCollection: Codable {
    /// An array of all quotes in the collection.
    let quotes: [Quote]
}

/// A singleton manager class responsible for loading and accessing the quote collection from the app bundle.
///
/// **Production use:** The app uses `AggregatingQuoteProvider.shared` as the single `QuoteProvider`
/// for `QuoteViewModel` and `NotificationManager`. `QuoteManager` is not used in production wiring;
/// it remains for bundle-only loading and for unit tests that exercise the bundle source in isolation.
///
/// `QuoteManager` loads quotes from a bundled JSON file and provides various methods to access them,
/// including retrieving quotes by index and accessing the full collection. It conforms to `QuoteProvider`
/// for testing and for use as the implementation behind `BundleQuoteSource` within the aggregator.
///
/// ## Usage
/// ```swift
/// let manager = QuoteManager.shared
/// if let quote = manager.getQuote(at: 0) {
///     print(quote.text)
/// }
/// ```
@MainActor
final class QuoteManager {
    /// The shared singleton instance of the quote manager.
    static let shared = QuoteManager()
    
    /// The internal storage of loaded quotes.
    private var quotes: [Quote] = []
    
    /// Private initializer to enforce singleton pattern.
    private init() {}

    /// Loads quotes from the bundled `Quotes_Default.json` file.
    ///
    /// This method attempts to locate and decode the quotes JSON file from the app bundle.
    /// Throws an error if loading fails, allowing proper error handling in the UI.
    ///
    /// - Throws: `QuoteError.fileNotFound` if the JSON file doesn't exist
    ///          `QuoteError.invalidJSON` if the JSON is malformed
    ///          `QuoteError.noQuotesLoaded` if the quotes array is empty
    func loadQuotes() async throws {
        guard let url = Bundle.main.url(forResource: "Quotes_Default", withExtension: "json")
            ?? Bundle.main.url(forResource: "Quotes_Default", withExtension: "json", subdirectory: "Quotes")
            ?? Bundle.main.url(forResource: "Quotes_Default", withExtension: "json", subdirectory: "Quotes/json_Quotes") else {
            #if DEBUG
            print("QuoteManager: Quotes_Default.json not found in bundle")
            #endif
            throw QuoteError.fileNotFound
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            #if DEBUG
            print("QuoteManager: Failed to read Quotes_Default.json - \(error)")
            #endif
            throw QuoteError.invalidJSON
        }

        let collection: QuoteCollection
        do {
            collection = try JSONDecoder().decode(QuoteCollection.self, from: data)
        } catch {
            #if DEBUG
            print("QuoteManager: Failed to decode Quotes_Default.json - \(error)")
            #endif
            throw QuoteError.invalidJSON
        }

        guard !collection.quotes.isEmpty else {
            #if DEBUG
            print("QuoteManager: Quotes_Default.json contains no quotes")
            #endif
            throw QuoteError.noQuotesLoaded
        }

        quotes = collection.quotes
        #if DEBUG
        print("QuoteManager: Successfully loaded \(quotes.count) quotes")
        #endif
    }
    
    /// Retrieves a quote at the specified index.
    ///
    /// - Parameter index: The zero-based index of the quote to retrieve.
    /// - Returns: The `Quote` at the given index, or `nil` if the index is out of bounds.
    func getQuote(at index: Int) -> Quote? {
        guard index >= 0 && index < quotes.count else {
            return nil
        }
        return quotes[index]
    }
    
    /// Returns all quotes in the collection.
    ///
    /// - Returns: An array containing all loaded quotes.
    func getAllQuotes() -> [Quote] {
        return quotes
    }
    
    /// Returns the total number of quotes in the collection.
    ///
    /// - Returns: The count of loaded quotes.
    func quoteCount() -> Int {
        return quotes.count
    }
}
