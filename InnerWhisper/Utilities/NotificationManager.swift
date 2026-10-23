//
//  NotificationManager.swift
//  InnerWhisper
//
//  Created for InnerWhisper.
//

import Foundation
import UserNotifications

/// Schedules and cancels local quote notifications, respecting frequency and blackout settings.
///
/// Uses a `QuoteProvider` (defaults to `AggregatingQuoteProvider.shared`) for quote content.
/// The scheduled pool matches the main app: category filters from `QuoteCategoryManager`, then
/// — when “My quotes only” is enabled — only user-added quotes, same as the home screen.
/// Persists the next-quote cycle so each notification shows a quote not yet used in the current cycle.
@MainActor
final class NotificationManager {
    static let shared = NotificationManager()

    private let quoteProvider: any QuoteProvider
    private let center = UNUserNotificationCenter.current()

    /// Chains overlapping `apply` calls so concurrent triggers (foreground + settings) run serially, not in parallel.
    private var applySerialTask: Task<Void, Never>?

    /// Ordered list of quote IDs for the current notification cycle. Ensures every quote (including new ones) is shown once before any repeat.
    private static let cycleQuoteIdsKey = "InnerWhisper.NotificationCycleQuoteIds"
    /// Index into cycleQuoteIds for the next quote to show.
    private static let cycleIndexKey = "InnerWhisper.NotificationCycleIndex"
    /// Set when we've cycled through all quotes. Used for reshuffle and optional UI.
    private static let lastCycleCompletedAtKey = "InnerWhisper.LastQuoteCycleCompletedAt"

    // MARK: - Scheduling Constants

    private enum Limits {
        /// Maximum notifications per day when using the "times per day" schedule type.
        static let maxTimesPerDay = 20
        /// iOS hard cap on pending notification requests.
        static let iOSNotificationLimit = 64
        /// Maximum calendar days to inspect while filling the pending-request queue.
        /// One extra day is required when today's only eligible time has already passed.
        static let maxSchedulingSearchDays = iOSNotificationLimit + 1
        /// Minutes in one full day.
        static let minutesPerDay = 24 * 60
    }

    init(quoteProvider: (any QuoteProvider)? = nil) {
        self.quoteProvider = quoteProvider ?? AggregatingQuoteProvider.shared
    }

    // MARK: - Permission

    /// Requests notification authorization. Call before scheduling.
    /// - Returns: `true` if authorized, `false` if denied or an error occurred.
    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            #if DEBUG
            print("NotificationManager: requestAuthorization failed — \(error)")
            #endif
            return false
        }
    }

    /// Returns the current authorization status without prompting.
    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    // MARK: - Schedule / Cancel

    /// Date when we last completed a full cycle through all quotes (next index wrapped to 0). `nil` if never.
    static var lastQuoteCycleCompletedAt: Date? {
        UserDefaults.standard.object(forKey: lastCycleCompletedAtKey) as? Date
    }

    /// Cancels all pending notifications.
    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }

    /// Rebuilds the notification schedule from the given settings.
    /// Call after the user saves configuration. Requests permission if needed.
    /// Overlapping calls are serialized so multiple foreground paths do not schedule concurrently.
    func apply(settings: NotificationSettings) async {
        let previous = applySerialTask
        let task = Task { [previous] in
            await previous?.value
            await self.performApply(settings: settings)
        }
        applySerialTask = task
        await task.value
    }

    private func performApply(settings: NotificationSettings) async {
        #if DEBUG
        print("[NotificationManager] apply() called — enabled: \(settings.isEnabled), schedule: \(settings.scheduleType)")
        #endif
        cancelAll()
        guard settings.isEnabled else {
            #if DEBUG
            print("[NotificationManager] Notifications disabled — all pending notifications cancelled")
            #endif
            return
        }

        // Only prompt for authorization if the status is undetermined.
        // If already authorized or denied, use the existing status directly
        // to avoid an unnecessary async round-trip on every foreground event.
        let currentStatus = await authorizationStatus()
        #if DEBUG
        print("[NotificationManager] Authorization status: \(currentStatus.rawValue)")
        #endif
        let granted: Bool
        if currentStatus == .notDetermined {
            granted = await requestAuthorization()
            #if DEBUG
            print("[NotificationManager] Authorization requested — granted: \(granted)")
            #endif
        } else {
            granted = currentStatus == .authorized
        }
        guard granted else {
            #if DEBUG
            print("[NotificationManager] Not authorized — skipping scheduling")
            #endif
            return
        }

        let triggers = Self.makeTriggerDates(settings: settings)
        #if DEBUG
        print("[NotificationManager] Generated \(triggers.count) trigger date(s)")
        #endif

        // Ensure quotes are available; the aggregator may not have loaded yet
        // if this is called before QuoteView's .task has had a chance to run.
        if quoteProvider.quoteCount() == 0 {
            #if DEBUG
            print("[NotificationManager] Quote provider is empty — loading quotes now...")
            #endif
            try? await quoteProvider.loadQuotes()
        }

        let categoryFiltered = quoteProvider.getAllQuotes()
        let notificationQuotes = UserQuoteBrowseSettings.filterQuotesMatchingMainBrowser(categoryFiltered)
        let quoteCount = notificationQuotes.count
        #if DEBUG
        print("[NotificationManager] Quote pool size (category + browse filter): \(quoteCount)")
        #endif
        guard quoteCount > 0 else {
            #if DEBUG
            print("[NotificationManager] No quotes available for current display/notification mode — skipping scheduling")
            #endif
            return
        }

        let currentIds = Set(notificationQuotes.map(\.id))

        // Load or build ID-based cycle so we show every quote once (including new ones) before any repeat.
        var cycleQuoteIds = UserDefaults.standard.stringArray(forKey: Self.cycleQuoteIdsKey) ?? []
        var cycleIndex = UserDefaults.standard.object(forKey: Self.cycleIndexKey) as? Int ?? 0
        let cycleIdSet = Set(cycleQuoteIds)

        if cycleQuoteIds.isEmpty || cycleIdSet != currentIds {
            // List changed (new or removed quotes) or first run: build new cycle. Show unshown (including new) first, then previously shown.
            let shownIds = cycleIndex > 0 ? Set(cycleQuoteIds.prefix(cycleIndex)) : []
            let unshownIds = currentIds.subtracting(shownIds)
            let unshownArray = Array(unshownIds).shuffled()
            let shownArray = Array(shownIds).shuffled()
            cycleQuoteIds = unshownArray + shownArray
            cycleIndex = 0
            #if DEBUG
            print("[NotificationManager] New cycle: \(cycleQuoteIds.count) quotes (\(unshownArray.count) unshown first)")
            #endif
        } else if cycleIndex >= cycleQuoteIds.count {
            // Completed a full cycle (same list): start next cycle with a fresh shuffle.
            cycleQuoteIds = Array(currentIds).shuffled()
            cycleIndex = 0
            #if DEBUG
            print("[NotificationManager] Cycle complete — starting new shuffled cycle")
            #endif
        }

        let effectiveSoundIdentifier = Self.effectiveSoundIdentifier(settings: settings)

        var scheduledCount = 0
        for triggerDate in triggers {
            if cycleIndex >= cycleQuoteIds.count {
                // Keep filling the system queue even when the selected quote pool is
                // smaller than 64. A new shuffle preserves the "all before repeat"
                // guarantee within each cycle.
                UserDefaults.standard.set(Date(), forKey: Self.lastCycleCompletedAtKey)
                cycleQuoteIds = Array(currentIds).shuffled()
                cycleIndex = 0
                if let aggregator = quoteProvider as? AggregatingQuoteProvider {
                    aggregator.reshuffleQuotesForNextCycle()
                }
            }

            // Advance through the cycle until we find a quote that still exists in the provider.
            var quote: Quote?
            while cycleIndex < cycleQuoteIds.count {
                let quoteId = cycleQuoteIds[cycleIndex]
                cycleIndex += 1
                if let candidate = notificationQuotes.first(where: { $0.id == quoteId }) {
                    quote = candidate
                    break
                }
            }
            guard let quote else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Inner Whisper"
            content.body = Self.notificationBody(for: quote)
            content.sound = Self.unNotificationSound(for: effectiveSoundIdentifier)
            content.userInfo = ["quoteId": quote.id]

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: triggerDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            let request = UNNotificationRequest(
                identifier: "InnerWhisper.quote.\(UUID().uuidString)",
                content: content,
                trigger: trigger
            )

            do {
                try await center.add(request)
                scheduledCount += 1
            } catch {
                #if DEBUG
                print("[NotificationManager] Failed to schedule notification for \(triggerDate) — \(error)")
                #endif
            }
        }

        UserDefaults.standard.set(cycleQuoteIds, forKey: Self.cycleQuoteIdsKey)
        UserDefaults.standard.set(cycleIndex, forKey: Self.cycleIndexKey)

        // Completed a full cycle: all quotes shown once. Reshuffle for next cycle and track it.
        if cycleIndex >= cycleQuoteIds.count && scheduledCount > 0 {
            UserDefaults.standard.set(Date(), forKey: Self.lastCycleCompletedAtKey)
            if let aggregator = quoteProvider as? AggregatingQuoteProvider {
                aggregator.reshuffleQuotesForNextCycle()
            }
            // Next apply() will see cycleIndex >= count and build a fresh cycle from the reshuffled list.
        }

        #if DEBUG
        print("[NotificationManager] Scheduled \(scheduledCount)/\(triggers.count) notifications, next cycle index: \(cycleIndex)/\(cycleQuoteIds.count)")
        let pendingRequests = await center.pendingNotificationRequests()
        let finalTriggerDate = pendingRequests.compactMap {
            ($0.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()
        }.max()
        print("[NotificationManager] Pending queue: \(pendingRequests.count), final trigger: \(String(describing: finalTriggerDate))")
        #endif
    }

    // MARK: - Sound

    /// Effective sound identifier: per-notification override if set, otherwise the globally selected sound.
    private static func effectiveSoundIdentifier(settings: NotificationSettings) -> String {
        if let override = settings.notificationSoundIdentifier {
            return override
        }
        let raw = UserDefaults.standard.string(forKey: "InnerWhisper.SelectedSound")
            ?? AppSound.default.rawValue
        return AppSound(rawValue: raw)?.soundIdentifier ?? AppSound.default.rawValue
    }

    /// Maps a sound identifier to `UNNotificationSound`. "default" or empty → system default; else custom named sound.
    private static func unNotificationSound(for identifier: String) -> UNNotificationSound {
        let id = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        if id.isEmpty || id == "default" {
            return .default
        }
        return UNNotificationSound(named: UNNotificationSoundName(rawValue: id))
    }

    // MARK: - Content formatting

    /// Formats the notification body for a given quote.
    /// Extracted so the format can be adjusted or tested independently.
    private static func notificationBody(for quote: Quote) -> String {
        "\(quote.text)\n— \(quote.author)"
    }

    // MARK: - Trigger date computation

    /// Builds the next available trigger dates, respecting blackout hours.
    ///
    /// The result fills iOS's pending-request capacity instead of stopping after two
    /// calendar days. This keeps notifications available across restarts and longer
    /// periods where the user does not reopen the app.
    ///
    /// - Parameters:
    ///   - settings: The user's notification frequency and blackout configuration.
    ///   - now: The scheduling reference time. Injectable for deterministic tests.
    ///   - calendar: The calendar used to construct delivery times. Injectable for tests.
    /// - Returns: Up to 64 chronological dates after `now`.
    static func makeTriggerDates(
        settings: NotificationSettings,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [Date] {
        let startOfToday = calendar.startOfDay(for: now)
        var candidates: [Date] = []

        switch settings.scheduleType {
        case .timesPerDay:
            let count = min(Limits.maxTimesPerDay, max(1, settings.timesPerDay))

            if count == 1, let hour = settings.singleNotificationHour, let minute = settings.singleNotificationMinute {
                // Single notification at user-chosen time (ignores blackout).
                for dayOffset in 0..<Limits.maxSchedulingSearchDays {
                    guard let dayStart = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday) else { continue }
                    guard let date = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: dayStart) else { continue }
                    if date > now {
                        candidates.append(date)
                    }
                }
            } else {
                // Distribute slots evenly within the active (non-blackout) window.
                //
                // Starting from midnight (minute 0) caused all slots to land at
                // midnight-aligned times, which fall inside the default 22:00–07:00
                // blackout window and get filtered — leaving the user with zero
                // notifications. Instead, start the distribution from the moment
                // the blackout ends and space slots across the remaining active hours.
                //
                // Active window calculation:
                //   • Blackout spans midnight (endMin < startMin, e.g. 22:00–07:00):
                //     active = startMin − endMin  (e.g. 1320 − 420 = 900 min)
                //   • Blackout is within a single day (endMin ≥ startMin, e.g. 09:00–17:00):
                //     active = 1440 − (endMin − startMin)
                //   • No effective blackout (startMin == endMin):
                //     active = 1440 (full day)
                let blackoutStartMin = settings.blackoutStartHour * 60 + settings.blackoutStartMinute
                let blackoutEndMin   = settings.blackoutEndHour   * 60 + settings.blackoutEndMinute
                let activeWindowMinutes: Int
                if blackoutStartMin == blackoutEndMin {
                    activeWindowMinutes = Limits.minutesPerDay
                } else if blackoutEndMin < blackoutStartMin {
                    // Midnight-spanning blackout (e.g. 22:00–07:00)
                    activeWindowMinutes = blackoutStartMin - blackoutEndMin
                } else {
                    // Daytime blackout (e.g. 09:00–17:00)
                    activeWindowMinutes = Limits.minutesPerDay - (blackoutEndMin - blackoutStartMin)
                }
                let step = max(1, activeWindowMinutes / count)
                for dayOffset in 0..<Limits.maxSchedulingSearchDays {
                    guard let dayStart = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday) else { continue }
                    for i in 0..<count {
                        // Offset from midnight: start at blackout-end, then add each step.
                        let minutesFromMidnight = (blackoutEndMin + i * step) % Limits.minutesPerDay
                        guard let date = calendar.date(byAdding: .minute, value: minutesFromMidnight, to: dayStart) else { continue }
                        if date > now && !isInBlackout(date, settings: settings, calendar: calendar) {
                            candidates.append(date)
                        }
                    }
                }
            }

        case .interval:
            let step = settings.intervalMinutes
            for dayOffset in 0..<Limits.maxSchedulingSearchDays {
                guard let dayStart = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday) else { continue }
                var minutesFromMidnight = 0
                while minutesFromMidnight < Limits.minutesPerDay {
                    guard let date = calendar.date(byAdding: .minute, value: minutesFromMidnight, to: dayStart) else { break }
                    if date > now && !isInBlackout(date, settings: settings, calendar: calendar) {
                        candidates.append(date)
                    }
                    minutesFromMidnight += step
                }
            }
        }

        candidates.sort()
        return Array(candidates.prefix(Limits.iOSNotificationLimit))
    }

    private static func isInBlackout(
        _ date: Date,
        settings: NotificationSettings,
        calendar: Calendar
    ) -> Bool {
        let hour   = calendar.component(.hour,   from: date)
        let minute = calendar.component(.minute, from: date)
        let minutesSinceMidnight = hour * 60 + minute
        let startMin = settings.blackoutStartHour * 60 + settings.blackoutStartMinute
        let endMin   = settings.blackoutEndHour   * 60 + settings.blackoutEndMinute

        if startMin <= endMin {
            return minutesSinceMidnight >= startMin && minutesSinceMidnight < endMin
        }
        // Blackout spans midnight (e.g. 22:00–07:00)
        return minutesSinceMidnight >= startMin || minutesSinceMidnight < endMin
    }
}
