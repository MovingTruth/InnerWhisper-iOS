//
//  NotificationConfigurationView.swift
//  InnerWhisper
//
//  Created for InnerWhisper.
//

import SwiftUI

/// Configuration screen for quote notifications: frequency, interval, and blackout window.
///
/// This view provides a Form-based interface for configuring notification settings
/// including enabling/disabling notifications, choosing schedule types, and setting
/// a "Do Not Disturb" blackout window.
///
/// ## Accessibility Features
/// - Native Form accessibility (labels, values, adjustable traits)
/// - Live announcements for save success
/// - Haptic feedback for user actions
/// - Full VoiceOver support
struct NotificationConfigurationView: View {
    private let notificationManager = NotificationManager.shared
    @State private var isEnabled = false
    @State private var scheduleType: NotificationScheduleType = .timesPerDay
    @State private var timesPerDay: Int = NotificationSettings.defaultTimesPerDay
    @State private var intervalMinutes: Int = NotificationSettings.defaultIntervalMinutes
    @State private var blackoutStart = Self.makeDate(hour: NotificationSettings.defaultBlackoutStart.hour, minute: NotificationSettings.defaultBlackoutStart.minute)
    @State private var blackoutEnd = Self.makeDate(hour: NotificationSettings.defaultBlackoutEnd.hour, minute: NotificationSettings.defaultBlackoutEnd.minute)
    @State private var singleNotificationTime = Self.makeDate(hour: NotificationSettings.defaultSingleNotificationHour, minute: NotificationSettings.defaultSingleNotificationMinute)
    @State private var showingSoundSettings = false
    @State private var isSaving = false
    @State private var saveMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Notifications", isOn: $isEnabled)
                        .onChange(of: isEnabled) {
                            HapticFeedback.selection()
                        }
                        .accessibilityLabel(String(localized: "Enable notifications"))
                        .accessibilityHint(String(localized: "Toggle to enable or disable inspirational quote notifications"))
                } header: {
                    Text("Enable")
                }

                if isEnabled {
                    Section {
                        Picker("Schedule", selection: $scheduleType) {
                            Text("Times per day").tag(NotificationScheduleType.timesPerDay)
                            Text("Interval").tag(NotificationScheduleType.interval)
                        }
                        .pickerStyle(.menu)

                        if scheduleType == .timesPerDay {
                            Picker("Times per day", selection: $timesPerDay) {
                                ForEach(1...20, id: \.self) { n in
                                    Text("\(n)").tag(n)
                                }
                            }
                            .pickerStyle(.menu)

                            if timesPerDay == 1 {
                                DatePicker("Notification time", selection: $singleNotificationTime, displayedComponents: .hourAndMinute)
                                    .accessibilityLabel(String(localized: "Time for daily notification"))
                                    .accessibilityHint(String(localized: "Choose when you want to receive your daily quote"))
                            }
                        } else {
                            Picker("Interval", selection: $intervalMinutes) {
                                Text("Every 5 minutes").tag(5)
                                Text("Every 7 minutes").tag(7)
                                Text("Every 10 minutes").tag(10)
                                Text("Every 15 minutes").tag(15)
                                Text("Every 20 minutes").tag(20)
                                Text("Every 30 minutes").tag(30)
                                Text("Every hour").tag(60)
                            }
                            .pickerStyle(.menu)
                        }
                    } header: {
                        Text("Frequency")
                    } footer: {
                        Text(frequencyFooterText)
                    }

                    Section {
                        DatePicker("Do not disturb from", selection: $blackoutStart, displayedComponents: .hourAndMinute)
                        DatePicker("Do not disturb until", selection: $blackoutEnd, displayedComponents: .hourAndMinute)
                    } header: {
                        Text("Blackout")
                    } footer: {
                        Text("No notifications will be sent during this time (e.g. overnight).")
                    }

                    Section {
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
                    } header: {
                        Text("Sound")
                    } footer: {
                        Text("Choose which sound plays with each quote notification.")
                    }
                }

                if let message = saveMessage {
                    Section {
                        Text(message)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Notification settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticFeedback.light()
                        dismiss()
                    }
                    .accessibleButton(
                        label: String(localized: "Cancel"),
                        hint: String(localized: "Discard changes and close settings")
                    )
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(isSaving)
                    .accessibleButton(
                        label: String(localized: "Save settings"),
                        hint: String(localized: "Save notification configuration and schedule quote notifications")
                    )
                }
            }
            .onAppear { loadSettings() }
            .sheet(isPresented: $showingSoundSettings) {
                SoundSettingsView()
            }
        }
    }

    private func loadSettings() {
        let s = NotificationSettings.load()
        isEnabled = s.isEnabled
        scheduleType = s.scheduleType
        timesPerDay = s.timesPerDay
        intervalMinutes = NotificationSettings.allowedIntervalMinutes.contains(s.intervalMinutes)
            ? s.intervalMinutes
            : NotificationSettings.defaultIntervalMinutes
        blackoutStart = Self.makeDate(hour: s.blackoutStartHour, minute: s.blackoutStartMinute)
        blackoutEnd = Self.makeDate(hour: s.blackoutEndHour, minute: s.blackoutEndMinute)
        if let h = s.singleNotificationHour, let m = s.singleNotificationMinute {
            singleNotificationTime = Self.makeDate(hour: h, minute: m)
        } else {
            singleNotificationTime = Self.makeDate(hour: NotificationSettings.defaultSingleNotificationHour, minute: NotificationSettings.defaultSingleNotificationMinute)
        }
        saveMessage = nil
    }

    @MainActor
    private func save() async {
        isSaving = true
        saveMessage = nil
        defer { isSaving = false }

        // Use Calendar.component(_:from:) rather than dateComponents(_:from:)
        // to avoid optional-chaining on the result — component(_:from:) always
        // returns a concrete Int for standard components on a valid Date.
        let cal = Calendar.current
        // Always persist single-notification time so it's remembered when switching between 1 and multiple.
        let singleH = cal.component(.hour, from: singleNotificationTime)
        let singleM = cal.component(.minute, from: singleNotificationTime)
        // Preserve the sound setting managed by SoundSettingsView.
        let existingSettings = NotificationSettings.load()
        let settings = NotificationSettings(
            isEnabled: isEnabled,
            scheduleType: scheduleType,
            timesPerDay: timesPerDay,
            intervalMinutes: intervalMinutes,
            blackoutStartHour:   cal.component(.hour,   from: blackoutStart),
            blackoutStartMinute: cal.component(.minute, from: blackoutStart),
            blackoutEndHour:     cal.component(.hour,   from: blackoutEnd),
            blackoutEndMinute:   cal.component(.minute, from: blackoutEnd),
            singleNotificationHour: singleH,
            singleNotificationMinute: singleM,
            notificationSoundIdentifier: existingSettings.notificationSoundIdentifier
        )
        settings.save()
        await notificationManager.apply(settings: settings)

        let message = "Settings saved. Notifications will appear on your lock screen."
        saveMessage = message

        // Provide haptic and accessibility feedback.
        // UIAccessibility.post must be called on the main thread; this function is
        // @MainActor so that requirement is satisfied automatically.
        HapticFeedback.success()
        UIAccessibility.post(notification: .announcement, argument: message)

        // Dismiss after save completes so the user sees the success feedback
        // and isSaving is cleared before the view disappears.
        dismiss()
    }

    private static func makeDate(hour: Int, minute: Int) -> Date {
        var c = DateComponents()
        c.hour = hour
        c.minute = minute
        return Calendar.current.date(from: c) ?? Date()
    }

    /// Explains what the current frequency selection means (times per day or interval).
    private var frequencyFooterText: String {
        switch scheduleType {
        case .timesPerDay:
            return timesPerDayFooterText
        case .interval:
            return intervalFooterText
        }
    }

    private var timesPerDayFooterText: String {
        switch timesPerDay {
        case 1:
            return "One quote per day at the time you choose above."
        case 2:
            return "Two quotes per day, spread evenly across your active hours."
        case 3:
            return "Three quotes per day, spread evenly across your active hours."
        case 4:
            return "Four quotes per day, spread evenly across your active hours."
        case 5...20:
            return "\(timesPerDay) quotes per day, spread evenly across your active hours."
        default:
            return "Quotes spread evenly across your active hours (outside quiet time)."
        }
    }

    private var intervalFooterText: String {
        switch intervalMinutes {
        case 5:
            return "A quote every 5 minutes (e.g. 9:00, 9:05, 9:10…) outside blackout."
        case 7:
            return "A quote every 7 minutes (e.g. 9:00, 9:07, 9:14…) outside blackout."
        case 10:
            return "A quote every 10 minutes (e.g. 9:00, 9:10, 9:20…) outside blackout."
        case 15:
            return "A quote every 15 minutes (e.g. 9:00, 9:15, 9:30…) outside blackout."
        case 20:
            return "A quote every 20 minutes (e.g. 9:00, 9:20, 9:40…) outside blackout."
        case 30:
            return "A quote every 30 minutes (e.g. 9:00, 9:30, 10:00…) outside blackout."
        case 60:
            return "A quote every hour on the hour (e.g. 9:00, 10:00, 11:00…) outside blackout."
        default:
            return "Quotes at a fixed interval throughout the day (outside blackout)."
        }
    }
}

#Preview {
    NotificationConfigurationView()
}
