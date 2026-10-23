//
//  QuoteSource.swift
//  InnerWhisper
//
//  Created for InnerWhisper.
//

import Foundation

/// A single source that knows how to fetch quotes asynchronously.
///
/// Each source is responsible only for fetching raw quotes. The aggregator
/// handles merging, ID assignment, and persistence.
protocol QuoteSource {
    func fetchQuotes() async throws -> [Quote]
}

// MARK: - Bundle quote file names (without extension) loaded on first launch.
// Add new category files here so they are included in the aggregated bundle source.
// Categories are loaded in order; add new entries at the end to preserve load priority.
private let bundleQuoteFileNames: [String] = [
    "Quotes_Default",
    "Quotes_Forest",
    "Quotes_Space",
]

/// Shared bundle lookup and locale-suffix resolution used by every source that reads
/// quote JSON files out of the app bundle, so `BundleQuoteSource` and
/// `BundleMultiQuoteSource` stay in sync on which file backs a given language.
enum BundleQuoteFileResolver {
    /// Returns the bundle URL for `resourceName`.json, checking all known subdirectory paths.
    static func bundleURL(forResource resourceName: String) -> URL? {
        Bundle.main.url(forResource: resourceName, withExtension: "json")
            ?? Bundle.main.url(forResource: resourceName, withExtension: "json", subdirectory: "Quotes")
            ?? Bundle.main.url(forResource: resourceName, withExtension: "json", subdirectory: "Quotes/json_Quotes")
    }

    /// Resolves the best available file name for a base quote file given the current language preference.
    ///
    /// - Returns: The locale-suffixed name if its bundle file exists, otherwise the original base name.
    static func resolvedFileName(for baseName: String, languageCode: String) -> String {
        guard languageCode != "en" else { return baseName }
        let candidate = "\(baseName)_\(languageCode)"
        return bundleURL(forResource: candidate) != nil ? candidate : baseName
    }
}

/// Fetches quotes from a single named JSON file in the app bundle.
///
/// `resourceName` is treated as the base (English) file name; the current `AppLanguage`
/// preference is resolved to a locale-suffixed file (e.g. "Quotes_Default_de") when one
/// exists in the bundle, falling back to the base file silently otherwise. This mirrors
/// `BundleMultiQuoteSource` so a single collection loaded on its own (e.g. by the quote
/// management screen) shows the same language as the aggregated quote list.
struct BundleQuoteSource: QuoteSource {
    /// Base resource name without extension (e.g. "Quotes_Default").
    private let resourceName: String

    init(resourceName: String = "Quotes_Default") {
        self.resourceName = resourceName
    }

    func fetchQuotes() async throws -> [Quote] {
        let languageCode = AppLanguage.current.resolvedLanguageCode
        let resolvedName = BundleQuoteFileResolver.resolvedFileName(for: resourceName, languageCode: languageCode)
        #if DEBUG
        print("[QuoteSource/Bundle] Fetching \(resolvedName).json from bundle...")
        #endif
        let quotes = try await Task.detached(priority: .utility) {
            guard let url = BundleQuoteFileResolver.bundleURL(forResource: resolvedName) else {
                #if DEBUG
                print("[QuoteSource/Bundle] ERROR: \(resolvedName).json not found in bundle")
                #endif
                throw QuoteError.fileNotFound
            }
            let data = try Data(contentsOf: url)
            let collection = try JSONDecoder().decode(QuoteCollection.self, from: data)
            guard !collection.quotes.isEmpty else {
                #if DEBUG
                print("[QuoteSource/Bundle] ERROR: \(resolvedName).json decoded but contains no quotes")
                #endif
                throw QuoteError.noQuotesLoaded
            }
            return collection.quotes
        }.value
        #if DEBUG
        print("[QuoteSource/Bundle] Fetched \(quotes.count) quotes from \(resolvedName).json")
        #endif
        return quotes
    }
}

/// Fetches quotes from all bundled quote JSON files (Quotes_Default, Quotes_Forest, etc.).
/// Used on first launch to load the full set without requiring network.
///
/// When a locale-specific file exists for the current `AppLanguage` preference
/// (e.g. `Quotes_Default_es.json`), it is loaded instead of the English base file.
/// If no locale file is found, the English base file is used silently as a fallback.
struct BundleMultiQuoteSource: QuoteSource {

    /// Returns the bundle URL for `resourceName`.json, checking all known subdirectory paths.
    private func bundleURL(forResource resourceName: String) -> URL? {
        Bundle.main.url(forResource: resourceName, withExtension: "json")
            ?? Bundle.main.url(forResource: resourceName, withExtension: "json", subdirectory: "Quotes")
            ?? Bundle.main.url(forResource: resourceName, withExtension: "json", subdirectory: "Quotes/json_Quotes")
    }

    /// Resolves the best available file name for a base quote file given the current language preference.
    ///
    /// - Returns: The locale-suffixed name if its bundle file exists, otherwise the original base name.
    private func resolvedFileName(for baseName: String, languageCode: String) -> String {
        guard languageCode != "en" else { return baseName }
        let candidate = "\(baseName)_\(languageCode)"
        return bundleURL(forResource: candidate) != nil ? candidate : baseName
    }

    func fetchQuotes() async throws -> [Quote] {
        let languageCode = AppLanguage.current.resolvedLanguageCode
        #if DEBUG
        print("[QuoteSource/BundleMulti] Fetching from \(bundleQuoteFileNames.count) bundle file(s) (language: \(languageCode))...")
        #endif
        let allQuotes = try await Task.detached(priority: .utility) {
            var quotes: [Quote] = []
            for baseName in bundleQuoteFileNames {
                let name = self.resolvedFileName(for: baseName, languageCode: languageCode)
                guard let url = self.bundleURL(forResource: name) else {
                    #if DEBUG
                    print("[QuoteSource/BundleMulti] Skipping \(name).json (not in bundle)")
                    #endif
                    continue
                }
                do {
                    let data = try Data(contentsOf: url)
                    let collection = try JSONDecoder().decode(QuoteCollection.self, from: data)
                    // Tag each quote with the base (English) source file name so the management
                    // UI can group them consistently regardless of which locale file was loaded.
                    let tagged = collection.quotes.map { q -> Quote in
                        var copy = q
                        copy.sourceFile = baseName
                        return copy
                    }
                    quotes.append(contentsOf: tagged)
                    #if DEBUG
                    print("[QuoteSource/BundleMulti] Loaded \(collection.quotes.count) from \(name).json")
                    #endif
                } catch {
                    #if DEBUG
                    print("[QuoteSource/BundleMulti] Failed to load \(name).json: \(error.localizedDescription)")
                    #endif
                }
            }
            return quotes
        }.value
        guard !allQuotes.isEmpty else {
            #if DEBUG
            print("[QuoteSource/BundleMulti] ERROR: No quotes loaded from any bundle file")
            #endif
            throw QuoteError.noQuotesLoaded
        }
        #if DEBUG
        print("[QuoteSource/BundleMulti] Total: \(allQuotes.count) quotes")
        #endif
        return allQuotes
    }
}

/// Fetches quotes from a remote JSON file.
struct RemoteQuoteSource: QuoteSource {
    /// Maximum allowed response size (5 MB) to avoid memory exhaustion from a malicious or misbehaving server.
    private static let maxResponseBytes = 5 * 1024 * 1024

    let url: URL
    /// The default category to assign to quotes if they don't specify one.
    let defaultCategory: String
    /// Network timeout in seconds. Default is 10 s; callers can pass a shorter value
    /// (e.g. 5 s) when a slow response should not block UI.
    let timeoutInterval: TimeInterval

    init(url: URL, defaultCategory: String = "Default", timeoutInterval: TimeInterval = 10) {
        self.url = url
        self.defaultCategory = defaultCategory
        self.timeoutInterval = timeoutInterval
    }

    func fetchQuotes() async throws -> [Quote] {
        guard url.scheme?.lowercased() == "https" else {
            #if DEBUG
            print("[QuoteSource/Remote] ERROR: Non-HTTPS URL rejected: \(url.absoluteString)")
            #endif
            throw URLError(.badURL)
        }
        #if DEBUG
        print("[QuoteSource/Remote] Fetching quotes from \(url.absoluteString)...")
        #endif

        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .useProtocolCachePolicy
        let session = URLSession(configuration: config)
        defer { session.finishTasksAndInvalidate() }

        var request = URLRequest(url: url)
        request.cachePolicy = .useProtocolCachePolicy
        request.timeoutInterval = timeoutInterval

        let (data, response) = try await session.data(for: request)

        guard data.count <= Self.maxResponseBytes else {
            #if DEBUG
            print("[QuoteSource/Remote] ERROR: Response too large (\(data.count) bytes) from \(url.absoluteString)")
            #endif
            throw URLError(.downloadDecodingFailedToComplete)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        // If not modified, URLSession might throw or just return empty data depending on cache.
        // We'll treat a successful status code as valid.
        guard (200...299).contains(httpResponse.statusCode) else {
            #if DEBUG
            print("[QuoteSource/Remote] ERROR: Bad status code \(httpResponse.statusCode) from \(url.absoluteString)")
            #endif
            // If the file is a 404 (not found), we can silently fail by returning an empty array
            // This allows pre-staging URLs for files that don't exist yet on GitHub Pages
            if httpResponse.statusCode == 404 {
                #if DEBUG
                print("[QuoteSource/Remote] File not found (404), returning empty array for \(url.absoluteString)")
                #endif
                return []
            }
            throw URLError(.badServerResponse)
        }

        #if DEBUG
        print("[QuoteSource/Remote] Read \(data.count) bytes from \(url.absoluteString)")
        #endif

        // Run decode off the main thread
        let quotes = try await Task.detached(priority: .utility) {
            let collection = try JSONDecoder().decode(QuoteCollection.self, from: data)
            let sourceTag = "Remote_\(self.defaultCategory)"
            return collection.quotes.map { quote in
                var updatedQuote = quote
                if updatedQuote.category == nil {
                    updatedQuote.category = self.defaultCategory
                }
                // Tag with a stable sourceFile so the aggregator can identify and
                // preserve these quotes if the remote fetch fails on a future refresh.
                updatedQuote.sourceFile = sourceTag
                return updatedQuote
            }
        }.value

        guard !quotes.isEmpty else {
            #if DEBUG
            print("[QuoteSource/Remote] ERROR: Remote JSON decoded but contains no quotes")
            #endif
            throw QuoteError.noQuotesLoaded
        }

        #if DEBUG
        print("[QuoteSource/Remote] Successfully fetched \(quotes.count) quotes from \(url.absoluteString)")
        #endif
        
        return quotes
    }
}
