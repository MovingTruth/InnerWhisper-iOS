//
//  NotificationResponseDelegate.swift
//  InnerWhisper
//
//  Created for InnerWhisper.
//

import Foundation
import UserNotifications

/// UserDefaults key used to pass a quote ID from a notification tap into the app.
/// The QuoteViewModel reads and clears this when handling a pending notification open.
let pendingNotificationQuoteIdKey = "InnerWhisper.PendingNotificationQuoteId"

/// Handles notification center delegate callbacks so that when the user taps a quote
/// notification, we store the quote ID for the QuoteViewModel to open that quote.
final class NotificationResponseDelegate: NSObject, UNUserNotificationCenterDelegate {

    /// When the app is **foregrounded**, the system does not show or play incoming notifications
    /// unless we opt in here. Without this, quote alerts are silenced after the user opens the app,
    /// which looks like “the notification sound only worked once.”
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }

        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else { return }

        let userInfo = response.notification.request.content.userInfo
        guard let quoteId = userInfo["quoteId"] as? String, !quoteId.isEmpty else { return }

        UserDefaults.standard.set(quoteId, forKey: pendingNotificationQuoteIdKey)
    }
}
