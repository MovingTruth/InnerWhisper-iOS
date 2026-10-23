//
//  QuoteSourceDisclaimerView.swift
//  InnerWhisper
//
//  Displays a copyright notice and quote attribution disclaimer.
//  Presented as a sheet from SettingsView and Info2View, and embedded
//  as a page in the onboarding walkthrough.
//

import SwiftUI

/// Full-screen disclaimer sheet covering quote sourcing and attribution accuracy.
///
/// Explains that quotes are drawn from public-domain and widely-circulated
/// sources and that InnerWhisper makes no warranty as to their accuracy or
/// correct attribution.
struct QuoteSourceDisclaimerView: View {
    /// Provide a dismiss action when presented as a sheet. Leave `nil` when
    /// embedded inside the onboarding `TabView` (no dedicated close button needed).
    var onDismiss: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var currentYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: Date())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    heroSection
                    attributionSection
                    sourcesSection
                    portfolioEditionSection
                    copyrightSection
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Quote Sources")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let onDismiss {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            HapticFeedback.light()
                            onDismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.teal.opacity(0.25), Color.indigo.opacity(0.18)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 42))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.teal, .indigo],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text("Quote Sources & Attribution")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text("What you should know about our quote collection")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 4)
    }

    // MARK: - Attribution Disclaimer

    private var attributionSection: some View {
        DisclaimerCard(
            icon: "exclamationmark.triangle",
            iconColor: .orange,
            title: String(localized: "No Guarantee of Accuracy"),
            bodyText: String(localized: """
            Inner Whisper contains a curated collection of inspirational quotes drawn \
            from public-domain works, historical writings, and widely circulated sources. \
            While we make every effort to present quotes correctly, we cannot guarantee:

            • The precise wording of every quote
            • That each quote is correctly attributed to the named author
            • That a quote was actually spoken or written by the attributed person

            Many famous quotes are misattributed, paraphrased, or of disputed origin — \
            this is a well-documented phenomenon in quotation literature. \
            Inner Whisper makes no warranty, express or implied, as to the accuracy \
            or authenticity of any quote or its attribution.
            """)
        )
    }

    // MARK: - Sources

    private var sourcesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Quote Collections", systemImage: "books.vertical")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            Text("This portfolio edition includes three small original collections:")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            let collections: [(String, String)] = [
                (String(localized: "Default"), String(localized: "Everyday reflection")),
                (String(localized: "Nature & Forest"), String(localized: "Reflections on the natural world")),
                (String(localized: "Space"), String(localized: "Wonder, distance, and perspective")),
            ]

            VStack(spacing: 6) {
                ForEach(collections, id: \.0) { name, description in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(Color.teal.opacity(0.7))
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(name)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text(description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(String(localized: "\(name): \(description)"))
                }
            }

            DisclaimerCard(
                icon: "info.circle",
                iconColor: .blue,
                title: String(localized: "Corrections Welcome"),
                bodyText: String(localized: """
                If you spot a misattribution or an error in a quote, we want to know. \
                Reach out via the app's website and we will investigate and correct it \
                in a future update.
                """)
            )
        }
    }

    // MARK: - Portfolio Edition

    private var portfolioEditionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Portfolio Edition", systemImage: "chevron.left.forwardslash.chevron.right")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            Text("The public source edition uses original sample quotes and the system notification sound. The production catalogue and licensed audio are intentionally excluded.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Copyright

    private var copyrightSection: some View {
        VStack(spacing: 12) {
            Divider()

            VStack(spacing: 6) {
                RippleCopyrightText("© \(currentYear) Robin O'Brien")

                Text("Inner Whisper is provided for inspirational and entertainment purposes only.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        }
    }
}

// MARK: - RippleCopyrightText

/// Renders the copyright line with the same damped-wave ripple effect used in InnerWhisperLogoView.
/// Tap or drag anywhere on the text to trigger the wave from that position.
private struct RippleCopyrightText: View {
    let text: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var rippleStart: Date?   = nil
    @State private var touchNorm: CGFloat   = 0.5
    @State private var viewWidth: CGFloat   = 200

    // Ripple physics — identical to InnerWhisperLogoView
    private let waveSpeed: Double  = 1.6
    private let frequency: Double  = 7.0
    private let damping:   Double  = 4.5
    private let amplitude: CGFloat = 5.0
    private let duration:  Double  = 0.8

    init(_ text: String) { self.text = text }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                Text(text)
                    .font(.footnote)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let start = rippleStart {
                TimelineView(.animation) { tl in
                    rippleLetters(elapsed: tl.date.timeIntervalSince(start))
                }
                .transition(.identity)
            } else {
                Text(text)
                    .font(.footnote)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .transition(.identity)
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { val in
                    touchNorm   = max(0, min(1, val.location.x / viewWidth))
                    rippleStart = Date()
                }
        )
        .background {
            GeometryReader { geo in
                Color.clear.onAppear { viewWidth = geo.size.width }
            }
        }
        .task(id: rippleStart) {
            guard rippleStart != nil else { return }
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            rippleStart = nil
        }
    }

    @ViewBuilder
    private func rippleLetters(elapsed: Double) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { idx, char in
                Text(String(char))
                    .font(.footnote)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .offset(y: waveOffset(charIndex: idx, elapsed: elapsed))
            }
        }
    }

    private func waveOffset(charIndex: Int, elapsed: Double) -> CGFloat {
        guard elapsed > 0 else { return 0 }
        let charPos  = Double(charIndex) / Double(max(1, text.count - 1))
        let distance = abs(charPos - Double(touchNorm))
        let local    = elapsed - distance / waveSpeed
        guard local > 0 else { return 0 }
        return CGFloat(sin(local * frequency * .pi * 2) * exp(-local * damping)) * amplitude
    }
}

// MARK: - DisclaimerCard

private struct DisclaimerCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let bodyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(iconColor)

            Text(bodyText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "\(title). \(bodyText)"))
    }
}

// MARK: - Previews

#Preview("Sheet") {
    QuoteSourceDisclaimerView(onDismiss: {})
}

#Preview("Sheet — Dark") {
    QuoteSourceDisclaimerView(onDismiss: {})
        .preferredColorScheme(.dark)
}

#Preview("Embedded (no close button)") {
    QuoteSourceDisclaimerView()
}
