//
//  QuoteCategoryManager.swift
//  InnerWhisper
//
//  Created for InnerWhisper.
//
import Foundation

/// Represents a single bundled quote collection (one JSON file).
struct QuoteCollection_Info: Identifiable {
    /// The bundle file name without extension (e.g. "Quotes_Stoicism").
    let fileName: String
    /// User-facing display name (e.g. "Stoicism").
    let displayName: String
    /// SF Symbol name for the collection.
    let symbol: String

    var id: String { fileName }
}

/// Manages which quote collections (bundle files) are enabled or disabled.
///
/// Enabled collections are included in the in-app quote browser and in
/// notification cycling (after any “My quotes only” browse filter). Disabled
/// collections are hidden from both.
///
/// Changes take effect after the next call to `QuoteViewModel.reloadWithCurrentCategories()`.
@MainActor
@Observable
final class QuoteCategoryManager {

    // MARK: - Shared instance

    static let shared = QuoteCategoryManager()

    // MARK: - All known collections (mirrors bundleQuoteFileNames in QuoteSource.swift)

    static let allCollections: [QuoteCollection_Info] = [
        QuoteCollection_Info(fileName: "Quotes_Default",          displayName: String(localized: "General"),           symbol: "sparkles"),
        QuoteCollection_Info(fileName: "Quotes_Motivational",     displayName: String(localized: "Motivational"),      symbol: "bolt.heart"),
        QuoteCollection_Info(fileName: "Quotes_Stoicism",         displayName: String(localized: "Stoicism"),          symbol: "scale.3d"),
        QuoteCollection_Info(fileName: "Quotes_Nature",           displayName: String(localized: "Nature"),            symbol: "leaf"),
        QuoteCollection_Info(fileName: "Quotes_Forest",           displayName: String(localized: "Forest"),            symbol: "tree"),
        QuoteCollection_Info(fileName: "Quotes_Space",            displayName: String(localized: "Space"),             symbol: "moon.stars"),
        QuoteCollection_Info(fileName: "Quotes_JapaneseProverbs", displayName: String(localized: "Japanese Proverbs"), symbol: "character.ja"),
        QuoteCollection_Info(fileName: "Quotes_AlanWatts",        displayName: String(localized: "Alan Watts"),        symbol: "person.wave.2"),
        QuoteCollection_Info(fileName: "Quotes_Gandhi",           displayName: String(localized: "Gandhi"),            symbol: "globe.americas"),
        QuoteCollection_Info(fileName: "Quotes_WorldLeaders",     displayName: String(localized: "World Leaders"),     symbol: "building.columns"),
        QuoteCollection_Info(fileName: "Quotes_Actors",           displayName: String(localized: "Actors"),            symbol: "theatermasks"),
        QuoteCollection_Info(fileName: "Quotes_UserAdded",        displayName: String(localized: "User Added"),        symbol: "person.crop.circle.badge.plus"),
    ]

    // MARK: - Persistence key

    private static let disabledSourcesKey = "InnerWhisper.DisabledQuoteSources"

    // MARK: - Observable State

    /// Set of file names (e.g. "Quotes_Stoicism") that are currently disabled.
    private(set) var disabledSources: Set<String> = []

    // MARK: - Init

    private init() {
        load()
    }

    // MARK: - Public API

    /// Whether the collection identified by `fileName` is currently enabled.
    func isEnabled(_ fileName: String) -> Bool {
        !disabledSources.contains(fileName)
    }

    /// Toggles the enabled state for the collection identified by `fileName`.
    func toggle(_ fileName: String) {
        if disabledSources.contains(fileName) {
            disabledSources.remove(fileName)
        } else {
            disabledSources.insert(fileName)
        }
        save()
    }

    /// Returns `true` if more than one collection is enabled (used to prevent disabling the last active collection).
    var hasMoreThanOneEnabled: Bool {
        Self.allCollections.filter { isEnabled($0.fileName) }.count > 1
    }

    // MARK: - Filtering

    /// Filters a flat array of quotes, returning only those whose `sourceFile` is in an enabled collection.
    /// Quotes with no `sourceFile` (e.g. loaded from old cache before tagging was introduced) are always included.
    func filtered(_ quotes: [Quote]) -> [Quote] {
        guard !disabledSources.isEmpty else { return quotes }
        return quotes.filter { quote in
            guard let sourceFile = quote.sourceFile else { return true }
            return isEnabled(sourceFile)
        }
    }

    // MARK: - Persistence

    private func save() {
        UserDefaults.standard.set(Array(disabledSources), forKey: Self.disabledSourcesKey)
    }

    private func load() {
        let stored = UserDefaults.standard.stringArray(forKey: Self.disabledSourcesKey) ?? []
        disabledSources = Set(stored)
    }
}
