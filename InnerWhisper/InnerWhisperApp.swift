//
//  InnerWhisperApp.swift
//  InnerWhisper
//
//  Created by Robin O'Brien on 2026-02-24.
//

import SwiftUI

/// The main entry point for the InnerWhisper application.
///
/// InnerWhisper is a quote of the day application that displays inspirational quotes
/// and allows users to navigate through a collection of wisdom and motivation.
@main
struct InnerWhisperApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    /// Shown on cold launch (first install, after the user force-quits, or after the system terminates the process). Hidden on warm resume from the background so the intro does not run every time the user returns to the app.
    @State private var showLaunchSplash = true

    init() {
        AppSound.migrateRetiredSoundsIfNeeded()
        // Increment the cold-launch counter (used to decide when to prompt for a review).
        let count = UserDefaults.standard.integer(forKey: "InnerWhisper.appLaunchCount") + 1
        UserDefaults.standard.set(count, forKey: "InnerWhisper.appLaunchCount")
    }

    /// The scene configuration for the application.
    ///
    /// Creates a `WindowGroup` containing the main `ContentView` where users
    /// can browse and read inspirational quotes.
    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView(splashIsVisible: showLaunchSplash)
                if showLaunchSplash {
                    SkyLaunchSplashView {
                        showLaunchSplash = false
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
        }
        // Reschedule notifications every time the app comes to the foreground,
        // not just on cold launch. The scheduling window is 2 days, so without
        // this the queue goes empty if the user opens the app from background
        // state more than 48 hours after the last cold start.
        .onChange(of: scenePhase) { oldPhase, newPhase in
            guard newPhase == .active else { return }
            if oldPhase == .background {
                showLaunchSplash = false
            }
            // Pull the latest iCloud favorites every time the app comes to the foreground.
            FavoritesManager.shared.synchronize()
            UserAddedQuotesStore.shared.synchronizeFromCloud()
            Task {
                let settings = NotificationSettings.load()
                if settings.isEnabled {
                    await NotificationManager.shared.apply(settings: settings)
                }
            }
        }
    }
}
