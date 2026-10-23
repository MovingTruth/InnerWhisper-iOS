//
//  UserQuoteBrowseModeSection.swift
//  InnerWhisper
//
//  Shared "My quotes only" toggle for the add/edit sheet and Quote Management.
//

import SwiftUI

/// Toggle that limits the main quote browser (and matching notifications) to
/// user-added quotes only when enabled.
///
/// The footer description changes based on the toggle state so the user always
/// knows exactly what is happening right now, not just what the setting does in theory.
struct UserQuoteBrowseModeSection: View {

    /// Use `.quoteManagement` when this section sits above collection toggles
    /// so the footer can reference them. Use `.addQuoteSheet` elsewhere.
    enum Placement {
        case addQuoteSheet
        case quoteManagement
    }

    var placement: Placement = .addQuoteSheet

    @AppStorage(UserQuoteBrowseSettings.browseUserQuotesOnlyKey) private var browseUserQuotesOnly = false

    var body: some View {
        Section {
            Toggle("Show my quotes only", isOn: $browseUserQuotesOnly)
                // Accessibility hint states the current effect clearly in both states.
                .accessibilityHint(
                    browseUserQuotesOnly
                    ? String(localized: "On. The home screen and notifications are showing only quotes you added yourself. Toggle to switch back to all collections.")
                    : String(localized: "Off. The home screen and notifications are showing quotes from all your enabled collections. Toggle to show only your own quotes.")
                )
        } header: {
            Text("Browse Mode")
        } footer: {
            // Footer is state-aware: tells the user what is happening NOW, not just what the setting does.
            if browseUserQuotesOnly {
                Text("Only quotes you've added yourself are showing on the home screen and in notifications. To add quotes, go to Quote Collections → User Added.")
            } else {
                switch placement {
                case .addQuoteSheet:
                    Text("Showing quotes from all your enabled collections, including any you've added yourself.")
                case .quoteManagement:
                    Text("Showing quotes from all the collections you've enabled below, including any you've added yourself.")
                }
            }
        }
        .onChange(of: browseUserQuotesOnly) { _, _ in
            NotificationCenter.default.post(name: .userQuoteBrowseModeDidChange, object: nil)
        }
    }
}
