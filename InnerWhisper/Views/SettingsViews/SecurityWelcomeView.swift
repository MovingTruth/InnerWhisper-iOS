//
//  SecurityWelcomeView.swift
//  InnerWhisper
//
//  First-launch security welcome screen shown before the main UI.
//

import SwiftUI

// MARK: - Security Welcome View

/// A visually appealing security welcome screen shown on first launch
struct SecurityWelcomeView: View {
    let onDismiss: () -> Void

    @State private var animateShield = false
    @State private var animateFeatures = false
    @State private var animateButton = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                securityHeader
                    .padding(.top, 60)
                    .padding(.bottom, 40)

                securityFeatures
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)

                footerNote
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)

                continueButton
                    .padding(.horizontal, 32)
                    .padding(.bottom, 50)
            }
        }
        .background(backgroundGradient)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animateShield = true
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
                animateFeatures = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.6)) {
                animateButton = true
            }
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        ZStack {
            Color(.systemBackground)

            LinearGradient(
                colors: [
                    Color.green.opacity(colorScheme == .dark ? 0.15 : 0.08),
                    Color.clear,
                    Color.blue.opacity(colorScheme == .dark ? 0.1 : 0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Header

    private var securityHeader: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.green.opacity(0.6), .blue.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 140, height: 140)
                    .scaleEffect(animateShield ? 1.0 : 0.8)
                    .opacity(animateShield ? 1.0 : 0)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.green.opacity(0.2),
                                Color.blue.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .scaleEffect(animateShield ? 1.0 : 0.5)

                Image(systemName: "lock.shield.fill")
                    .font(.largeTitle)
                    .imageScale(.large)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(animateShield ? 1.0 : 0.3)
                    .opacity(animateShield ? 1.0 : 0)
            }
            .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("Your Data is Protected")
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("AES-256-GCM encryption enabled")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .opacity(animateShield ? 1.0 : 0)
            .offset(y: animateShield ? 0 : 20)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Your data is protected with AES-256-GCM encryption"))
    }

    // MARK: - Features

    private var securityFeatures: some View {
        VStack(spacing: 16) {
            SecurityFeatureRow(
                icon: "key.fill",
                iconColor: .orange,
                title: String(localized: "AES-256-GCM Encryption"),
                description: String(localized: "Your app data is encrypted using AES-256 in Galois/Counter Mode — the same standard used by governments worldwide")
            )
            .opacity(animateFeatures ? 1.0 : 0)
            .offset(x: animateFeatures ? 0 : -30)

            SecurityFeatureRow(
                icon: "quote.bubble.fill",
                iconColor: .red,
                title: String(localized: "Quote Settings Protected"),
                description: String(localized: "Your notification preferences and app settings are stored securely in the device Keychain")
            )
            .opacity(animateFeatures ? 1.0 : 0)
            .offset(x: animateFeatures ? 0 : -30)
            .animation(.easeOut(duration: 0.5).delay(0.1), value: animateFeatures)

            SecurityFeatureRow(
                icon: "lock.icloud.fill",
                iconColor: .yellow,
                title: String(localized: "Keys Stay On-Device"),
                description: String(localized: "Encryption keys are generated on your device and default to local-only storage — they are never sent to a server")
            )
            .opacity(animateFeatures ? 1.0 : 0)
            .offset(x: animateFeatures ? 0 : -30)
            .animation(.easeOut(duration: 0.5).delay(0.2), value: animateFeatures)

            SecurityFeatureRow(
                icon: "iphone.and.arrow.forward",
                iconColor: .blue,
                title: String(localized: "No Tracking, No Accounts"),
                description: String(localized: "Inner Whisper works entirely offline. No account required, no analytics, no data leaves your device")
            )
            .opacity(animateFeatures ? 1.0 : 0)
            .offset(x: animateFeatures ? 0 : -30)
            .animation(.easeOut(duration: 0.5).delay(0.3), value: animateFeatures)
        }
    }

    // MARK: - Footer

    private var footerNote: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "gearshape.fill")
                .font(.title3)
                .foregroundStyle(.secondary)

            Text("You can manage encryption settings anytime via the **Security** button in the toolbar")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .opacity(animateFeatures ? 1.0 : 0)
    }

    // MARK: - Button

    private var continueButton: some View {
        Button {
            HapticFeedback.success()
            onDismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.title3)

                Text("Continue Securely")
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 56)
            .background(
                LinearGradient(
                    colors: [.green, .green.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .green.opacity(0.4), radius: 12, y: 6)
        }
        .opacity(animateButton ? 1.0 : 0)
        .scaleEffect(animateButton ? 1.0 : 0.9)
        .accessibilityLabel(String(localized: "Continue securely"))
        .accessibilityHint(String(localized: "Tap to dismiss this welcome screen and start using the app"))
    }
}

// MARK: - Security Feature Row

/// A single row displaying a security feature with icon, title, and description
struct SecurityFeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .fixedSize(horizontal: false, vertical: true)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "\(title). \(description)"))
    }
}

// MARK: - Previews

#Preview("Security Welcome") {
    SecurityWelcomeView {
        print("Dismissed")
    }
}

#Preview("Security Welcome - Dark") {
    SecurityWelcomeView { }
        .preferredColorScheme(.dark)
}

#Preview("Security Welcome - Large Text") {
    SecurityWelcomeView { }
        .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
}

#Preview("Security Feature Row") {
    SecurityFeatureRow(
        icon: "key.fill",
        iconColor: .orange,
        title: "AES-256 Encryption",
        description: "Your sensitive data is encrypted using the same standard trusted by governments worldwide"
    )
    .padding()
}
