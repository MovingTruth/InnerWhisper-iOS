//
//  OnboardingView.swift
//  InnerWhisper
//
//  First-launch onboarding walkthrough. Introduces the app, explains the
//  notification-driven concept, and lets the user enable + configure
//  notifications before they ever see the main UI.
//

import SwiftUI
import UserNotifications

// MARK: - Onboarding View

/// Multi-page first-launch walkthrough presented as a `fullScreenCover`.
///
/// Pages:
/// 1. Welcome — app identity and purpose
/// 2. How it works — quote delivery concept
/// 3. Notifications — OS permission request + frequency setup (the core feature)
/// 4. All set — confirmation before entering the main UI
struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var currentPage = 0
    @State private var animateContent = false

    // Notification page state
    @State private var permissionStatus: UNAuthorizationStatus = .notDetermined
    @State private var isRequestingPermission = false
    @State private var selectedScheduleType: NotificationScheduleType = .interval
    @State private var selectedIntervalMinutes: Int = 60
    @State private var selectedTimesPerDay: Int = 4

    private let pageCount = 7

    var body: some View {
        ZStack {
            backgroundGradient

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    howItWorksPage.tag(1)
                    notificationsPage.tag(2)
                    lockScreenPage.tag(3)
                    securityPage.tag(4)
                    attributionPage.tag(5)
                    allSetPage.tag(6)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.35), value: currentPage)

                bottomControls
                    .padding(.horizontal, 32)
                    .padding(.bottom, 48)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { animateContent = true }
            Task { await refreshPermissionStatus() }
        }
    }

    // MARK: - Background

    // Moving Truth background: near-black with a faint warm-gold trace
    private var backgroundGradient: some View {
        ZStack {
            Color(red: 0.051, green: 0.051, blue: 0.051)   // #0D0D0D
            LinearGradient(
                colors: [
                    Color(red: 0.79, green: 0.66, blue: 0.30).opacity(0.07),   // gold trace
                    Color.clear,
                    Color(red: 0.79, green: 0.66, blue: 0.30).opacity(0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer(minLength: 60)

                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.79, green: 0.66, blue: 0.30).opacity(0.22),
                                    Color(red: 0.60, green: 0.47, blue: 0.19).opacity(0.14)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 140, height: 140)
                        .scaleEffect(animateContent ? 1.0 : 0.6)
                        .opacity(animateContent ? 1.0 : 0)

                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.79, green: 0.66, blue: 0.30).opacity(0.55),
                                    Color(red: 0.60, green: 0.47, blue: 0.19).opacity(0.35)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 158, height: 158)
                        .scaleEffect(animateContent ? 1.0 : 0.8)
                        .opacity(animateContent ? 1.0 : 0)

                    Image(systemName: "quote.bubble.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.79, green: 0.66, blue: 0.30),
                                    Color(red: 0.60, green: 0.47, blue: 0.19)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(animateContent ? 1.0 : 0.4)
                        .opacity(animateContent ? 1.0 : 0)
                }
                .accessibilityHidden(true)
                .padding(.bottom, 40)

                VStack(spacing: 14) {
                    Text("Welcome to")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .opacity(animateContent ? 1.0 : 0)
                        .offset(y: animateContent ? 0 : 16)

                    Text("Inner Whisper")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .fontDesign(.serif)
                        .opacity(animateContent ? 1.0 : 0)
                        .offset(y: animateContent ? 0 : 16)
                        .animation(.easeOut(duration: 0.6).delay(0.1), value: animateContent)

                    Text("A word, arriving quietly, in its own time.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        .opacity(animateContent ? 1.0 : 0)
                        .offset(y: animateContent ? 0 : 16)
                        .animation(.easeOut(duration: 0.6).delay(0.2), value: animateContent)
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 32)
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Page 2: How it works

    private var howItWorksPage: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer(minLength: 60)

                Image(systemName: "bell.and.waves.left.and.right.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.79, green: 0.66, blue: 0.30),
                                Color(red: 0.60, green: 0.47, blue: 0.19)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .padding(.bottom, 36)
                    .accessibilityHidden(true)

                VStack(spacing: 12) {
                    Text("Words that find their way to you")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text("More than a thousand of them, gathered from the world's deepest thinkers — each one chosen to open a door, never to close one. They arrive quietly, like something remembered rather than announced.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
                .padding(.bottom, 40)

                VStack(spacing: 12) {
                    OnboardingFeatureRow(
                        icon: "lock.iphone",
                        iconColor: Color(red: 0.79, green: 0.66, blue: 0.30),
                        title: String(localized: "Wherever you are"),
                        description: String(localized: "A word finds you the moment you reach for your phone — nothing to open, nothing to search for")
                    )
                    OnboardingFeatureRow(
                        icon: "shuffle",
                        iconColor: Color(red: 0.60, green: 0.47, blue: 0.19),
                        title: String(localized: "Never twice the same"),
                        description: String(localized: "Every voice gets its turn before any one of them returns")
                    )
                    OnboardingFeatureRow(
                        icon: "heart.fill",
                        iconColor: .pink,
                        title: String(localized: "Keep what stays with you"),
                        description: String(localized: "Hold onto the words that resonate, and wander back to them whenever you like")
                    )
                }
                .padding(.horizontal, 4)

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Page 3: Notifications

    private var notificationsPage: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer(minLength: 50)

                // Hero icon
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.2))
                        .frame(width: 130, height: 130)

                    Image(systemName: permissionStatus == .authorized ? "bell.badge.fill" : "bell.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .pink],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .symbolEffect(.bounce, value: permissionStatus)
                }
                .accessibilityHidden(true)
                .padding(.bottom, 28)

                VStack(spacing: 10) {
                    Text("Enable Notifications")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text("A whisper, delivered to your lock screen at the pace that works for you. Quiet. Timely. Yours.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
                .padding(.bottom, 28)

                // Permission state
                notificationPermissionSection
                    .padding(.bottom, 16)

                // Frequency picker — shown once authorized
                if permissionStatus == .authorized {
                    frequencySection
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 32)
            .animation(.easeInOut(duration: 0.4), value: permissionStatus)
        }
    }

    @ViewBuilder
    private var notificationPermissionSection: some View {
        switch permissionStatus {
        case .notDetermined:
            // Primary CTA: request OS permission
            Button {
                Task { await requestPermission() }
            } label: {
                HStack(spacing: 12) {
                    if isRequestingPermission {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "bell.badge.fill")
                            .font(.title3)
                    }
                    Text(isRequestingPermission ? "Enabling…" : "Enable Notifications")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 56)
                .padding(.vertical, 4)
                .background(
                    LinearGradient(
                        colors: [.orange, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .orange.opacity(0.4), radius: 12, y: 6)
            }
            .disabled(isRequestingPermission)
            .accessibilityLabel(String(localized: "Enable notifications"))
            .accessibilityHint(String(localized: "Requests permission to send you inspirational quote notifications"))

        case .authorized, .provisional, .ephemeral:
            // Confirmed state
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Notifications enabled")
                        .font(.headline)
                    Text("Now choose how often you'd like them")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.green.opacity(0.1))
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(localized: "Notifications enabled. Choose how often you want them below."))

        case .denied:
            // Prompt to open Settings
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "bell.slash.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Notifications are off")
                            .font(.headline)
                        Text("You can enable them in iOS Settings")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(.secondarySystemBackground))
                )

                Button {
                    openAppSettings()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.right.square")
                        Text("Open iOS Settings")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color(red: 0.79, green: 0.66, blue: 0.30))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 48)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(red: 0.79, green: 0.66, blue: 0.30).opacity(0.1))
                    )
                }
                .accessibilityHint(String(localized: "Opens the iOS Settings app where you can turn on notifications for this app"))
            }

        @unknown default:
            EmptyView()
        }
    }

    private var frequencySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("How often?")
                .font(.headline)
                .padding(.bottom, 2)

            VStack(spacing: 8) {
                ForEach(FrequencyOption.presets) { option in
                    FrequencyOptionRow(
                        option: option,
                        isSelected: isOptionSelected(option)
                    ) {
                        HapticFeedback.selection()
                        selectedScheduleType = option.scheduleType
                        if option.scheduleType == .interval {
                            selectedIntervalMinutes = option.intervalMinutes
                        } else {
                            selectedTimesPerDay = option.timesPerDay
                        }
                        Task { await saveNotificationSettings() }
                    }
                }
            }

            Text("You can set a custom schedule anytime in Notification Settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func isOptionSelected(_ option: FrequencyOption) -> Bool {
        guard option.scheduleType == selectedScheduleType else { return false }
        return option.scheduleType == .interval
            ? option.intervalMinutes == selectedIntervalMinutes
            : option.timesPerDay == selectedTimesPerDay
    }

    // MARK: - Page 4: Lock Screen & Apple Watch

    private var lockScreenPage: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer(minLength: 50)

                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.22), Color.purple.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 130, height: 130)

                    Image(systemName: "lock.iphone")
                        .font(.system(size: 56))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .accessibilityHidden(true)
                .padding(.bottom, 28)

                VStack(spacing: 10) {
                    Text("Your quotes, everywhere")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text("Quotes arrive without opening the app — on your lock screen and, if you have one, on your wrist.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
                .padding(.bottom, 28)

                VStack(spacing: 12) {
                    OnboardingFeatureRow(
                        icon: "lock.iphone",
                        iconColor: .blue,
                        title: String(localized: "Lock Screen"),
                        description: String(localized: "Quotes appear as banners the moment they arrive. Pick up your phone and one is already waiting.")
                    )
                    OnboardingFeatureRow(
                        icon: "applewatch",
                        iconColor: .purple,
                        title: String(localized: "Apple Watch"),
                        description: String(localized: "Paired with a Watch? Quotes forward to your wrist automatically when your phone is locked. Nothing extra to set up.")
                    )
                    OnboardingFeatureRow(
                        icon: "bell.badge",
                        iconColor: Color(red: 0.79, green: 0.66, blue: 0.30),
                        title: String(localized: "Make sure Lock Screen is on"),
                        description: String(localized: "In iOS Settings → Inner Whisper → Notifications, check that \"Lock Screen\" is enabled. Tap the button below to check now.")
                    )
                }
                .padding(.horizontal, 4)

                Button {
                    openAppSettings()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.right.square")
                        Text("Check Notification Settings")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color(red: 0.79, green: 0.66, blue: 0.30))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 48)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(red: 0.79, green: 0.66, blue: 0.30).opacity(0.1))
                    )
                }
                .padding(.top, 16)
                .padding(.horizontal, 4)
                .accessibilityHint(String(localized: "Opens iOS Settings so you can verify lock screen and Apple Watch notifications are enabled for Inner Whisper"))

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Page 5: Security

    private var securityPage: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer(minLength: 50)

                // Hero icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.green.opacity(0.22), Color.blue.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 130, height: 130)

                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .accessibilityHidden(true)
                .padding(.bottom, 28)

                VStack(spacing: 10) {
                    Text("Your Data is Protected")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text("Your settings and data are encrypted on-device. No accounts, no tracking. Favourites can optionally sync via iCloud.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
                .padding(.bottom, 28)

                VStack(spacing: 10) {
                    SecurityFeatureRow(
                        icon: "key.fill",
                        iconColor: .orange,
                        title: String(localized: "AES-256-GCM Encryption"),
                        description: String(localized: "Your app data is encrypted using the same standard used by governments worldwide")
                    )
                    SecurityFeatureRow(
                        icon: "iphone.and.arrow.forward",
                        iconColor: .blue,
                        title: String(localized: "No Tracking, No Accounts"),
                        description: String(localized: "No account required, no analytics. Favourites sync only via your personal iCloud account.")
                    )
                    SecurityFeatureRow(
                        icon: "lock.icloud.fill",
                        iconColor: .yellow,
                        title: String(localized: "Keys Stay On-Device"),
                        description: String(localized: "Encryption keys are generated locally and never sent to a server")
                    )
                }
                .padding(.horizontal, 4)

                Text("You can review encryption details anytime in Settings.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 20)
                    .padding(.horizontal, 8)

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Page 5: Attribution

    private var attributionPage: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer(minLength: 50)

                // Hero icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.teal.opacity(0.22), Color.indigo.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 130, height: 130)

                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 56))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.teal, .indigo],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .accessibilityHidden(true)
                .padding(.bottom, 28)

                VStack(spacing: 10) {
                    Text("About Our Quotes")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text("Our collection is drawn from public-domain works, historical writings, and widely circulated sources. While we care deeply about accuracy, a few things are worth knowing:")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
                .padding(.bottom, 28)

                VStack(spacing: 12) {
                    OnboardingFeatureRow(
                        icon: "person.fill.questionmark",
                        iconColor: .orange,
                        title: String(localized: "Attribution may not be perfect"),
                        description: String(localized: "Many famous quotes are misattributed or paraphrased — this is common across all quote collections worldwide")
                    )
                    OnboardingFeatureRow(
                        icon: "text.magnifyingglass",
                        iconColor: .teal,
                        title: String(localized: "We strive for accuracy"),
                        description: String(localized: "We review and update the collection — if you spot an error, we welcome corrections via our website")
                    )
                    OnboardingFeatureRow(
                        icon: "sparkles",
                        iconColor: .indigo,
                        title: String(localized: "For inspiration, not citation"),
                        description: String(localized: "This collection is provided for inspirational purposes — please verify quotes independently before citing them")
                    )
                }
                .padding(.horizontal, 4)

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Page 6: All Set

    private var allSetPage: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer(minLength: 60)

                // Animated checkmark
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.green.opacity(0.25), Color.teal.opacity(0.18)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 140, height: 140)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 70))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green, .teal],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .accessibilityHidden(true)
                .padding(.bottom, 36)

                VStack(spacing: 12) {
                    Text("You're all set!")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text(allSetSubtitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
                .padding(.bottom, 40)

                VStack(spacing: 10) {
                    OnboardingFeatureRow(
                        icon: "bell.badge",
                        iconColor: .orange,
                        title: String(localized: "Notification Settings"),
                        description: String(localized: "Tap the bell icon in the toolbar to adjust your quote schedule anytime")
                    )
                    OnboardingFeatureRow(
                        icon: "gearshape",
                        iconColor: .indigo,
                        title: String(localized: "More Options"),
                        description: String(localized: "Favourites, themes, and more are all in the Settings menu")
                    )
                }
                .padding(.horizontal, 4)

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 32)
        }
    }

    private var allSetSubtitle: String {
        if permissionStatus == .authorized {
            let freqDesc: String
            if selectedScheduleType == .interval {
                freqDesc = selectedIntervalMinutes == 60 ? "once an hour" : "every \(selectedIntervalMinutes) minutes"
            } else {
                freqDesc = selectedTimesPerDay == 1 ? "once a day" : "\(selectedTimesPerDay) times a day"
            }
            return "Your first quote is on its way. We'll whisper to you \(freqDesc)."
        } else {
            return "You can enable notifications anytime via the bell icon in the toolbar."
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 20) {
            // Page indicator dots
            HStack(spacing: 7) {
                ForEach(0..<pageCount, id: \.self) { i in
                    Capsule()
                        .fill(i == currentPage ? Color(red: 0.79, green: 0.66, blue: 0.30) : Color.primary.opacity(0.2))
                        .frame(width: i == currentPage ? 22 : 7, height: 7)
                        .animation(.spring(duration: 0.3), value: currentPage)
                }
            }
            .accessibilityHidden(true)

            // Primary CTA button
            Button {
                HapticFeedback.light()
                if currentPage < pageCount - 1 {
                    withAnimation { currentPage += 1 }
                } else {
                    HapticFeedback.success()
                    onComplete()
                }
            } label: {
                Text(currentPage == pageCount - 1 ? "Enter" : "Continue")
                    .font(.headline)
                    .foregroundStyle(Color(red: 0.051, green: 0.051, blue: 0.051))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 56)
                    .padding(.vertical, 4)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.79, green: 0.66, blue: 0.30),
                                Color(red: 0.60, green: 0.47, blue: 0.19)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color(red: 0.79, green: 0.66, blue: 0.30).opacity(0.35), radius: 10, y: 5)
            }
            .accessibilityLabel(currentPage == pageCount - 1 ? String(localized: "Enter") : String(localized: "Continue to next page"))

            // Skip — visible on all pages except the last
            if currentPage < pageCount - 1 {
                Button("Skip") {
                    HapticFeedback.light()
                    onComplete()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityLabel(String(localized: "Skip onboarding"))
                .accessibilityHint(String(localized: "Go directly to the app"))
            }
        }
    }

    // MARK: - Helpers

    private func refreshPermissionStatus() async {
        permissionStatus = await NotificationManager.shared.authorizationStatus()
    }

    private func requestPermission() async {
        isRequestingPermission = true
        let granted = await NotificationManager.shared.requestAuthorization()
        permissionStatus = await NotificationManager.shared.authorizationStatus()
        isRequestingPermission = false

        if granted {
            HapticFeedback.success()
            await saveNotificationSettings()
        }
    }

    private func saveNotificationSettings() async {
        let settings = NotificationSettings(
            isEnabled: true,
            scheduleType: selectedScheduleType,
            timesPerDay: selectedTimesPerDay,
            intervalMinutes: selectedIntervalMinutes
        )
        settings.save()
        await NotificationManager.shared.apply(settings: settings)
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Frequency Option

private struct FrequencyOption: Identifiable {
    var id: String { "\(scheduleType.rawValue)-\(intervalMinutes)-\(timesPerDay)" }
    let scheduleType: NotificationScheduleType
    let timesPerDay: Int
    let intervalMinutes: Int
    let label: String
    let detail: String

    static let presets: [FrequencyOption] = [
        .init(scheduleType: .interval,    timesPerDay: 0, intervalMinutes: 60, label: String(localized: "Every hour"),        detail: String(localized: "A quiet nudge, once an hour")),
        .init(scheduleType: .interval,    timesPerDay: 0, intervalMinutes: 30, label: String(localized: "Every 30 minutes"),  detail: String(localized: "Steady flow throughout your day")),
        .init(scheduleType: .timesPerDay, timesPerDay: 6, intervalMinutes: 0,  label: String(localized: "A few times a day"), detail: String(localized: "Six whispers spread across your day")),
        .init(scheduleType: .timesPerDay, timesPerDay: 1, intervalMinutes: 0,  label: String(localized: "Once a day"),        detail: String(localized: "One gentle daily reminder")),
    ]
}

// MARK: - Frequency Option Row

private struct FrequencyOptionRow: View {
    let option: FrequencyOption
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? .white : .primary)
                    Text(option.detail)
                        .font(.caption)
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white)
                        .font(.title3)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected
                        ? LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [Color(.tertiarySystemBackground), Color(.tertiarySystemBackground)], startPoint: .leading, endPoint: .trailing)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "\(option.label). \(option.detail)."))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Feature Row

/// A compact icon + title + description row used across onboarding pages.
struct OnboardingFeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(iconColor)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "\(title). \(description)"))
    }
}

// MARK: - Previews

#Preview("Onboarding — Light") {
    OnboardingView { print("Complete") }
}

#Preview("Onboarding — Dark") {
    OnboardingView { print("Complete") }
        .preferredColorScheme(.dark)
}

#Preview("Feature Row") {
    VStack(spacing: 10) {
        OnboardingFeatureRow(
            icon: "bell.badge.fill",
            iconColor: .orange,
            title: "Lock screen quotes",
            description: "Get inspired every time you pick up your phone"
        )
        OnboardingFeatureRow(
            icon: "heart.fill",
            iconColor: .pink,
            title: "Save favourites",
            description: "Collect the quotes that resonate with you"
        )
    }
    .padding()
}
