//
//  QuoteNavigationControlsView.swift
//  InnerWhisper
//
//  Created for InnerWhisper.
//

import SwiftUI

/// Navigation controls for browsing quotes: previous, favorite, random, and next.
///
/// This view is intentionally decoupled from `QuoteViewModel` — it only needs
/// simple state values and action closures, making it easy to reuse in any
/// view that wants quote navigation.
///
/// ## Usage
/// ```swift
/// QuoteNavigationControlsView(
///     canGoToPrevious: viewModel.canGoToPrevious,
///     canGoToNext: viewModel.canGoToNext,
///     canGoToRandom: viewModel.totalCount > 1,
///     isFavorited: favoritesManager.isFavorite(quote.id),
///     onPrevious: viewModel.goToPrevious,
///     onNext: viewModel.goToNext,
///     onRandom: viewModel.goToRandom,
///     onFavorite: { favoritesManager.toggleFavorite(quote.id) }
/// )
/// ```
struct QuoteNavigationControlsView: View {
    let canGoToPrevious: Bool
    let canGoToNext: Bool
    let canGoToRandom: Bool
    let isFavorited: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onRandom: () -> Void
    let onFavorite: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// True when an accessibility text size is active — four icon buttons in one row
    /// no longer fit the screen width, so they reflow into a 2x2 grid instead.
    private var isAccessibilitySize: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        GlassEffectContainer(spacing: 20.0) {
            if isAccessibilitySize {
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        previousButton
                        favoriteButton
                    }
                    HStack(spacing: 16) {
                        randomButton
                        nextButton
                    }
                }
                .padding()
            } else {
                HStack(spacing: 20) {
                    previousButton
                    favoriteButton
                    randomButton
                    nextButton
                }
                .padding()
            }
        }
        .padding(.bottom)
    }

    // MARK: - Buttons

    private var previousButton: some View {
        Button {
            onPrevious()
        } label: {
            Label("Previous", systemImage: "chevron.left")
                .labelStyle(.iconOnly)
                .font(.title)
                .imageScale(.large)
        }
        .buttonStyle(.glass)
        .disabled(!canGoToPrevious)
        .accessibleButton(
            label: String(localized: "Previous quote"),
            hint: String(localized: "Shows the previous inspirational quote. Double tap or swipe right to activate.")
        )
    }

    private var favoriteButton: some View {
        Button {
            onFavorite()
        } label: {
            Label("Favorite", systemImage: isFavorited ? "heart.fill" : "heart")
                .labelStyle(.iconOnly)
                .font(.title)
                .imageScale(.large)
        }
        .buttonStyle(.glass)
        .tint(isFavorited ? .red : .primary)
        .accessibleButton(
            label: isFavorited
                ? String(localized: "Remove from favorites")
                : String(localized: "Add to favorites"),
            hint: String(localized: "Double tap to toggle favorite status for this quote")
        )
    }

    private var randomButton: some View {
        Button {
            onRandom()
        } label: {
            Label("Random", systemImage: "shuffle")
                .labelStyle(.iconOnly)
                .font(.title)
                .imageScale(.large)
        }
        .buttonStyle(.glass)
        .disabled(!canGoToRandom)
        .accessibleButton(
            label: String(localized: "Random quote"),
            hint: String(localized: "Jumps to a randomly selected quote. Double tap to activate.")
        )
    }

    private var nextButton: some View {
        Button {
            onNext()
        } label: {
            Label("Next", systemImage: "chevron.right")
                .labelStyle(.iconOnly)
                .font(.title)
                .imageScale(.large)
        }
        .buttonStyle(.glass)
        .disabled(!canGoToNext)
        .accessibleButton(
            label: String(localized: "Next quote"),
            hint: String(localized: "Shows the next inspirational quote. Double tap or swipe left to activate.")
        )
    }
}

// MARK: - Previews

#Preview {
    QuoteNavigationControlsView(
        canGoToPrevious: true,
        canGoToNext: true,
        canGoToRandom: true,
        isFavorited: false,
        onPrevious: {},
        onNext: {},
        onRandom: {},
        onFavorite: {}
    )
}

#Preview("Large Text") {
    QuoteNavigationControlsView(
        canGoToPrevious: true,
        canGoToNext: true,
        canGoToRandom: true,
        isFavorited: false,
        onPrevious: {},
        onNext: {},
        onRandom: {},
        onFavorite: {}
    )
    .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
}
