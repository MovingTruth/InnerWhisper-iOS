//
//  SettingsView.swift
//  InnerWhisper
//
//  Created for InnerWhisper.
//

import SwiftUI

/// The main settings screen for InnerWhisper.
///
/// Provides access to quote management, notification configuration,
/// and security settings in a single organized Form.
struct SettingsView: View {
    /// Controls the Settings sheet from `ContentView`; passed to child views that must dismiss the whole sheet (not only pop navigation).
    @Binding var isPresented: Bool
    @Environment(QuoteViewModel.self) private var quoteViewModel
    @State private var showingNotificationSettings = false
    @State private var showingSoundSettings = false
    @State private var showingEncryptionSettings = false
    @State private var showingOnboarding = false
    @State private var showingSecurityWelcome = false
    @State private var showingAppInfo = false
    @State private var showingDisclaimer = false
    @AppStorage(UserQuoteBrowseSettings.shuffleDisplayedQuotesKey) private var shuffleDisplayedQuotes = false
    @AppStorage(AppLanguage.storageKey) private var appLanguageRaw: String = AppLanguage.systemDefault.rawValue
    @State private var showingLanguageRestartAlert = false

    /// Public privacy policy (same URL as App Store Connect).
    private let privacyPolicyURL = URL(string: "https://inner-whisper.movingtruth.com/privacy_policy.html")!
    /// Opens the user's mail app with support pre-addressed and subject pre-filled.
    private let reportProblemURL = URL(string: "mailto:support@movingtruth.com?subject=Inner%20Whisper%20Issue%20-%20User%20Reported")!

    var body: some View {
        ZStack {
            NavigationStack {
                Form {
                    appearanceSection
                    quotesSection
                    shuffleSection
                    languageSection
                    notificationsSection
                    securitySection
                    aboutSection
                }
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            HapticFeedback.light()
                            isPresented = false
                        }
                        .accessibleButton(label: String(localized: "Done"), hint: String(localized: "Close settings"))
                    }
                }
                .sheet(isPresented: $showingNotificationSettings, onDismiss: {
                    quoteViewModel.refreshNotificationState()
                }) {
                    NotificationConfigurationView()
                }
                .sheet(isPresented: $showingSoundSettings) {
                    SoundSettingsView()
                }
                .sheet(isPresented: $showingEncryptionSettings) {
                    EncryptionSettingsView()
                }
                .sheet(isPresented: $showingOnboarding) {
                    OnboardingView { showingOnboarding = false }
                }
                .sheet(isPresented: $showingSecurityWelcome) {
                    SecurityWelcomeView { showingSecurityWelcome = false }
                }
                .sheet(isPresented: $showingDisclaimer) {
                    QuoteSourceDisclaimerView(onDismiss: { showingDisclaimer = false })
                }
                .alert(
                    String(localized: "Language Updated"),
                    isPresented: $showingLanguageRestartAlert
                ) {
                    Button(String(localized: "OK"), role: .cancel) {}
                } message: {
                    Text("Quotes have updated. Close and reopen Inner Whisper to update menus and buttons throughout the app.")
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

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        Section {
            NavigationLink {
                ThemeSettingsView()
            } label: {
                Label("Appearance", systemImage: "paintpalette")
                    .foregroundStyle(.blue)
            }
            .accessibilityHint(String(localized: "Customise background, icon, and notification sound"))
        } header: {
            Text("Appearance")
        } footer: {
            Text("Choose a background, decorative icon, and notification sound.")
        }
    }

    // MARK: - Quotes Section

    private var quotesSection: some View {
        Section {
            NavigationLink {
                QuoteManagementView(isPresented: $isPresented)
            } label: {
                Label("Manage Collections", systemImage: "books.vertical")
                    .foregroundStyle(.blue)
            }
            .accessibilityHint(String(localized: "Browse all quote collections, view individual quotes, and enable or disable categories"))

            Button {
                Task { await quoteViewModel.refreshQuotes() }
            } label: {
                HStack {
                    Label("Update Quotes", systemImage: "arrow.clockwise")
                        .foregroundStyle(.primary)
                    Spacer()
                    if quoteViewModel.isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
            .disabled(quoteViewModel.isRefreshing)
            .accessibleButton(
                label: String(localized: "Update quotes"),
                hint: String(localized: "Double tap to fetch the latest quotes from all sources")
            )

            if let message = quoteViewModel.refreshStatusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Quotes")
        } footer: {
            Text("Choose which collections appear in the app and in your notifications.")
        }
    }

    // MARK: - Shuffle Section

    private var shuffleSection: some View {
        Section {
            Toggle(isOn: $shuffleDisplayedQuotes) {
                Label("Shuffle Quotes", systemImage: "shuffle")
            }
            .onChange(of: shuffleDisplayedQuotes) { _, newValue in
                HapticFeedback.selection()
                quoteViewModel.reloadBrowseOrder(forceReshuffle: newValue)
            }
            // Hint states the current effect, not just what the setting does.
            .accessibilityHint(
                shuffleDisplayedQuotes
                ? String(localized: "On. Quotes are appearing in a random order. Toggle to group them by collection instead.")
                : String(localized: "Off. Quotes are appearing grouped by collection. Toggle to randomise the order.")
            )
        } footer: {
            // Footer is state-aware: describes what is happening right now.
            if shuffleDisplayedQuotes {
                Text("Quotes are appearing in a random order. Each session brings a different mix.")
            } else {
                Text("Quotes are appearing grouped by collection, in their original order.")
            }
        }
    }

    // MARK: - Language Section

    private var languageSection: some View {
        Section {
            Picker(selection: $appLanguageRaw) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.displayName).tag(language.rawValue)
                }
            } label: {
                Label("Language", systemImage: "globe")
            }
            .accessibilityLabel(String(localized: "Language"))
            .accessibilityHint(String(localized: "Choose the language for quotes and the app interface. Quotes update immediately; menus and buttons update after you restart Inner Whisper."))
            .onChange(of: appLanguageRaw) { _, newValue in
                HapticFeedback.selection()
                let language = AppLanguage(rawValue: newValue) ?? .systemDefault
                language.applyAsInterfaceLanguageOverride()
                Task { await quoteViewModel.refreshQuotes() }
                showingLanguageRestartAlert = true
            }
        } header: {
            Text("Language")
        } footer: {
            Text("Sets the language for quotes, menus, and buttons. Quotes update immediately — restart Inner Whisper to update the rest of the interface.")
        }
    }

    // MARK: - Notifications Section

    private var notificationsSection: some View {
        Section("Notifications") {
            Button {
                HapticFeedback.light()
                showingNotificationSettings = true
            } label: {
                Label(
                    quoteViewModel.notificationsEnabled ? "Notifications On" : "Notifications Off",
                    systemImage: quoteViewModel.notificationsEnabled ? "bell.badge" : "bell.slash"
                )
                .foregroundStyle(.primary)
            }
            .accessibleButton(
                label: quoteViewModel.notificationsEnabled
                    ? String(localized: "Notifications On")
                    : String(localized: "Notifications Off"),
                hint: String(localized: "Configure when and how often you receive inspirational quote notifications")
            )

            Button {
                HapticFeedback.light()
                showingSoundSettings = true
            } label: {
                Label("Notification Sound", systemImage: "speaker.wave.2")
                    .foregroundStyle(.primary)
            }
            .accessibleButton(
                label: String(localized: "Notification Sound"),
                hint: String(localized: "Choose the sound that plays with each quote notification")
            )
        }
    }

    // MARK: - Security Section

    private var securitySection: some View {
        Section("Security") {
            Button {
                HapticFeedback.light()
                showingSecurityWelcome = true
            } label: {
                Label("About Security", systemImage: "lock.shield")
                    .foregroundStyle(.primary)
            }
            .accessibleButton(
                label: String(localized: "About Security"),
                hint: String(localized: "Learn how the app protects your data with AES-256-GCM encryption")
            )

            Button {
                HapticFeedback.light()
                showingEncryptionSettings = true
            } label: {
                Label("Encryption Settings", systemImage: "key")
                    .foregroundStyle(.primary)
            }
            .accessibleButton(
                label: String(localized: "Encryption Settings"),
                hint: String(localized: "View and manage AES-256-GCM encryption settings")
            )
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section("About") {
            Button {
                HapticFeedback.light()
                withAnimation(.easeInOut(duration: 0.38)) { showingAppInfo = true }
            } label: {
                Label("App Info", systemImage: "info.circle")
                    .foregroundStyle(.blue)
                    
            }
            .accessibilityHint(String(localized: "View detailed app information and developer details"))
            
            HStack {
                Text("Version")
                Spacer()
                Text(appVersion)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(localized: "App version \(appVersion)"))

            HStack {
                Text("Build")
                Spacer()
                Text(buildNumber)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(localized: "Build number \(buildNumber)"))

            Button {
                HapticFeedback.light()
                showingOnboarding = true
            } label: {
                Label("App Introduction", systemImage: "sparkles")
                    .foregroundStyle(.primary)
            }
            .accessibleButton(
                label: String(localized: "App Introduction"),
                hint: String(localized: "Replay the onboarding walkthrough to learn about Inner Whisper")
            )

            Button {
                HapticFeedback.light()
                showingDisclaimer = true
            } label: {
                Label("Quote Sources & Attribution", systemImage: "doc.text.magnifyingglass")
                    .foregroundStyle(.primary)
            }
            .accessibleButton(
                label: String(localized: "Quote Sources and Attribution"),
                hint: String(localized: "View information about quote sources and our accuracy disclaimer")
            )

            Button {
                HapticFeedback.light()
                openPrivacyPolicyInBrowser()
            } label: {
                Label("Privacy Policy", systemImage: "hand.raised.fill")
                    .foregroundStyle(.blue)
            }
            .accessibleButton(
                label: String(localized: "Privacy Policy"),
                hint: String(localized: "Opens the Moving Truth privacy policy in Safari")
            )

            Button {
                HapticFeedback.light()
                openReportProblemEmail()
            } label: {
                Label("Report a Problem", systemImage: "envelope")
                    .foregroundStyle(.primary)
            }
            .accessibleButton(
                label: String(localized: "Report a Problem"),
                hint: String(localized: "Opens Mail with a new message addressed to Moving Truth support")
            )
        }
    }

    private func openPrivacyPolicyInBrowser() {
        guard UIApplication.shared.canOpenURL(privacyPolicyURL) else {
            HapticFeedback.error()
            return
        }
        UIApplication.shared.open(privacyPolicyURL)
    }

    private func openReportProblemEmail() {
        guard UIApplication.shared.canOpenURL(reportProblemURL) else {
            HapticFeedback.error()
            return
        }
        UIApplication.shared.open(reportProblemURL)
    }

    // MARK: - Version Information

    /// The app's marketing version (e.g., "1.0.0")
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    /// The app's build number (e.g., "42")
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }


}

// MARK: - Previews

#Preview {
    SettingsView(isPresented: .constant(true))
        .environment(QuoteViewModel())
}
