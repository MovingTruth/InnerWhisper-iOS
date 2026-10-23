//
//  FavoritesListView.swift
//  InnerWhisper
//
//  Created for InnerWhisper.
//

import SwiftUI
import UIKit

/// Displays a scrollable list of quotes the user has marked as favorites.
///
/// Resolves favorite IDs against the currently loaded quote set (from the shared
/// QuoteViewModel). Tapping a quote navigates to it on the main screen and dismisses
/// this view. Supports unfavoriting from the list.
struct FavoritesListView: View {
    @Environment(QuoteViewModel.self) private var quoteViewModel
    @Environment(FavoritesManager.self) private var favoritesManager
    @Environment(\.dismiss) private var dismiss

    @State private var quoteToShare: Quote?

    /// Quotes that are both loaded and in the favorites set, sorted by display number.
    private var favoriteQuotes: [Quote] {
        guard let allQuotes = quoteViewModel.loadingState.data else {
            return []
        }
        return allQuotes
            .filter { favoritesManager.favoriteIds.contains($0.id) }
            .sorted { $0.displayNumber < $1.displayNumber }
    }

    var body: some View {
        Group {
            if quoteViewModel.isLoading {
                loadingView
            } else if quoteViewModel.loadingState.isFailure {
                errorView
            } else if favoriteQuotes.isEmpty {
                emptyView
            } else {
                listView
            }
        }
        .background(.regularMaterial)
        .navigationTitle("Favorites")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Loading State

    private var loadingView: some View {
        ContentUnavailableView {
            Label {
                Text("Loading quotes")
            } icon: {
                Image(systemName: "heart.text.square")
                    // Scope the effect to this symbol only — a container-level repeating pulse
                    // can interact badly with other SF Symbols after a navigation transition.
                    .symbolEffect(.pulse, options: .repeating, isActive: quoteViewModel.isLoading, )
            }
        } description: {
            Text("Your favorite quotes will appear here once loading is complete.")
        }
    }

    // MARK: - Error State

    private var errorView: some View {
        ContentUnavailableView {
            Label("Quotes unavailable", systemImage: "exclamationmark.triangle")
        } description: {
            Text(quoteViewModel.errorMessage ?? "Unable to load quotes.")
        } actions: {
            Button("Retry") {
                quoteViewModel.retry()
            }
            .accessibleButton(label: String(localized: "Retry loading quotes"), hint: String(localized: "Double tap to try loading again"))
        }
    }

    // MARK: - Empty State

    private var emptyView: some View {
        ContentUnavailableView {
            Label("No favorites yet", systemImage: "heart")
        } description: {
            Text("Tap the heart on any quote to add it here.")
        }
    }

    // MARK: - List

    private var listView: some View {
        List {
            ForEach(favoriteQuotes) { quote in
                favoriteRow(quote: quote)
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .accessibilityLabel(String(localized: "Favorites list, \(favoriteQuotes.count) quotes"))
        .sheet(item: $quoteToShare) { quote in
            ActivityView(activityItems: [quote.shareableText])
                .presentationDetents([.medium, .large])
        }
    }

    /// A single row: quote card, tap to go to quote; swipe or context menu for favorites, copy, and share.
    private func favoriteRow(quote: Quote) -> some View {
        Button {
            HapticFeedback.light()
            _ = quoteViewModel.goToQuote(id: quote.id)
            dismiss()
        } label: {
            QuoteCardView(quote: quote, showContextMenu: false)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                HapticFeedback.light()
                quoteToShare = quote
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .tint(.blue)
            Button {
                HapticFeedback.light()
                UIPasteboard.general.string = quote.shareableText
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .tint(.indigo)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                HapticFeedback.light()
                favoritesManager.toggleFavorite(quote.id)
            } label: {
                Label("Remove", systemImage: "heart.slash")
            }
            .accessibilityLabel(String(localized: "Remove from favorites"))
        }
        .contextMenu {
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
        .accessibilityLabel("\(quote.text), by \(quote.author)")
        .environment(\.locale, Locale(identifier: AppLanguage.current.resolvedLanguageCode))
        .accessibilityHint(String(localized: "Double tap to open this quote on the main screen. Swipe right to share or copy. Swipe left to remove from favorites. Long press for more options."))
    }
}

// MARK: - Activity View

private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Previews

#Preview("With favorites") {
    NavigationStack {
        FavoritesListView()
            .environment(QuoteViewModel())
            .environment(FavoritesManager.shared)
    }
}

#Preview("Empty") {
    NavigationStack {
        FavoritesListView()
            .environment(QuoteViewModel())
            .environment(FavoritesManager.shared)
    }
}
