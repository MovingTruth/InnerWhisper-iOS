//
//  UserQuoteBrowseSettings.swift
//  InnerWhisper
//
//  UserDefaults key for “browse only quotes I added” on the main quote screen.
//

import Foundation

enum UserQuoteBrowseSettings {
    /// When `true`, the main quote browser and scheduled notifications use only quotes whose
    /// `sourceFile` is `Quotes_UserAdded` (still subject to enabled collection filters in
    /// `QuoteCategoryManager`). Favorites are unchanged.
    static let browseUserQuotesOnlyKey = "InnerWhisper.BrowseUserQuotesOnly"

    /// When `true`, the displayed quote order is shuffled (previous behaviour).
    /// When `false` (default), quotes are shown in their initial grouped order — sorted by
    /// collection then by display number — so the sequence is stable across launches.
    /// Notification scheduling always shuffles independently, regardless of this setting.
    static let shuffleDisplayedQuotesKey = "InnerWhisper.ShuffleDisplayedQuotes"

    /// Applies the same filter as the main quote browser: when “My quotes only” is on, returns
    /// only user-added quotes; otherwise returns `quotes` unchanged.
    ///
    /// `quotes` should already be category-filtered (e.g. from `QuoteProvider.getAllQuotes()`).
    static func filterQuotesMatchingMainBrowser(_ quotes: [Quote]) -> [Quote] {
        guard UserDefaults.standard.bool(forKey: browseUserQuotesOnlyKey) else {
            return quotes
        }
        return quotes.filter { $0.sourceFile == UserAddedQuotesStore.sourceFileName }
    }
}

extension Notification.Name {
    /// Posted when browse-only mode is turned off programmatically (e.g. opening a quote from a notification).
    static let userQuoteBrowseModeDidChange = Notification.Name("InnerWhisper.userQuoteBrowseModeDidChange")
}
