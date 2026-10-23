//
//  QuoteView.swift
//  InnerWhisper
//
//  Created by Robin O'Brien on 2026-03-04.
//

import SwiftUI

/// The main coordinator view for the InnerWhisper quote browsing interface.
///
/// This view manages the overall state and routing for the quote browsing experience,
/// showing different views based on the current state:
/// - Loading view while quotes are being loaded
/// - Error view if something goes wrong
/// - Quote content view for the main browsing experience
///
/// It also handles swipe gestures for navigation between quotes.
///
/// ## Accessibility Features
/// - Full VoiceOver support with descriptive labels and hints
/// - Haptic feedback on navigation
/// - Dynamic Type support for text scaling
/// - Swipe gestures for alternate navigation
struct QuoteView: View {
    /// The shared ViewModel injected from ContentView via the environment.
    @Environment(QuoteViewModel.self) private var viewModel
    @Environment(FavoritesManager.self) private var favoritesManager
    @AppStorage("InnerWhisper.SelectedBackground") private var selectedBackground: AppBackground = .space
    @AppStorage("InnerWhisper.SelectedIcon") private var selectedIcon: AppIcon = .yinYang
    @AppStorage("InnerWhisper.SelectedSound") private var selectedSound: AppSound = .default

    /// Resolved style built from the user's independent background, icon, and sound selections.
    private var currentStyle: QuoteThemeStyle {
        QuoteThemeStyle(
            background: selectedBackground.background,
            icon: selectedIcon.icon,
            quoteFont: .title2,
            defaultNotificationSoundIdentifier: selectedSound.soundIdentifier,
            preferredColorScheme: selectedBackground.preferredColorScheme,
            foregroundColor: selectedBackground.foregroundColor
        )
    }

    var body: some View {
        ZStack {
            ThemeBackgroundView(background: currentStyle.background)

            if viewModel.isLoading {
                loadingView
                    .padding()
            } else if let errorMessage = viewModel.errorMessage {
                errorView(message: errorMessage)
                    .padding()
            } else {
                QuoteContentView()
                    .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .environment(\.quoteFont, currentStyle.quoteFont)
        .environment(\.quoteThemeStyle, currentStyle)
        .preferredColorScheme(currentStyle.preferredColorScheme)
        .if(currentStyle.foregroundColor != nil) { view in
            view.foregroundStyle(currentStyle.foregroundColor!)
        }
        .task {
            await viewModel.loadQuotes()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Loading quotes...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .accessibleGroup(label: String(localized: "Loading inspirational quotes, please wait"))
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.orange)
                    .accessibleDecorative()

                Text(message)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity)
                    .accessibleStaticText(label: String(localized: "Error: \(message)"))

                if viewModel.isErrorRecoverable {
                    Button("Retry") {
                        HapticFeedback.light()
                        viewModel.retry()
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibleButton(
                        label: String(localized: "Retry loading quotes"),
                        hint: String(localized: "Double tap to attempt loading quotes again")
                    )
                } else {
                    Text("Please reinstall the app to resolve this issue.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .padding()
        }
    }


}

// MARK: - Previews

#Preview("Normal") {
    QuoteView()
        .environment(QuoteViewModel())
        .environment(FavoritesManager())
}

#Preview("Dark Mode") {
    QuoteView()
        .environment(QuoteViewModel())
        .environment(FavoritesManager())
        .preferredColorScheme(.dark)
}

#Preview("Large Text") {
    QuoteView()
        .environment(QuoteViewModel())
        .environment(FavoritesManager())
        .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
}
