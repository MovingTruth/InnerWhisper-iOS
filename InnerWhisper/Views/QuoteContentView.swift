//
//  QuoteContentView.swift
//  InnerWhisper
//
//  Created by Robin O'Brien on 2026-03-08.
//

import SwiftUI

/// Displays the main quote browsing interface with header and navigation controls.
///
/// This view shows:
/// - A decorative quote icon and position indicator (fixed at top) in portrait
/// - In landscape, the icon is hidden so the quote uses the full area
/// - The current quote card inside a ScrollView
/// - Navigation controls (fixed at bottom)
struct QuoteContentView: View {
    @Environment(QuoteViewModel.self) private var viewModel
    @Environment(FavoritesManager.self) private var favoritesManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.quoteThemeStyle) private var quoteThemeStyle
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.layoutDirection) private var layoutDirection

    /// True when in landscape (compact vertical), so we hide the icon and show quote full-bleed.
    private var isLandscape: Bool { verticalSizeClass == .compact }
    /// True when an accessibility text size is active — the 155 pt icon would eat most of the screen.
    private var isAccessibilitySize: Bool { dynamicTypeSize.isAccessibilitySize }

    private let forwardTransition = AnyTransition.asymmetric(
        insertion: .move(edge: .trailing).combined(with: .opacity),
        removal: .move(edge: .leading).combined(with: .opacity)
    )
    private let backwardTransition = AnyTransition.asymmetric(
        insertion: .move(edge: .leading).combined(with: .opacity),
        removal: .move(edge: .trailing).combined(with: .opacity)
    )

    var body: some View {
        VStack(spacing: 0) {
            // Quote area — header optional (hidden in landscape)
            VStack(spacing: 0) {
                // Fixed header with decorative quote icon and position (portrait only, normal text sizes only)
                if !isLandscape && !isAccessibilitySize {
                    VStack(spacing: 20) {
                        ThemeIconView(icon: quoteThemeStyle?.icon ?? .systemImage("quote.bubble.fill"))

                        Text(viewModel.positionText)
                            .padding(.top, 20)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .accessibilityLabel(viewModel.positionAccessibilityLabel)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 30)
                } else if !isLandscape {
                    // At accessibility sizes show only the compact position indicator, no 155pt icon
                    Text(viewModel.positionText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .accessibilityLabel(viewModel.positionAccessibilityLabel)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)
                }

                if let quote = viewModel.currentQuote {
                    quoteContent(quote: quote)
                } else {
                    noQuotesPlaceholder
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Navigation controls — fixed at bottom, always visible
            navigationControls

            InnerWhisperLogoView()
        }
        .frame(maxWidth: horizontalSizeClass == .regular ? 700 : .infinity)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Quote content

    /// Always uses a ScrollView so the view type never changes between navigations.
    /// Keeping a single, stable view type ensures the `.id()`-driven transition fires
    /// without an unrelated branch-switch disrupting the animation.
    private func quoteContent(quote: Quote) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            QuoteCardView(quote: quote)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, isLandscape ? 0 : 32)
        .transition(viewModel.navigationDirection == .forward ? forwardTransition : backwardTransition)
        .id(viewModel.currentIndex)
        // simultaneousGesture lets the inner ScrollView handle vertical scrolling
        // while this recogniser still fires for horizontal swipes. Attaching it here
        // (rather than on the parent) means drags starting on the icon never trigger
        // navigation — no coordinate-space exclusion needed.
        .simultaneousGesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    let horizontal = abs(value.translation.width)
                    let vertical   = abs(value.translation.height)
                    guard horizontal > vertical, horizontal > 50 else { return }
                    // A swipe toward the leading edge always advances, and toward the
                    // trailing edge always goes back — matching how forwardTransition/
                    // backwardTransition already move content via .leading/.trailing,
                    // so this reverses correctly under RTL without extra branching there.
                    let isPhysicalLeftwardSwipe = value.translation.width < 0
                    let advancesToNext = layoutDirection == .rightToLeft
                        ? !isPhysicalLeftwardSwipe
                        : isPhysicalLeftwardSwipe
                    if advancesToNext {
                        viewModel.goToNext()
                    } else {
                        viewModel.goToPrevious()
                    }
                }
        )
    }

    // MARK: - No quotes placeholder

    private var noQuotesPlaceholder: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 16) {
                Image(systemName: "text.quote")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                    .accessibleDecorative()

                if viewModel.isBrowseUserQuotesOnlyEmpty {
                    Text("No quotes you’ve added yet")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Text("Turn off “My quotes only” above to browse all collections, or use the + button to add your own.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                } else {
                    Text("No quotes available")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Button("Try Again") {
                        HapticFeedback.light()
                        viewModel.retry()
                    }
                    .buttonStyle(.bordered)
                    .accessibleButton(
                        label: String(localized: "Try again"),
                        hint: String(localized: "Double tap to attempt reloading quotes")
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            viewModel.isBrowseUserQuotesOnlyEmpty
                ? String(localized: "No quotes you added yet. Turn off My quotes only or add a quote.")
                : String(localized: "No quotes available. Double tap Try Again to reload.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Navigation Controls

    private var navigationControls: some View {
        QuoteNavigationControlsView(
            canGoToPrevious: viewModel.canGoToPrevious,
            canGoToNext: viewModel.canGoToNext,
            canGoToRandom: viewModel.totalCount > 1,
            isFavorited: viewModel.currentQuote.map { favoritesManager.isFavorite($0.id) } ?? false,
            onPrevious: viewModel.goToPrevious,
            onNext: viewModel.goToNext,
            onRandom: viewModel.goToRandom,
            onFavorite: {
                guard let quote = viewModel.currentQuote else { return }
                HapticFeedback.light()
                favoritesManager.toggleFavorite(quote.id)
            }
        )
    }
}

// MARK: - Previews

#Preview("Normal") {
    QuoteContentView()
        .environment(QuoteViewModel())
        .environment(FavoritesManager())
}

#Preview("Dark Mode") {
    QuoteContentView()
        .environment(QuoteViewModel())
        .environment(FavoritesManager())
        .preferredColorScheme(.dark)
}

#Preview("Large Text") {
    QuoteContentView()
        .environment(QuoteViewModel())
        .environment(FavoritesManager())
        .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
}
