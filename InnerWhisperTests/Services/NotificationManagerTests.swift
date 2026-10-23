//
//  NotificationManagerTests.swift
//  InnerWhisperTests
//
//  Created for InnerWhisper.
//

import XCTest
import UserNotifications
@testable import InnerWhisper

/// Unit tests for NotificationManager.
///
/// These tests verify notification scheduling logic, blackout window handling,
/// and quote rotation. Note that some tests require @MainActor since
/// NotificationManager is isolated to the main actor.
@MainActor
final class NotificationManagerTests: XCTestCase {
    var sut: NotificationManager!

    override func setUp() async throws {
        try await super.setUp()
        sut = NotificationManager.shared
    }

    override func tearDown() async throws {
        // Clean up any scheduled notifications
        sut.cancelAll()
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testShared_ReturnsSameInstance() {
        // Given
        let instance1 = NotificationManager.shared
        let instance2 = NotificationManager.shared

        // Then
        XCTAssertTrue(instance1 === instance2, "shared should return the same instance")
    }

    // MARK: - Settings Application Tests

    func testApply_WithDisabledSettings_CancelsAllNotifications() async {
        // Given
        let settings = NotificationSettings(isEnabled: false)

        // When
        await sut.apply(settings: settings)

        // Then
        let center = UNUserNotificationCenter.current()
        let pendingRequests = await center.pendingNotificationRequests()
        XCTAssertTrue(pendingRequests.isEmpty, "Should have no pending notifications when disabled")
    }

    func testCancelAll_RemovesAllNotifications() async {
        // Avoid presenting an interactive permission alert in unattended CI.
        guard await sut.authorizationStatus() != .notDetermined else {
            sut.cancelAll()
            return
        }

        // Given: Schedule some notifications first
        let settings = NotificationSettings(
            isEnabled: true,
            scheduleType: .timesPerDay,
            timesPerDay: 3
        )
        await sut.apply(settings: settings)

        // When
        sut.cancelAll()

        // Then
        let center = UNUserNotificationCenter.current()
        let pendingRequests = await center.pendingNotificationRequests()
        XCTAssertTrue(pendingRequests.isEmpty, "Should have no pending notifications after cancel")
    }

    // MARK: - Blackout Logic Tests

    func testBlackoutSettings_SavedAndLoadedCorrectly() {
        // Given: Settings with a specific blackout window (10 PM to 7 AM)
        let settings = NotificationSettings(
            isEnabled: true,
            scheduleType: .timesPerDay,
            timesPerDay: 3,
            blackoutStartHour: 22,
            blackoutStartMinute: 0,
            blackoutEndHour: 7,
            blackoutEndMinute: 0
        )

        // When
        settings.save()
        let loaded = NotificationSettings.load()

        // Then: Blackout window values are preserved through save/load
        XCTAssertEqual(loaded.blackoutStartHour, 22, "Blackout start hour should be preserved")
        XCTAssertEqual(loaded.blackoutStartMinute, 0, "Blackout start minute should be preserved")
        XCTAssertEqual(loaded.blackoutEndHour, 7, "Blackout end hour should be preserved")
        XCTAssertEqual(loaded.blackoutEndMinute, 0, "Blackout end minute should be preserved")
    }

    // MARK: - Settings Persistence Tests

    func testNotificationSettings_SaveAndLoad_Roundtrip() {
        // Given
        let originalSettings = NotificationSettings(
            isEnabled: true,
            scheduleType: .interval,
            timesPerDay: 5,
            intervalMinutes: 30,
            blackoutStartHour: 23,
            blackoutStartMinute: 30,
            blackoutEndHour: 6,
            blackoutEndMinute: 45
        )

        // When
        originalSettings.save()
        let loadedSettings = NotificationSettings.load()

        // Then
        XCTAssertEqual(loadedSettings, originalSettings, "Loaded settings should match saved settings")
    }

    func testNotificationSettings_Validation_ClampsValues() {
        // Given/When: Create settings with out-of-range values
        let settings = NotificationSettings(
            isEnabled: true,
            scheduleType: .timesPerDay,
            timesPerDay: 100, // Should be clamped to 20
            intervalMinutes: 45, // Should be clamped to 60 (invalid value)
            blackoutStartHour: 30, // Should be clamped to 23
            blackoutStartMinute: 70, // Should be clamped to 59
            blackoutEndHour: -5, // Should be clamped to 0
            blackoutEndMinute: -10 // Should be clamped to 0
        )

        // Then
        XCTAssertEqual(settings.timesPerDay, 20, "Times per day should be clamped to max 20")
        XCTAssertEqual(settings.intervalMinutes, 60, "Invalid interval should default to 60")
        XCTAssertEqual(settings.blackoutStartHour, 23, "Hour should be clamped to 0-23 range")
        XCTAssertEqual(settings.blackoutStartMinute, 59, "Minute should be clamped to 0-59 range")
        XCTAssertEqual(settings.blackoutEndHour, 0, "Negative hour should be clamped to 0")
        XCTAssertEqual(settings.blackoutEndMinute, 0, "Negative minute should be clamped to 0")
    }

    func testNotificationSettings_IntervalMinutes_ValidatesOptions() {
        // Test valid values (allowed: 5, 7, 10, 15, 20, 30, 60)
        for minutes in [5, 7, 10, 15, 20, 30, 60] {
            let settings = NotificationSettings(intervalMinutes: minutes)
            XCTAssertEqual(settings.intervalMinutes, minutes, "\(minutes) min should be accepted")
        }

        // Test invalid value (not in allowed list → default to 60)
        let settingsInvalid = NotificationSettings(intervalMinutes: 45)
        XCTAssertEqual(settingsInvalid.intervalMinutes, 60, "Invalid interval should default to 60")
    }

    // MARK: - Schedule Type Tests

    func testNotificationScheduleType_Codable_Roundtrip() throws {
        // Given
        let timesPerDay = NotificationScheduleType.timesPerDay
        let interval = NotificationScheduleType.interval

        // When
        let encodedTimesPerDay = try JSONEncoder().encode(timesPerDay)
        let encodedInterval = try JSONEncoder().encode(interval)

        let decodedTimesPerDay = try JSONDecoder().decode(NotificationScheduleType.self, from: encodedTimesPerDay)
        let decodedInterval = try JSONDecoder().decode(NotificationScheduleType.self, from: encodedInterval)

        // Then
        XCTAssertEqual(decodedTimesPerDay, .timesPerDay)
        XCTAssertEqual(decodedInterval, .interval)
    }

    func testNotificationScheduleType_CaseIterable_ContainsAllCases() {
        // Given/When
        let allCases = NotificationScheduleType.allCases

        // Then
        XCTAssertEqual(allCases.count, 2, "Should have exactly 2 schedule types")
        XCTAssertTrue(allCases.contains(.timesPerDay))
        XCTAssertTrue(allCases.contains(.interval))
    }

    // MARK: - Integration Tests (Require Permissions)

    func testApply_WithEnabledSettings_DoesNotThrow() async {
        // CI cannot interact with the system permission alert. Exercise this
        // integration path only after the simulator has an explicit decision.
        guard await sut.authorizationStatus() != .notDetermined else {
            return
        }

        // Given
        let settings = NotificationSettings(
            isEnabled: true,
            scheduleType: .timesPerDay,
            timesPerDay: 2
        )

        // When/Then: Applying enabled settings should not crash, regardless of
        // authorization state (not determined / denied / authorized all handled internally)
        await sut.apply(settings: settings)

        // Verify the manager is still functional after applying settings
        let status = await sut.authorizationStatus()
        let validStatuses: [UNAuthorizationStatus] = [.authorized, .notDetermined, .denied, .provisional, .ephemeral]
        XCTAssertTrue(validStatuses.contains(status), "Should return a recognized authorization status")
    }

    // MARK: - Edge Case Tests

    func testNotificationSettings_DefaultValues_AreValid() {
        // Given/When
        let settings = NotificationSettings()

        // Then
        XCTAssertFalse(settings.isEnabled, "Should be disabled by default")
        XCTAssertEqual(settings.scheduleType, .interval)
        XCTAssertEqual(settings.timesPerDay, 4)
        XCTAssertEqual(settings.intervalMinutes, 60)
        XCTAssertEqual(settings.blackoutStartHour, 22)
        XCTAssertEqual(settings.blackoutStartMinute, 0)
        XCTAssertEqual(settings.blackoutEndHour, 7)
        XCTAssertEqual(settings.blackoutEndMinute, 0)
    }

    func testMakeTriggerDates_OnceDaily_FillsPendingRequestCapacity() throws {
        // Given: Today's chosen time has already passed.
        let calendar = utcCalendar
        let now = try XCTUnwrap(date(year: 2026, month: 10, day: 5, hour: 12, calendar: calendar))
        let settings = NotificationSettings(
            isEnabled: true,
            scheduleType: .timesPerDay,
            timesPerDay: 1,
            singleNotificationHour: 9,
            singleNotificationMinute: 0
        )

        // When
        let dates = NotificationManager.makeTriggerDates(
            settings: settings,
            now: now,
            calendar: calendar
        )

        // Then: one notification per day spans 64 future days, surviving long periods
        // without an app launch instead of ending after tomorrow.
        XCTAssertEqual(dates.count, 64)
        let firstDate = try XCTUnwrap(dates.first)
        let lastDate = try XCTUnwrap(dates.last)
        let sixtyDaysLater = try XCTUnwrap(calendar.date(byAdding: .day, value: 60, to: now))
        XCTAssertEqual(calendar.dateComponents([.day], from: firstDate, to: lastDate).day, 63)
        XCTAssertGreaterThan(lastDate, sixtyDaysLater)
    }

    func testMakeTriggerDates_Hourly_ExtendsBeyondTwoCalendarDays() throws {
        // Given: hourly notifications with the default overnight blackout.
        let calendar = utcCalendar
        let now = try XCTUnwrap(date(year: 2026, month: 10, day: 5, hour: 12, calendar: calendar))
        let settings = NotificationSettings(
            isEnabled: true,
            scheduleType: .interval,
            intervalMinutes: 60,
            blackoutStartHour: 22,
            blackoutStartMinute: 0,
            blackoutEndHour: 7,
            blackoutEndMinute: 0
        )

        // When
        let dates = NotificationManager.makeTriggerDates(
            settings: settings,
            now: now,
            calendar: calendar
        )

        // Then
        XCTAssertEqual(dates.count, 64)
        let lastDate = try XCTUnwrap(dates.last)
        let twoDaysLater = try XCTUnwrap(calendar.date(byAdding: .day, value: 2, to: now))
        XCTAssertGreaterThan(lastDate, twoDaysLater)
        XCTAssertTrue(dates.allSatisfy { date in
            let hour = calendar.component(.hour, from: date)
            return hour >= 7 && hour < 22
        })
    }

    func testNotificationSettings_Equatable_Works() {
        // Given
        let settings1 = NotificationSettings(isEnabled: true, timesPerDay: 5)
        let settings2 = NotificationSettings(isEnabled: true, timesPerDay: 5)
        let settings3 = NotificationSettings(isEnabled: false, timesPerDay: 5)

        // Then
        XCTAssertEqual(settings1, settings2, "Identical settings should be equal")
        XCTAssertNotEqual(settings1, settings3, "Different settings should not be equal")
    }

    // MARK: - Test Helpers

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        calendar: Calendar
    ) -> Date? {
        calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour
        ))
    }
}
