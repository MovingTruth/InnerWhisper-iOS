//
//  NotificationSettings.swift
//  InnerWhisper
//
//  Created for InnerWhisper.
//

import Foundation

/// Defines how often quote notifications are sent.
enum NotificationScheduleType: String, Codable, CaseIterable {
    /// A fixed number of times per day (1–20).
    case timesPerDay
    /// A fixed interval in minutes (see `NotificationSettings.allowedIntervalMinutes`).
    case interval
}

/// User-configurable settings for quote notifications.
///
/// Persisted in UserDefaults. Used by `NotificationManager` to schedule
/// local notifications with blackout and frequency rules.
struct NotificationSettings: Codable, Equatable {
    /// Whether notifications are enabled.
    var isEnabled: Bool

    /// How schedule is defined: by times per day or by interval.
    var scheduleType: NotificationScheduleType

    /// Number of notifications per day (1–20). Used when `scheduleType == .timesPerDay`.
    var timesPerDay: Int

    /// Interval in minutes (5, 7, 10, 15, 20, 30, or 60). Used when `scheduleType == .interval`.
    var intervalMinutes: Int

    /// Blackout start: hour (0–23) and minute (0–59). No notifications in this window.
    var blackoutStartHour: Int
    var blackoutStartMinute: Int

    /// Blackout end: hour (0–23) and minute (0–59). Window may span midnight.
    var blackoutEndHour: Int
    var blackoutEndMinute: Int

    /// When `timesPerDay == 1`, the exact time for the daily notification (hour 0–23, minute 0–59).
    /// `nil` means use legacy behavior (just after blackout end). Stored for backward compatibility.
    var singleNotificationHour: Int?
    var singleNotificationMinute: Int?

    /// Override for notification sound. `nil` = use theme default; `"default"` = system default; otherwise a bundle filename (e.g. `"chime.caf"`).
    var notificationSoundIdentifier: String?

    // MARK: - Defaults

    /// Allowed interval values in minutes. Invalid values are stored as 60.
    static let allowedIntervalMinutes = [5, 7, 10, 15, 20, 30, 60]

    static let defaultTimesPerDay = 4
    static let defaultIntervalMinutes = 60
    static let defaultBlackoutStart = (hour: 22, minute: 0)   // 10:00 PM
    static let defaultBlackoutEnd = (hour: 7, minute: 0)      // 7:00 AM
    static let defaultSingleNotificationHour = 9
    static let defaultSingleNotificationMinute = 0

    init(
        isEnabled: Bool = false,
        scheduleType: NotificationScheduleType = .interval,
        timesPerDay: Int = Self.defaultTimesPerDay,
        intervalMinutes: Int = Self.defaultIntervalMinutes,
        blackoutStartHour: Int = Self.defaultBlackoutStart.hour,
        blackoutStartMinute: Int = Self.defaultBlackoutStart.minute,
        blackoutEndHour: Int = Self.defaultBlackoutEnd.hour,
        blackoutEndMinute: Int = Self.defaultBlackoutEnd.minute,
        singleNotificationHour: Int? = nil,
        singleNotificationMinute: Int? = nil,
        notificationSoundIdentifier: String? = nil
    ) {
        self.isEnabled = isEnabled
        self.scheduleType = scheduleType
        self.timesPerDay = min(20, max(1, timesPerDay))
        self.intervalMinutes = Self.allowedIntervalMinutes.contains(intervalMinutes) ? intervalMinutes : 60
        self.blackoutStartHour = min(23, max(0, blackoutStartHour))
        self.blackoutStartMinute = min(59, max(0, blackoutStartMinute))
        self.blackoutEndHour = min(23, max(0, blackoutEndHour))
        self.blackoutEndMinute = min(59, max(0, blackoutEndMinute))
        self.singleNotificationHour = singleNotificationHour.map { min(23, max(0, $0)) }
        self.singleNotificationMinute = singleNotificationMinute.map { min(59, max(0, $0)) }
        self.notificationSoundIdentifier = notificationSoundIdentifier
    }
}

// MARK: - Persistence

private let notificationSettingsKey = "InnerWhisper.NotificationSettings"

extension NotificationSettings {
    /// Loads saved settings from UserDefaults, or returns defaults if none are stored.
    static func load() -> NotificationSettings {
        guard let data = UserDefaults.standard.data(forKey: notificationSettingsKey) else {
            return NotificationSettings()
        }
        do {
            return try JSONDecoder().decode(NotificationSettings.self, from: data)
        } catch {
            #if DEBUG
            print("NotificationSettings: Failed to decode saved settings — \(error). Falling back to defaults.")
            #endif
            return NotificationSettings()
        }
    }

    /// Saves the receiver to UserDefaults.
    func save() {
        do {
            let data = try JSONEncoder().encode(self)
            UserDefaults.standard.set(data, forKey: notificationSettingsKey)
        } catch {
            #if DEBUG
            print("NotificationSettings: Failed to encode settings — \(error)")
            #endif
        }
    }
}
