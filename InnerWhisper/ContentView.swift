//
//  ContentView.swift
//  InnerWhisper
//
//  Created by Robin O'Brien on 2026-02-24.
//
//  Completed for App store release April 6, 2026.  I think its done.

import StoreKit
import SwiftUI

/// The root navigation container for the InnerWhisper application.
///
/// Owns the `QuoteViewModel` and injects it as an environment object so that
/// any child view — including sheets such as `SettingsView` — can access and
/// trigger actions on the shared view model (e.g. force-refreshing quotes).
struct ContentView: View {
    /// Set to `true` while `SkyLaunchSplashView` is covering the screen so
    /// the onboarding sheet is not presented until the splash has finished.
    var splashIsVisible: Bool = false

    @State private var quoteViewModel = QuoteViewModel()
    private let favoritesManager = FavoritesManager.shared
    @State private var showingSettings = false
    @State private var showingNotificationSettings = false
    @State private var showingAppInfo = false
    @State private var showAddQuoteSheet = false
    /// Programmatic push to Favorites avoids toolbar `NavigationLink` transition glitches (leading items fading on pop).
    @State private var showFavorites = false
    @Environment(\.scenePhase) private var scenePhase

    /// Tracks whether the user has completed the first-launch onboarding walkthrough.
    @AppStorage("InnerWhisper.hasShownOnboarding") private var hasShownOnboarding = false

    /// Number of cold launches recorded (incremented in `InnerWhisperApp.init`).
    @AppStorage("InnerWhisper.appLaunchCount") private var appLaunchCount = 0
    /// Prevents the review prompt from appearing more than once.
    @AppStorage("InnerWhisper.hasRequestedReview") private var hasRequestedReview = false
    @Environment(\.requestReview) private var requestReview


    var body: some View {
        ZStack {
        NavigationStack {
            QuoteView()
                .navigationDestination(isPresented: $showFavorites) {
                    FavoritesListView()
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            HapticFeedback.light()
                            showFavorites = true
                        } label: {
                            Label("Favorites", systemImage: "heart.fill")
                        }
                        .buttonStyle(.plain)
                        .accessibleButton(
                            label: String(localized: "Favorites"),
                            hint: String(localized: "View your saved favorite quotes")
                        )
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        HStack(spacing: 12) {
                            if let quote = quoteViewModel.currentQuote {
                                ShareLink(
                                    item: quote.shareableText,
                                    subject: Text("A whisper from Moving Truth"),
                                    message: Text(quote.shareableText)
                                ) {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                }
                                .accessibilityLabel(String(localized: "Share quote"))
                                .accessibilityHint(String(localized: "Double tap to share this quote"))
                            }
                            Button {
                                HapticFeedback.light()
                                showAddQuoteSheet = true
                            } label: {
                                Label("Add quote", systemImage: "plus")
                            }
                            .accessibilityLabel(String(localized: "Add your own quote"))
                            .accessibilityHint(String(localized: "Double tap to add a quote to your User Added collection"))
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            HapticFeedback.light()
                            showingSettings = true
                        } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                        .accessibleButton(
                            label: String(localized: "Settings"),
                            hint: String(localized: "Open app settings including notifications, security, and quote updates")
                        )
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            HapticFeedback.light()
                            showingNotificationSettings = true
                        } label: {
                            Label(
                                quoteViewModel.notificationsEnabled ? "Notifications On" : "Notifications Off",
                                systemImage: quoteViewModel.notificationsEnabled ? "bell.badge" : "bell.slash"
                            )
                        }
                        .accessibleButton(
                            label: quoteViewModel.notificationsEnabled
                                ? String(localized: "Notifications On")
                                : String(localized: "Notifications Off"),
                            hint: String(localized: "Configure quote notification schedule. Double tap to open.")
                        )
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            HapticFeedback.light()
                            withAnimation(.easeInOut(duration: 0.38)) { showingAppInfo = true }
                        } label: {
                            Label("About", systemImage: "info.circle")
                        }
                        .accessibleButton(
                            label: String(localized: "About"),
                            hint: String(localized: "View app information and developer details")
                        )
                    }
                }
                .sheet(isPresented: $showingSettings) {
                    SettingsView(isPresented: $showingSettings)
                }
                .sheet(isPresented: $showingNotificationSettings, onDismiss: {
                    quoteViewModel.refreshNotificationState()
                }) {
                    NotificationConfigurationView()
                }
                .sheet(isPresented: $showAddQuoteSheet, onDismiss: {
                    // Run after the dismiss transition so bar items are not caught in its animation.
                    DispatchQueue.main.async {
                        quoteViewModel.reloadWithCurrentCategories()
                    }
                }) {
                    UserQuoteEditorSheet(quote: nil)
                }
        }
        .environment(quoteViewModel)
        .environment(favoritesManager)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                quoteViewModel.handlePendingNotificationOpen()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .userAddedQuotesDidChange)) { _ in
            quoteViewModel.reloadWithCurrentCategories()
        }
        .onReceive(NotificationCenter.default.publisher(for: .userQuoteBrowseModeDidChange)) { _ in
            quoteViewModel.reloadBrowseMode()
            Task {
                let settings = NotificationSettings.load()
                if settings.isEnabled {
                    await NotificationManager.shared.apply(settings: settings)
                }
            }
        }
        // After the splash screen finishes on a cold launch, check whether to
        // prompt the user to rate the app (shown once, on the 10th cold launch).
        .onChange(of: splashIsVisible) { _, isVisible in
            guard !isVisible, appLaunchCount >= 10, !hasRequestedReview else { return }
            hasRequestedReview = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                requestReview()
            }
        }
        // Onboarding fires on first launch. Security info is included as a
        // page within the onboarding, and is also reachable from Settings.
        .fullScreenCover(isPresented: Binding(
            get: { !hasShownOnboarding && !splashIsVisible },
            set: { _ in }
        )) {
            OnboardingView {
                quoteViewModel.refreshNotificationState()
                hasShownOnboarding = true
            }
        }

        if showingAppInfo {
            Info2View(dismissAction: {
                withAnimation(.easeInOut(duration: 0.38)) { showingAppInfo = false }
            })
            .transition(.asymmetric(
                insertion: .move(edge: .trailing),
                removal: .move(edge: .trailing)
            ))
            .zIndex(100)
        }
        }
    }
}

// MARK: - Previews

#Preview("Light Mode") {
    ContentView()
}

#Preview("Dark Mode") {
    ContentView()
        .preferredColorScheme(.dark)
}
