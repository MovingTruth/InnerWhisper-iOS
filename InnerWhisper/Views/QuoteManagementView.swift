//
//  QuoteManagementView.swift
//  InnerWhisper
//
//  Created for InnerWhisper.
//

import SwiftUI
import UIKit

/// Browse all bundled quote collections, see every quote organised by file and category,
/// and toggle which collections appear in the app and notifications. User-added quotes
/// are listed under "User Added" and stored encrypted (synced via iCloud when available).
struct QuoteManagementView: View {

    @Environment(QuoteViewModel.self) private var quoteViewModel
    @Environment(FavoritesManager.self) private var favoritesManager
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// The Settings sheet’s presentation binding from `ContentView` (via `SettingsView`). Using this instead of `Environment.dismiss` closes the entire sheet; `dismiss` would only pop this view inside the navigation stack.
    @Binding var isPresented: Bool
    private let categoryManager = QuoteCategoryManager.shared
    private let userQuotesStore = UserAddedQuotesStore.shared


    /// Loaded quotes from each bundle file, keyed by file name.
    @State private var quotesByFile: [String: [Quote]] = [:]
    /// Loaded quotes from remote source with category 'Extra'.
    @State private var remoteExtraQuotes: [Quote] = []
    /// Tracks which collection sections are expanded to show individual quotes.
    @State private var expandedFiles: Set<String> = []
    @State private var isLoading = true
    @State private var showUserQuoteEditor = false
    @State private var userQuoteToEdit: Quote?
    @State private var quotePendingDelete: Quote?


    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading collections…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                collectionList
            }
        }
        .navigationTitle("Quote Collections")
        .navigationBarTitleDisplayMode(.large)
        .task { await loadAllCollections() }
        .onDisappear {
            // Reload quotes in the view model so that any enable/disable changes
            // take effect immediately in the app and notification cycle.
            quoteViewModel.reloadWithCurrentCategories()
        }
        .sheet(isPresented: $showUserQuoteEditor, onDismiss: {
            quoteViewModel.reloadWithCurrentCategories()
        }) {
            UserQuoteEditorSheet(quote: userQuoteToEdit)
        }
        .confirmationDialog(
            "Delete this quote?",
            isPresented: Binding(
                get: { quotePendingDelete != nil },
                set: { if !$0 { quotePendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let q = quotePendingDelete {
                    try? UserAddedQuotesStore.shared.deleteQuote(id: q.id)
                    quoteViewModel.reloadWithCurrentCategories()
                }
                quotePendingDelete = nil
            }
            Button("Cancel", role: .cancel) {
                quotePendingDelete = nil
            }
        } message: {
            Text("This cannot be undone.")
        }
    }

    // MARK: - Collection List

    private var collectionList: some View {
        List {
            UserQuoteBrowseModeSection(placement: .quoteManagement)
            summarySection
            ForEach(QuoteCategoryManager.allCollections) { info in
                collectionSection(for: info)
            }
            remoteExtraSection
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Summary Header Section

    private var summarySection: some View {
        Section {
            let totalEnabled = QuoteCategoryManager.allCollections
                .filter { categoryManager.isEnabled($0.fileName) }
                .count
            let totalQuotes = QuoteCategoryManager.allCollections
                .filter { categoryManager.isEnabled($0.fileName) }
                .reduce(0) { sum, info in
                    let count = info.fileName == UserAddedQuotesStore.sourceFileName
                        ? userQuotesStore.quotes.count
                        : (quotesByFile[info.fileName]?.count ?? 0)
                    return sum + count
                }

            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 16) {
                        summaryValue(
                            value: "\(totalEnabled) of \(QuoteCategoryManager.allCollections.count)",
                            label: String(localized: "Collections enabled")
                        )
                        summaryValue(
                            value: "\(totalQuotes)",
                            label: String(localized: "Quotes active")
                        )
                    }
                } else {
                    HStack(spacing: 16) {
                        summaryValue(
                            value: "\(totalEnabled) of \(QuoteCategoryManager.allCollections.count)",
                            label: String(localized: "Collections enabled")
                        )
                        Spacer()
                        summaryValue(
                            value: "\(totalQuotes)",
                            label: String(localized: "Quotes active"),
                            alignment: .trailing
                        )
                    }
                }
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(localized: "\(totalEnabled) of \(QuoteCategoryManager.allCollections.count) collections enabled, \(totalQuotes) quotes active"))
        } footer: {
            Text("Disabled collections are hidden from both the quote browser and notifications.")
        }
    }

    private func summaryValue(
        value: String,
        label: String,
        alignment: HorizontalAlignment = .leading
    ) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(value)
                .font(.title2.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Remote Extra Section

    private var remoteExtraSection: some View {
        let isExpanded = expandedFiles.contains("Remote_Extra")
        
        return Section {
            // Info row
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Remote Quotes")
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text("Category: Extra")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(remoteExtraQuotes.count) quote")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "cloud.fill")
                    .foregroundStyle(.blue)
                    .font(.title3)
            }
            .padding(.vertical, 2)
            
            // Top collapse button (only visible when expanded)
            if isExpanded && !remoteExtraQuotes.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        _ = expandedFiles.remove("Remote_Extra")
                    }
                } label: {
                    HStack {
                        Text("Hide Quotes")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "chevron.up")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityHint(String(localized: "Collapse quote list"))
            }
            
            // Expandable quote list
            if isExpanded && !remoteExtraQuotes.isEmpty {
                quoteRows(quotes: remoteExtraQuotes, isEnabled: true, isUserAdded: false)
            }
            
            // Bottom expand / collapse button
            if !remoteExtraQuotes.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if isExpanded {
                            _ = expandedFiles.remove("Remote_Extra")
                        } else {
                            _ = expandedFiles.insert("Remote_Extra")
                        }
                    }
                } label: {
                    HStack {
                        Text(isExpanded ? "Hide Quotes" : "Show \(remoteExtraQuotes.count) Quote")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityHint(isExpanded ? String(localized: "Collapse quote list") : String(localized: "Expand to view individual quotes"))
            }
        } header: {
            Label("Remote Collection", systemImage: "icloud.and.arrow.down")
        } footer: {
            if remoteExtraQuotes.isEmpty {
                Text("No remote quotes available. Remote quotes are fetched from the server and appear here when available.")
            } else {
                Text("Remote quotes are loaded from the server and automatically refresh every 24 hours.")
            }
        }
    }

    // MARK: - Per-Collection Section

    @ViewBuilder
    private func collectionSection(for info: QuoteCollection_Info) -> some View {
        let quotes: [Quote] = {
            if info.fileName == UserAddedQuotesStore.sourceFileName {
                return userQuotesStore.quotes
            }
            return quotesByFile[info.fileName] ?? []
        }()
        let isEnabled = categoryManager.isEnabled(info.fileName)
        let isExpanded = expandedFiles.contains(info.fileName)
        let isUserAddedSection = info.fileName == UserAddedQuotesStore.sourceFileName
        let categoryFallback = isUserAddedSection ? UserAddedQuotesStore.categoryDisplayName : nil

        Section {
            collectionToggleRow(info: info, quotes: quotes, isEnabled: isEnabled, categoryFallback: categoryFallback)

            if isUserAddedSection {
                Button {
                    HapticFeedback.light()
                    userQuoteToEdit = nil
                    showUserQuoteEditor = true
                } label: {
                    Label("Add your own quote", systemImage: "plus.circle.fill")
                }
                .accessibilityHint(String(localized: "Opens a form to add a quote to your User Added collection"))
            }

            // Top collapse button (only visible when expanded)
            if isExpanded && !quotes.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        _ = expandedFiles.remove(info.fileName)
                    }
                } label: {
                    HStack {
                        Text("Hide Quotes")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "chevron.up")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityHint(String(localized: "Collapse quote list"))
            }

            // Expandable quote list
            if isExpanded && !quotes.isEmpty {
                quoteRows(quotes: quotes, isEnabled: isEnabled, isUserAdded: isUserAddedSection)
            }

            // Bottom expand / collapse button
            if !quotes.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if isExpanded {
                            _ = expandedFiles.remove(info.fileName)
                        } else {
                            _ = expandedFiles.insert(info.fileName)
                        }
                    }
                } label: {
                    HStack {
                        Text(isExpanded ? "Hide Quotes" : "Show \(quotes.count) Quote")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityHint(isExpanded ? String(localized: "Collapse quote list") : String(localized: "Expand to view individual quotes"))
            }
        } header: {
            Label(info.displayName, systemImage: info.symbol)
        } footer: {
            if isUserAddedSection {
                Text("Your quotes are encrypted on device and can sync across your Apple devices via iCloud when you are signed in.")
            }
        }
    }

    // MARK: - Collection Toggle Row

    private func collectionToggleRow(
        info: QuoteCollection_Info,
        quotes: [Quote],
        isEnabled: Bool,
        categoryFallback: String? = nil
    ) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(info.displayName)
                    .font(.body)
                    .foregroundStyle(isEnabled ? .primary : .secondary)
                if let category = quotes.first?.category ?? categoryFallback {
                    Text("Category: \(category)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("\(quotes.count) quote")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { _ in
                    HapticFeedback.light()
                    categoryManager.toggle(info.fileName)
                }
            ))
            .labelsHidden()
            .disabled(isEnabled && !categoryManager.hasMoreThanOneEnabled)
            .accessibilityLabel(String(localized: "\(info.displayName) collection \(isEnabled ? String(localized: "enabled") : String(localized: "disabled"))"))
            .accessibilityHint(collectionToggleHint(isEnabled: isEnabled))
        }
        .padding(.vertical, 2)
        .opacity(isEnabled ? 1.0 : 0.6)
    }

    /// Full-phrase hint per state — never a template with a word swapped in, since the
    /// "cannot disable" case is structurally different, not just an opposite word.
    private func collectionToggleHint(isEnabled: Bool) -> String {
        if isEnabled && !categoryManager.hasMoreThanOneEnabled {
            return String(localized: "Cannot disable — at least one collection must remain active")
        } else if isEnabled {
            return String(localized: "Toggle to disable this collection")
        } else {
            return String(localized: "Toggle to enable this collection")
        }
    }

    // MARK: - Individual Quote Rows

    @ViewBuilder
    private func quoteRows(quotes: [Quote], isEnabled: Bool, isUserAdded: Bool) -> some View {
        ForEach(quotes) { quote in
            Button {
                HapticFeedback.light()
                if quoteViewModel.goToQuote(id: quote.id) {
                    isPresented = false
                }
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 8) {
                        Text(quote.text)
                            .font(.subheadline)
                            .foregroundStyle(isEnabled ? .primary : .secondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        if favoritesManager.isFavorite(quote.id) {
                            Image(systemName: "heart.fill")
                                .font(.caption)
                                .foregroundStyle(.red)
                                .accessibilityHidden(true)
                        }
                    }
                    Group {
                        if dynamicTypeSize.isAccessibilitySize {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("— \(quote.author)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                if let category = quote.category {
                                    categoryLabel(category)
                                }
                            }
                        } else {
                            HStack {
                                Text("— \(quote.author)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                if let category = quote.category {
                                    categoryLabel(category)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
                .opacity(isEnabled ? 1.0 : 0.5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .contextMenu {
                if isUserAdded {
                    Button {
                        HapticFeedback.light()
                        userQuoteToEdit = quote
                        showUserQuoteEditor = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        quotePendingDelete = quote
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                Button {
                    HapticFeedback.light()
                    favoritesManager.toggleFavorite(quote.id)
                } label: {
                    Label(
                        favoritesManager.isFavorite(quote.id) ? String(localized: "Remove from Favorites") : String(localized: "Add to Favorites"),
                        systemImage: favoritesManager.isFavorite(quote.id) ? "heart.slash" : "heart"
                    )
                }
                Button {
                    UIPasteboard.general.string = quote.shareableText
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                ShareLink(
                    item: quote.shareableText,
                    subject: Text("A whisper from Moving Truth"),
                    message: Text(quote.shareableText)
                ) {
                    Label("Share Quote", systemImage: "square.and.arrow.up")
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(quoteRowAccessibilityLabel(quote: quote))
            .environment(\.locale, Locale(identifier: AppLanguage.current.resolvedLanguageCode))
            .accessibilityHint(String(localized: "Double tap to open this quote on the main screen. Long press to copy, share, or add to favorites."))
        }
    }

    private func categoryLabel(_ category: String) -> some View {
        Text(category)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.secondary.opacity(0.15), in: Capsule())
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Combines quote content (verbatim -- pronunciation locale is handled separately via
    /// `.environment(\.locale, ...)` at the call site) with localized UI chrome for
    /// favorite/category state. Only the connective words are looked up in the catalog.
    private func quoteRowAccessibilityLabel(quote: Quote) -> String {
        var label = String(localized: "\(quote.text) by \(quote.author)")
        if favoritesManager.isFavorite(quote.id) {
            label += String(localized: ", favorited")
        }
        if let category = quote.category {
            label += String(localized: ", category: \(category)")
        }
        return label
    }

    // MARK: - Data Loading

    /// Loads quotes from each bundle file independently for display in the management view.
    /// This runs fresh from the bundle (not the aggregated cache) so the list is always complete.
    /// Also loads remote quotes with category 'Extra' from the remote source and user-added quotes from `UserAddedQuotesStore`.
    private func loadAllCollections() async {
        isLoading = true
        // Do NOT call UserAddedQuotesStore.shared.loadFromDisk() here.
        // The store is already synchronized at app launch and on every foreground transition
        // via synchronizeFromCloud(). Calling loadFromDisk() again blocks opening this view
        // for up to 7.5 s when iCloud Keychain is still syncing (5 retries × 1.5 s each).
        // @Observable tracking keeps the view up-to-date whenever quotes change.

        var result: [String: [Quote]] = [:]
        var remoteQuotes: [Quote] = []

        await withTaskGroup(of: (String, [Quote]).self) { group in
            for info in QuoteCategoryManager.allCollections {
                guard info.fileName != UserAddedQuotesStore.sourceFileName else { continue }
                group.addTask {
                    let source = BundleQuoteSource(resourceName: info.fileName)
                    let quotes = (try? await source.fetchQuotes()) ?? []
                    return (info.fileName, quotes)
                }
            }

            if let remoteURL = AggregatingQuoteProvider.remoteExtraQuotesJSONURL {
                group.addTask {
                    // 5 s timeout keeps a slow/unavailable server from blocking the view open.
                    let source = RemoteQuoteSource(url: remoteURL, defaultCategory: "Extra", timeoutInterval: 5)
                    let quotes = (try? await source.fetchQuotes()) ?? []
                    return ("Remote_Extra", quotes)
                }
            }

            for await (fileName, quotes) in group {
                if fileName == "Remote_Extra" {
                    remoteQuotes = quotes
                } else {
                    result[fileName] = quotes
                }
            }
        }

        result[UserAddedQuotesStore.sourceFileName] = UserAddedQuotesStore.shared.quotes

        await MainActor.run {
            quotesByFile = result
            remoteExtraQuotes = remoteQuotes
            isLoading = false
        }
    }
}

// MARK: - Previews

#Preview {
    NavigationStack {
        QuoteManagementView(isPresented: .constant(true))
            .environment(QuoteViewModel())
            .environment(FavoritesManager.shared)
    }
}
