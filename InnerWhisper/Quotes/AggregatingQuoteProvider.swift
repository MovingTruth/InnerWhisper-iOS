//
//  AggregatingQuoteProvider.swift
//  InnerWhisper
//
//  Created for InnerWhisper.
//

import Foundation

/// Aggregates quotes from multiple sources into a single persistent local collection.
///
/// Implements the offline-first strategy described in the multi-source architecture:
/// - On `loadQuotes()`: serves from the cached local file immediately if available,
///   then triggers a background refresh if the data is older than 24 hours.
/// - On first launch (no cached file): fetches from all sources synchronously,
///   saves the result, then shows the merged list.
/// - `refreshQuotesFromSources()`: force-fetches from all sources, ignoring the 24h throttle.
///
/// User-added quotes (`Quotes_UserAdded`) are **not** stored in the aggregated JSON file; they are
/// merged in memory and loaded from `UserAddedQuotesStore`. Browse order is persisted (ordered quote ids
/// in `UserDefaults`): shuffled once when there is no saved order, and reshuffled when the merged set
/// gains new quote ids; otherwise the previous order is kept (with ids removed when quotes disappear).
/// Notification scheduling uses its own shuffled cycle in `NotificationManager`, independent of browse order.
///
/// To add a new backend source (Supabase, Firebase, etc.) later, just append a new
/// `QuoteSource` conformer to the `sources` array used at initialisation.
@MainActor
final class AggregatingQuoteProvider: QuoteProvider {

    /// Optional HTTPS URL for remote "Extra" category quotes. Used by the aggregator refresh and `QuoteManagementView`.
    /// Replace with your hosted JSON location; the app continues if fetch fails.
    /// Example: `URL(string: "https://yourdomain.github.io/innerwhisper/Quotes_Remote.json")`
    // The portfolio edition is self-contained. Supply an HTTPS endpoint here to
    // demonstrate the optional remote-source path with your own content service.
    static let remoteExtraQuotesJSONURL: URL? = nil

    /// Shared instance: all quotes loaded from bundle on first launch (Quotes_Default, Quotes_Forest, and all category files).
    static let shared: AggregatingQuoteProvider = {
        var sources: [any QuoteSource] = [BundleMultiQuoteSource()]
        if let url = remoteExtraQuotesJSONURL {
            sources.append(RemoteQuoteSource(url: url, defaultCategory: "Extra"))
        }
        return AggregatingQuoteProvider(sources: sources)
    }()

    private let sources: [any QuoteSource]
    /// Bundle + remote + remote cache only (never user-added rows).
    private var bundledQuotes: [Quote] = []
    /// Bundled + user quotes merged for browsing/notifications (unfiltered by category toggles).
    private var allQuotes: [Quote] = []

    private static let lastRefreshKey = "InnerWhisper.LastQuoteRefreshDate"
    private static let aggregatedFileName = "aggregated_quotes.json"
    /// Persisted browse sequence (bundled + user). Notification cycle order is separate (`NotificationManager`).
    private static let browseQuoteOrderIdsKey = "InnerWhisper.BrowseQuoteOrderIds"

    init(sources: [any QuoteSource]) {
        self.sources = sources
    }

    // MARK: - QuoteProvider

    /// Loads quotes offline-first.
    ///
    /// If a cached aggregated file exists, loads from it immediately (offline-capable).
    /// Then starts a background refresh if the cache is older than 24 hours.
    /// If no cached file exists (first launch), fetches from sources and saves.
    func loadQuotes() async throws {
        await UserAddedQuotesStore.shared.loadFromDisk()
        #if DEBUG
        print("[Aggregator] loadQuotes() called — checking for cached file...")
        #endif
        if let cached = try? await loadFromFile(), !cached.isEmpty {
            let withoutUser = cached.filter { $0.sourceFile != UserAddedQuotesStore.sourceFileName }
            let dedupedCache = Self.deduplicateQuotes(withoutUser)
            bundledQuotes = dedupedCache
            if dedupedCache.count < withoutUser.count {
                Task { try? await Self.persistQuotesToDisk(dedupedCache) }
            }
            #if DEBUG
            print("[Aggregator] Cache hit: loaded \(bundledQuotes.count) bundled quotes from local file")
            #endif
            applyMergedBrowseOrder()
            refreshInBackgroundIfStale()
        } else {
            #if DEBUG
            print("[Aggregator] No cache found — fetching from sources (first launch or cache cleared)")
            #endif
            try await fetchFromSourcesAndSave()
        }
    }

    /// Force-fetches from all sources and saves, ignoring the 24-hour throttle.
    ///
    /// Call this when the user taps "Update Quotes". Throws if all sources fail.
    func refreshQuotesFromSources() async throws {
        await UserAddedQuotesStore.shared.loadFromDisk()
        #if DEBUG
        print("[Aggregator] Force refresh requested — ignoring 24h throttle")
        #endif
        try await fetchFromSourcesAndSave()
    }

    /// Rebuilds the in-memory list after user quotes change on disk (add/edit/delete).
    ///
    /// Pass `forceReshuffle: true` when the user enables shuffle mode so the previously
    /// saved (grouped) order is discarded and a fresh shuffle is produced.
    func reloadUserQuotes(forceReshuffle: Bool = false) {
        if forceReshuffle {
            UserDefaults.standard.removeObject(forKey: Self.browseQuoteOrderIdsKey)
        }
        applyMergedBrowseOrder()
    }

    /// Returns the active (category-filtered) quote list.
    private var activeQuotes: [Quote] {
        QuoteCategoryManager.shared.filtered(allQuotes)
    }

    func getQuote(at index: Int) -> Quote? {
        let active = activeQuotes
        guard index >= 0 && index < active.count else { return nil }
        return active[index]
    }

    func getAllQuotes() -> [Quote] { activeQuotes }

    func quoteCount() -> Int { activeQuotes.count }

    // MARK: - Merge

    /// Merges bundled and user quotes, dedupes, and sorts by `id` so browse order is stable across app launches.
    static func mergedStable(bundled: [Quote], user: [Quote]) -> [Quote] {
        deduplicateQuotes(bundled + user).sorted { $0.id < $1.id }
    }

    /// Merges bundled quotes with user-added quotes, dedupes, and shuffles (tests / ad-hoc use).
    static func mergedAndShuffled(bundled: [Quote], user: [Quote]) -> [Quote] {
        deduplicateQuotes(bundled + user).shuffled()
    }

    private func applyMergedBrowseOrder() {
        let merged = Self.deduplicateQuotes(bundledQuotes + UserAddedQuotesStore.shared.quotes)
        guard !merged.isEmpty else {
            allQuotes = []
            UserDefaults.standard.removeObject(forKey: Self.browseQuoteOrderIdsKey)
            return
        }

        let shuffleEnabled = UserDefaults.standard.bool(forKey: UserQuoteBrowseSettings.shuffleDisplayedQuotesKey)

        if !shuffleEnabled {
            // Grouped order: sort by collection (category → sourceFile fallback) then display number.
            // This preserves the original themed groupings and is stable across launches.
            let grouped = merged.sorted { a, b in
                let aGroup = a.category ?? a.sourceFile ?? "~"
                let bGroup = b.category ?? b.sourceFile ?? "~"
                if aGroup != bGroup { return aGroup < bGroup }
                return a.displayNumber < b.displayNumber
            }
            allQuotes = grouped
            UserDefaults.standard.set(grouped.map(\.id), forKey: Self.browseQuoteOrderIdsKey)
            return
        }

        // Shuffle mode: shuffle once on first launch or when new quotes arrive;
        // otherwise restore the previously persisted shuffled order.
        let byId = Dictionary(uniqueKeysWithValues: merged.map { ($0.id, $0) })
        let mergedIds = Set(merged.map(\.id))
        let savedIds = UserDefaults.standard.stringArray(forKey: Self.browseQuoteOrderIdsKey) ?? []
        let savedIdSet = Set(savedIds)

        let shouldShuffle: Bool
        if savedIds.isEmpty {
            shouldShuffle = true
        } else {
            shouldShuffle = !mergedIds.subtracting(savedIdSet).isEmpty
        }

        if shouldShuffle {
            let shuffled = merged.shuffled()
            allQuotes = shuffled
            UserDefaults.standard.set(shuffled.map(\.id), forKey: Self.browseQuoteOrderIdsKey)
        } else {
            var ordered: [Quote] = []
            for id in savedIds {
                if let q = byId[id] { ordered.append(q) }
            }
            let remainingIds = mergedIds.subtracting(ordered.map(\.id))
            let remainingSorted = merged.filter { remainingIds.contains($0.id) }.sorted { $0.id < $1.id }
            ordered.append(contentsOf: remainingSorted)
            allQuotes = ordered
            UserDefaults.standard.set(ordered.map(\.id), forKey: Self.browseQuoteOrderIdsKey)
        }
    }

    // MARK: - Private

    private func refreshInBackgroundIfStale() {
        let lastRefresh = UserDefaults.standard.object(forKey: Self.lastRefreshKey) as? Date
        let isStale = lastRefresh.map { Date().timeIntervalSince($0) > 86_400 } ?? true

        if let lastRefresh {
            let hours = Int(Date().timeIntervalSince(lastRefresh) / 3600)
            #if DEBUG
            print("[Aggregator] Last refresh: \(hours)h ago — \(isStale ? "stale, triggering background refresh" : "fresh, skipping refresh")")
            #endif
        } else {
            #if DEBUG
            print("[Aggregator] No previous refresh timestamp — triggering background refresh")
            #endif
        }

        guard isStale else { return }

        Task { [weak self] in
            #if DEBUG
            print("[Aggregator] Background refresh starting...")
            #endif
            try? await self?.fetchFromSourcesAndSave()
            #if DEBUG
            print("[Aggregator] Background refresh complete")
            #endif
        }
    }

    /// Fetches from all sources, merges, saves bundled quotes to the local file (excludes user-added).
    ///
    /// Partial success is tolerated: if at least one source succeeds, the merged
    /// list is saved. Throws `QuoteError.noQuotesLoaded` only if every source fails.
    private func fetchFromSourcesAndSave() async throws {
        await UserAddedQuotesStore.shared.loadFromDisk()
        #if DEBUG
        print("[Aggregator] Fetching from \(sources.count) source(s)...")
        #endif
        var merged: [Quote] = []
        var sourceIndex = 0

        for source in sources {
            sourceIndex += 1
            let sourceName = String(describing: type(of: source))
            #if DEBUG
            print("[Aggregator] [\(sourceIndex)/\(sources.count)] Querying \(sourceName)...")
            #endif
            do {
                let fetched = try await source.fetchQuotes()
                #if DEBUG
                print("[Aggregator] [\(sourceIndex)/\(sources.count)] \(sourceName) returned \(fetched.count) quotes")
                #endif
                merged.append(contentsOf: fetched)
            } catch {
                #if DEBUG
                print("[Aggregator] [\(sourceIndex)/\(sources.count)] \(sourceName) FAILED — \(error.localizedDescription)")
                #endif
                // For remote sources, fall back to previously cached quotes so a transient
                // network failure doesn't permanently drop remote quotes until the next manual refresh.
                if let remote = source as? RemoteQuoteSource {
                    let sourceTag = "Remote_\(remote.defaultCategory)"
                    let preserved = bundledQuotes.filter { $0.sourceFile == sourceTag }
                    if !preserved.isEmpty {
                        merged.append(contentsOf: preserved)
                        #if DEBUG
                        print("[Aggregator] [\(sourceIndex)/\(sources.count)] Preserved \(preserved.count) cached quotes for \(sourceTag)")
                        #endif
                    }
                }
            }
        }

        guard !merged.isEmpty else {
            #if DEBUG
            print("[Aggregator] ERROR: All sources failed — no quotes to save")
            #endif
            throw QuoteError.noQuotesLoaded
        }

        let deduped = Self.deduplicateQuotes(merged)
        #if DEBUG
        print("[Aggregator] Merged \(merged.count) quotes, \(deduped.count) after dedupe (stable order)")
        #endif

        bundledQuotes = deduped
        try await Self.persistQuotesToDisk(deduped)
        applyMergedBrowseOrder()
        UserDefaults.standard.set(Date(), forKey: Self.lastRefreshKey)
        #if DEBUG
        if let fileURL = try? Self.aggregatedFileURL() {
            print("[Aggregator] Saved \(deduped.count) bundled quotes to: \(fileURL.path)")
        }
        #endif
    }

    /// Called when a full notification cycle completes. Browse order is unchanged here; `NotificationManager`
    /// already builds a new shuffled id cycle in `UserDefaults`.
    func reshuffleQuotesForNextCycle() {
        #if DEBUG
        print("[Aggregator] reshuffleQuotesForNextCycle: no-op (browse order is browseQuoteOrderIdsKey; notifications use NotificationManager cycle)")
        #endif
    }

    private func loadFromFile() async throws -> [Quote] {
        let url = try Self.aggregatedFileURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            #if DEBUG
            print("[Aggregator] No cached file at: \(url.path)")
            #endif
            return []
        }
        // Read and decode off the main thread to avoid blocking UI.
        return try await Task.detached(priority: .utility) {
            let data = try Data(contentsOf: url)
            #if DEBUG
            print("[Aggregator] Read cached file (\(data.count) bytes) from: \(url.path)")
            #endif
            return try JSONDecoder().decode(QuoteCollection.self, from: data).quotes
        }.value
    }

    /// Drops duplicate IDs and duplicate quote bodies (normalized text), keeping first occurrence.
    private static func deduplicateQuotes(_ quotes: [Quote]) -> [Quote] {
        var seenIds = Set<String>()
        let byId = quotes.filter { seenIds.insert($0.id).inserted }
        var seenContent = Set<String>()
        return byId.filter { q in
            let key = Quote.normalizedContentKey(forText: q.text)
            return seenContent.insert(key).inserted
        }
    }

    /// Writes the deduplicated bundled list to the aggregated cache (sorted by id for a deterministic on-disk cache).
    private static func persistQuotesToDisk(_ quotes: [Quote]) async throws {
        let fileURL = try aggregatedFileURL()
        let ordered = quotes.sorted { $0.id < $1.id }
        try await Task.detached(priority: .utility) {
            let data = try JSONEncoder().encode(QuoteCollection(quotes: ordered))
            try data.write(to: fileURL, options: .atomic)
        }.value
    }

    private static func aggregatedFileURL() throws -> URL {
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw QuoteError.storageUnavailable
        }
        let appDir = appSupport.appendingPathComponent("InnerWhisper", isDirectory: true)
        try FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent(aggregatedFileName)
    }
}
