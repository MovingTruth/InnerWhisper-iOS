//
//  QuoteViewModel.swift
//  InnerWhisper
//
//  Created for InnerWhisper.
//

import Foundation
import SwiftUI

/// Protocol for accessing quote data, enabling dependency injection and testing.
///
/// Implement this protocol for production use (AggregatingQuoteProvider) and testing (MockQuoteProvider).
protocol QuoteProvider {
    func getQuote(at index: Int) -> Quote?
    /// Returns the quote with the given ID, or nil if not in the current list. Used for ID-based notification cycling.
    func getQuote(byId id: String) -> Quote?
    func getAllQuotes() -> [Quote]
    func quoteCount() -> Int
    func loadQuotes() async throws
    func refreshQuotesFromSources() async throws
}

extension QuoteProvider {
    /// Default implementation: look up by ID in the full list.
    func getQuote(byId id: String) -> Quote? {
        getAllQuotes().first { $0.id == id }
    }

    /// Default implementation: force-refresh falls back to a normal load.
    func refreshQuotesFromSources() async throws {
        try await loadQuotes()
    }
}

/// Make QuoteManager conform to QuoteProvider for direct use and testing.
extension QuoteManager: QuoteProvider {}

/// Direction of navigation for quote transitions.
enum NavigationDirection {
    case forward
    case backward
}

@MainActor
@Observable
final class QuoteViewModel {
    // MARK: - Observable Properties

    /// The current index of the displayed quote in the collection.
    var currentIndex: Int = 0 {
        didSet { UserDefaults.standard.set(currentIndex, forKey: Self.currentIndexKey) }
    }

    /// The loading state of quotes data.
    var loadingState: LoadingState<[Quote]> = .loading

    /// Error message to display to the user (if any).
    var errorMessage: String?

    /// The direction of the last navigation action.
    var navigationDirection: NavigationDirection = .forward

    /// Whether a force-refresh is currently in progress.
    var isRefreshing: Bool = false

    /// Status message shown after a force-refresh attempt (success or failure).
    var refreshStatusMessage: String?

    /// Whether notifications are currently enabled. Refreshed from UserDefaults
    /// on init and whenever `refreshNotificationState()` is called.
    var notificationsEnabled: Bool = NotificationSettings.load().isEnabled

    /// Incremented whenever the browse filter preference changes in UserDefaults.
    /// Because UserDefaults mutations are invisible to @Observable tracking, touching
    /// this property in browseDisplayedQuotes establishes it as a dependency — so any
    /// call to reloadBrowseMode() causes views that display quotes to re-render.
    private(set) var browseFilterVersion: Int = 0

    // MARK: - Private Properties

    private let quoteProvider: any QuoteProvider
    private static let currentIndexKey = "InnerWhisper.CurrentQuoteIndex"

    // MARK: - Computed Properties

    /// Quotes shown in the main browser (category filter + optional “my quotes only” browse filter).
    private var browseDisplayedQuotes: [Quote] {
        // Touch browseFilterVersion so @Observable tracks it as a dependency.
        // Without this, UserDefaults-driven filter changes would not trigger a re-render.
        _ = browseFilterVersion
        guard case .success(let all) = loadingState else { return [] }
        return Self.applyBrowseFilter(to: all)
    }

    /// The currently displayed quote based on the current index.
    var currentQuote: Quote? {
        let quotes = browseDisplayedQuotes
        guard currentIndex >= 0 && currentIndex < quotes.count else { return nil }
        return quotes[currentIndex]
    }

    /// The total number of quotes in the browse collection (may differ from `quoteProvider.quoteCount()` when “my quotes only” is on).
    var totalCount: Int {
        browseDisplayedQuotes.count
    }

    /// `true` when browse mode is “my quotes only” but the user has not added any quotes yet (full catalog may still be non-empty).
    var isBrowseUserQuotesOnlyEmpty: Bool {
        guard case .success(let all) = loadingState else { return false }
        guard UserDefaults.standard.bool(forKey: UserQuoteBrowseSettings.browseUserQuotesOnlyKey) else { return false }
        return !all.isEmpty && Self.applyBrowseFilter(to: all).isEmpty
    }

    /// Whether quotes are currently loading.
    var isLoading: Bool {
        loadingState.isLoading
    }

    /// Whether the current error is potentially fixable by tapping "Retry".
    ///
    /// Returns `false` for bundle-level errors (missing file, corrupt JSON)
    /// that cannot be resolved without reinstalling the app.
    var isErrorRecoverable: Bool {
        guard case .failure(let error) = loadingState else { return false }
        return (error as? QuoteError)?.isRecoverable ?? true
    }

    /// User-friendly position text (e.g., "3 / 15").
    var positionText: String {
        guard totalCount > 0 else { return String(localized: "0 / 0") }
        return String(localized: "\(currentIndex + 1) / \(totalCount)")
    }

    /// Accessibility label for the current position.
    var positionAccessibilityLabel: String {
        guard totalCount > 0 else { return String(localized: "No quotes available") }
        return String(localized: "Quote \(currentIndex + 1) of \(totalCount)")
    }

    /// Whether the Previous button should be enabled.
    var canGoToPrevious: Bool {
        totalCount > 1
    }

    /// Whether the Next button should be enabled.
    var canGoToNext: Bool {
        totalCount > 1
    }

    // MARK: - Initialization

    /// Creates a new QuoteViewModel with the specified quote provider.
    ///
    /// - Parameter quoteProvider: The provider to use for accessing quotes.
    ///   Defaults to AggregatingQuoteProvider.shared for production use.
    init(quoteProvider: any QuoteProvider = AggregatingQuoteProvider.shared) {
        self.quoteProvider = quoteProvider
        self.currentIndex = UserDefaults.standard.integer(forKey: Self.currentIndexKey)
    }

    /// Limits the main browser to user-added quotes when the user enables “My quotes only”.
    /// Matches `UserQuoteBrowseSettings.filterQuotesMatchingMainBrowser` (also used for notifications).
    static func applyBrowseFilter(to quotes: [Quote]) -> [Quote] {
        UserQuoteBrowseSettings.filterQuotesMatchingMainBrowser(quotes)
    }

    /// Re-clamps the current index after toggling “My quotes only” or changing UserDefaults.
    func reloadBrowseMode() {
        guard case .success(let all) = loadingState else { return }
        clampIndexForBrowseFilter(with: all)
        // Increment version so browseDisplayedQuotes (which reads UserDefaults via applyBrowseFilter)
        // is re-evaluated. @Observable cannot track UserDefaults changes directly.
        browseFilterVersion += 1
    }

    /// Re-derives the browse order after the shuffle preference changes, then refreshes the UI.
    ///
    /// Pass `forceReshuffle: true` when enabling shuffle so any previously saved grouped
    /// order is discarded and a fresh shuffle is produced.
    func reloadBrowseOrder(forceReshuffle: Bool = false) {
        if let aggregator = quoteProvider as? AggregatingQuoteProvider {
            aggregator.reloadUserQuotes(forceReshuffle: forceReshuffle)
        }
        reloadWithCurrentCategories()
    }

    private func clampIndexForBrowseFilter(with allQuotes: [Quote]) {
        let displayed = Self.applyBrowseFilter(to: allQuotes)
        if displayed.isEmpty {
            currentIndex = 0
        } else if currentIndex >= displayed.count {
            currentIndex = 0
        }
    }

    // MARK: - Public Methods

    /// Loads quotes from the provider asynchronously.
    ///
    /// Call this from a `.task` modifier on the owning view.
    /// Updates the loading state and handles any errors that occur.
    func loadQuotes() async {
        // Skip if already loaded — prevents a flash when switching themes,
        // since each themed view calls this from its own .task modifier.
        if case .success = loadingState { return }

        #if DEBUG
        print("[QuoteViewModel] loadQuotes() started")
        #endif
        loadingState = .loading
        errorMessage = nil

        do {
            try await quoteProvider.loadQuotes()
            let quotes = quoteProvider.getAllQuotes()

            if quotes.isEmpty {
                throw QuoteError.noQuotesLoaded
            }

            #if DEBUG
            print("[QuoteViewModel] loadQuotes() succeeded — \(quotes.count) quotes ready")
            #endif
            loadingState = .success(quotes)
            clampIndexForBrowseFilter(with: quotes)
            handlePendingNotificationOpen()
        } catch let error as QuoteError {
            #if DEBUG
            print("[QuoteViewModel] loadQuotes() failed — \(error.errorDescription ?? error.localizedDescription)")
            #endif
            loadingState = .failure(error)
            errorMessage = error.errorDescription
        } catch {
            #if DEBUG
            print("[QuoteViewModel] loadQuotes() unexpected error — \(error.localizedDescription)")
            #endif
            loadingState = .failure(error)
            errorMessage = "An unexpected error occurred"
        }
    }

    /// Force-refreshes quotes from all sources, ignoring the 24-hour throttle.
    ///
    /// Call this when the user taps "Update Quotes". Sets `isRefreshing` while
    /// in progress and sets `refreshStatusMessage` with the result.
    func refreshQuotes() async {
        #if DEBUG
        print("[QuoteViewModel] refreshQuotes() started (user-initiated force refresh)")
        #endif
        isRefreshing = true
        refreshStatusMessage = nil

        do {
            try await quoteProvider.refreshQuotesFromSources()
            let quotes = quoteProvider.getAllQuotes()
            if !quotes.isEmpty {
                #if DEBUG
                print("[QuoteViewModel] refreshQuotes() succeeded — \(quotes.count) quotes now loaded")
                #endif
                loadingState = .success(quotes)
                clampIndexForBrowseFilter(with: quotes)
            }
            refreshStatusMessage = nil
        } catch {
            #if DEBUG
            print("[QuoteViewModel] refreshQuotes() failed — \(error.localizedDescription)")
            #endif
            refreshStatusMessage = "Unable to update quotes. Please try again."
        }

        isRefreshing = false
    }

    /// Refreshes the notification enabled state from UserDefaults.
    ///
    /// Call this after the notification settings sheet is dismissed so that
    /// toolbar and settings icons update to reflect the current state.
    func refreshNotificationState() {
        notificationsEnabled = NotificationSettings.load().isEnabled
    }

    /// Re-applies the current category filter to the loaded quote list and updates the UI.
    ///
    /// Call this after the user changes which collections are enabled in `QuoteManagementView`.
    /// Does nothing if quotes have not been loaded yet.
    ///
    /// Updates run with implicit animations disabled so a sheet dismiss (or other system
    /// transition) does not animate the navigation bar / toolbar items when this reload runs.
    func reloadWithCurrentCategories() {
        guard case .success = loadingState else { return }
        let filtered = quoteProvider.getAllQuotes()
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            loadingState = .success(filtered)
            clampIndexForBrowseFilter(with: filtered)
        }
        #if DEBUG
        print("[QuoteViewModel] reloadWithCurrentCategories — \(filtered.count) quotes in catalog, \(Self.applyBrowseFilter(to: filtered).count) in browser")
        #endif
    }

    /// Retries loading quotes after a failure.
    /// Resets to the first quote so the user starts fresh after recovery.
    func retry() {
        currentIndex = 0
        loadingState = .idle  // reset so the guard in loadQuotes() doesn't skip
        Task { await loadQuotes() }
    }

    /// Navigates to a randomly selected quote, different from the current one if possible.
    func goToRandom() {
        guard totalCount > 1 else { return }

        HapticFeedback.light()

        var randomIndex: Int
        repeat {
            randomIndex = Int.random(in: 0..<totalCount)
        } while randomIndex == currentIndex

        navigationDirection = .forward

        Task { @MainActor [weak self] in
            guard let self else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                currentIndex = randomIndex
            }
        }
    }

    /// Advances to the next quote in the collection.
    ///
    /// Wraps around to the first quote when reaching the end of the collection.
    /// Provides haptic feedback for better user experience.
    func goToNext() {
        guard totalCount > 0 else { return }

        HapticFeedback.light()
        navigationDirection = .forward

        // The Task defers the index change to a second render cycle.
        // This gives SwiftUI one cycle to record `navigationDirection = .forward`
        // before the `.id(currentIndex)` change triggers the asymmetric transition.
        // Without the deferral, both state changes are batched into one update and
        // the transition cannot read the already-updated direction.
        // [weak self] prevents a retain cycle if the view is dismissed before the
        // Task executes (e.g. during rapid navigation or view teardown).
        Task { @MainActor [weak self] in
            guard let self else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                if currentIndex < totalCount - 1 {
                    currentIndex += 1
                } else {
                    currentIndex = 0
                }
            }
        }
    }

    /// Returns to the previous quote in the collection.
    ///
    /// Wraps around to the last quote when at the beginning of the collection.
    /// Provides haptic feedback for better user experience.
    func goToPrevious() {
        guard totalCount > 0 else { return }

        HapticFeedback.light()
        navigationDirection = .backward

        // See goToNext() for explanation of the Task deferral and [weak self] pattern.
        Task { @MainActor [weak self] in
            guard let self else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                if currentIndex > 0 {
                    currentIndex -= 1
                } else {
                    currentIndex = totalCount - 1
                }
            }
        }
    }

    /// Navigates to a specific quote by index.
    ///
    /// - Parameter index: The index of the quote to display.
    /// - Returns: True if navigation was successful, false if index is invalid.
    @discardableResult
    func goToQuote(at index: Int) -> Bool {
        guard index >= 0 && index < totalCount else {
            return false
        }

        navigationDirection = index > currentIndex ? .forward : .backward

        // See goToNext() for explanation of the Task deferral and [weak self] pattern.
        Task { @MainActor [weak self] in
            guard let self else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                currentIndex = index
            }
        }

        HapticFeedback.light()
        return true
    }

    /// Navigates to the quote with the given ID (e.g. from a notification tap).
    ///
    /// - Parameter quoteId: The unique identifier of the quote to display.
    /// - Returns: True if a quote with that ID was found and navigation was triggered.
    @discardableResult
    func goToQuote(id quoteId: String) -> Bool {
        guard case .success(let all) = loadingState else { return false }
        var displayed = Self.applyBrowseFilter(to: all)
        if let index = displayed.firstIndex(where: { $0.id == quoteId }) {
            return goToQuote(at: index)
        }
        // Quote exists in the full catalog but is hidden by “My quotes only” — turn browse filter off.
        if all.contains(where: { $0.id == quoteId }) {
            UserDefaults.standard.set(false, forKey: UserQuoteBrowseSettings.browseUserQuotesOnlyKey)
            NotificationCenter.default.post(name: .userQuoteBrowseModeDidChange, object: nil)
            displayed = Self.applyBrowseFilter(to: all)
            if let index = displayed.firstIndex(where: { $0.id == quoteId }) {
                return goToQuote(at: index)
            }
        }
        return false
    }

    /// If the app was opened by tapping a quote notification, navigates to that quote
    /// and clears the stored ID. Call when quotes are available (e.g. after load, or when app becomes active).
    /// Safe to call after load and on scene active; if quotes are not loaded yet, the call is a no-op
    /// until the next successful load or active transition.
    func handlePendingNotificationOpen() {
        let quoteId = UserDefaults.standard.string(forKey: pendingNotificationQuoteIdKey)
        guard let quoteId else { return }
        UserDefaults.standard.removeObject(forKey: pendingNotificationQuoteIdKey)
        _ = goToQuote(id: quoteId)
    }
}
