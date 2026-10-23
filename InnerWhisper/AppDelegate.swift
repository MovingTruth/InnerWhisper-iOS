//
//  AppDelegate.swift
//  InnerWhisper
//
//  Created for InnerWhisper.
//

import UIKit
import UserNotifications

/// App delegate used to set the notification center delegate at launch
/// so that tapping a quote notification can open the app on that quote.
final class AppDelegate: NSObject, UIApplicationDelegate {

    private let notificationResponseDelegate = NotificationResponseDelegate()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = notificationResponseDelegate
        return true
    }
}
