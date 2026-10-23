//
//  SkyLaunchSplashView.swift
//  InnerWhisper
//
//  Short cold-start intro: gradient sky, drifting clouds, yin-yang spins and morphs
//  into the glass quote card (styling aligned with SplashIntroView2), then finishes.
//

import SwiftUI

// MARK: - Copy (matches SplashIntroView2)

private enum SkyLaunchContent {
    static let quoteText = String(localized: "Your inner voice is your greatest guide. Listen to it, nurture it, and let it whisper the truth you need to hear in every moment.")
    static let quoteAuthor = String(localized: "Inner Whisper")
    /// Short prompt; "Tap" matches iOS copy (touchscreen and indirect input).
    static let tapToContinueLabel = String(localized: "Tap to continue")
}

private enum SkyLaunchQuoteTypography {
    static let font = Font.system(.body, design: .serif).weight(.medium)
    static let lineSpacing: CGFloat = 7
}

// MARK: - Launch splash

/// Full-screen intro on cold launch: plays the sky / yin-yang / card animation, then waits for a tap on the card before `onComplete`.
struct SkyLaunchSplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Called on the main actor after the user taps the quote card to leave the splash.
    var onComplete: () -> Void

    @State private var spinRotation: Double = 0
    @State private var morphProgress: CGFloat = 0
    /// After the scripted animation, the card accepts a tap to dismiss.
    @State private var isReadyForDismiss = false
    /// Plays after tap: fades and scales the whole splash so the main app underneath is revealed smoothly.
    @State private var isExitingToMain = false

    private let yinYangSize: CGFloat = 150
    private let yinYangRestYOffset: CGFloat = -6

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                let floatY = reduceMotion ? 0 : sin(t * 1.2) * 6
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.42 + yinYangRestYOffset)

                ZStack {
                    skyGradient
                        .frame(width: geo.size.width, height: geo.size.height)

                    FloatingCloudsSky(colorScheme: colorScheme)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .allowsHitTesting(false)

                    // Yin-yang — controlled outer spin only (no inner idle spin / 3D wobble).
                    YinYangView(
                        size: yinYangSize,
                        darkColor: yinDarkColor,
                        lightColor: yinLightColor,
                        isControlledRotation: true
                    )
                        .rotationEffect(.degrees(spinRotation))
                        .scaleEffect(yinYangScale)
                        .opacity(yinYangOpacity)
                        .position(x: center.x, y: center.y + CGFloat(floatY))
                        .allowsHitTesting(false)
                        .shadow(color: yinDarkColor.opacity(0.35), radius: 18, y: 10)

                    if dynamicTypeSize.isAccessibilitySize {
                        accessibilityQuoteCard(geo: geo)
                            .opacity(cardOpacity)
                            .scaleEffect(cardScale)
                            .allowsHitTesting(isReadyForDismiss && cardOpacity > 0.25)
                    } else {
                        launchQuoteCard(geo: geo, centerY: center.y + CGFloat(floatY))
                            .opacity(cardOpacity)
                            .scaleEffect(cardScale)
                            .allowsHitTesting(isReadyForDismiss && cardOpacity > 0.25)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .ignoresSafeArea()
        .opacity(isExitingToMain ? 0 : 1)
        .scaleEffect(isExitingToMain ? (reduceMotion ? 1 : 1.06) : 1)
        .allowsHitTesting(!isExitingToMain)
        .task {
            if reduceMotion {
                morphProgress = 1
                spinRotation = 180
                isReadyForDismiss = true
                return
            }
            do {
                try await runSequence()
            } catch is CancellationError {
                // Splash removed early (e.g. warm resume) — avoid mutating state after teardown.
            } catch {
                // `Task.sleep` only throws `CancellationError`; keep a catch-all so `.task` stays non-throwing.
            }
        }
    }

    // MARK: - Morph math

    private var yinYangOpacity: Double {
        Double(1 - smoothstep(morphProgress))
    }

    private var yinYangScale: CGFloat {
        1 - 0.22 * morphProgress
    }

    private var cardOpacity: Double {
        Double(smoothstep(morphProgress))
    }

    private var cardScale: CGFloat {
        0.9 + 0.1 * morphProgress
    }

    private func smoothstep(_ t: CGFloat) -> CGFloat {
        let x = min(1, max(0, t))
        return x * x * (3 - 2 * x)
    }

    /// Runs a short full-screen exit animation, then hands off to the app shell so `ContentView` is shown.
    @MainActor
    private func beginTransitionToMainApp() {
        guard isReadyForDismiss, !isExitingToMain else { return }
        let seconds: TimeInterval = reduceMotion ? 0.22 : 0.5
        let animation: Animation = reduceMotion
            ? .easeOut(duration: seconds)
            : .easeIn(duration: seconds)
        withAnimation(animation) {
            isExitingToMain = true
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            onComplete()
        }
    }

    // MARK: - Card (SplashIntroView2 styling)

    private func launchQuoteCard(geo: GeometryProxy, centerY: CGFloat) -> some View {
        let cardWidth = min(geo.size.width - 24, 440)

        return quoteCardSurface(cardWidth: cardWidth)
            .position(x: geo.size.width / 2, y: centerY)
    }

    /// At accessibility sizes the card can be taller than the smallest iPhone.
    /// Scrolling keeps every word and the continue action reachable instead of
    /// asking SwiftUI to compress the quote inside a fixed, centred position.
    private func accessibilityQuoteCard(geo: GeometryProxy) -> some View {
        ScrollView(.vertical, showsIndicators: true) {
            quoteCardSurface(cardWidth: min(geo.size.width - 24, 440))
                .padding(.vertical, max(24, geo.safeAreaInsets.top + 12))
        }
        .frame(width: geo.size.width, height: geo.size.height)
    }

    private func quoteCardSurface(cardWidth: CGFloat) -> some View {
        quoteCardBody
            .padding(.vertical, 24)
            .padding(.horizontal, 22)
            .frame(width: cardWidth, alignment: .center)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(hazyCardFill)
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(cardEdgeSheen, lineWidth: 1.25)
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(hazyCardStrokeGradient, lineWidth: 0.5)
                }
            }
            .shadow(color: brandGlowColor.opacity(colorScheme == .dark ? 0.12 : 0.2), radius: 28, y: 8)
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.38 : 0.12), radius: 24, y: 16)
            .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
            .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .onTapGesture {
                beginTransitionToMainApp()
            }
            .accessibilityAddTraits(isReadyForDismiss ? .isButton : [])
            .accessibilityHint(isReadyForDismiss ? String(localized: "Double tap to continue into the app.") : "")
    }

    private var quoteCardBody: some View {
        VStack(spacing: 18) {
            VStack(spacing: 10) {
                Image("MovingTruthLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                    .accessibilityHidden(true)
                Text("A moment for you")
                    .font(.caption.weight(.semibold))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(.tertiary)
            }
            .accessibilityHidden(true)

            Text(SkyLaunchContent.quoteText)
                .font(SkyLaunchQuoteTypography.font)
                .lineSpacing(SkyLaunchQuoteTypography.lineSpacing)
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(SkyLaunchContent.quoteText)

            Text("— \(SkyLaunchContent.quoteAuthor)")
                .font(.subheadline.weight(.semibold).italic())
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(String(localized: "Author: \(SkyLaunchContent.quoteAuthor)"))

            if isReadyForDismiss {
                Text(SkyLaunchContent.tapToContinueLabel)
                    .font(.footnote.weight(.semibold))
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
                    .background(
                        Capsule(style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.18 : 0.45), lineWidth: 0.75)
                            )
                    )
                    .padding(.top, 6)
                    .accessibilityHidden(true)

                Text("v\(appVersion)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
    }

    /// Marketing version + build number, e.g. "1.2 (34)".
    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }

    private var hazyCardFill: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(colorScheme == .dark ? 0.07 : 0.18),
                Color.white.opacity(colorScheme == .dark ? 0.02 : 0.08),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var hazyCardStrokeGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(colorScheme == .dark ? 0.22 : 0.55),
                Color.white.opacity(colorScheme == .dark ? 0.08 : 0.2),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var cardEdgeSheen: LinearGradient {
        LinearGradient(
            colors: [
                brandGlowColor.opacity(colorScheme == .dark ? 0.35 : 0.5),
                Color(red: 0.45, green: 0.78, blue: 0.92).opacity(colorScheme == .dark ? 0.2 : 0.35),
                brandGlowColor.opacity(colorScheme == .dark ? 0.15 : 0.25),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var brandGlowColor: Color {
        Color(red: 0.98, green: 0.72, blue: 0.42)
    }

    private var skyGradient: some View {
        LinearGradient(
            colors: skyGradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var skyGradientColors: [Color] {
        switch colorScheme {
        case .dark:
            return [
                Color(red: 0.10, green: 0.12, blue: 0.22),
                Color(red: 0.11, green: 0.16, blue: 0.28),
                Color(red: 0.08, green: 0.14, blue: 0.26),
            ]
        default:
            return [
                Color(red: 0.80, green: 0.91, blue: 0.99),
                Color(red: 0.68, green: 0.85, blue: 0.98),
                Color(red: 0.58, green: 0.80, blue: 0.97),
            ]
        }
    }

    private var yinDarkColor: Color {
        colorScheme == .dark ? Color(red: 0.92, green: 0.94, blue: 0.96) : Color(red: 0.12, green: 0.14, blue: 0.18)
    }

    private var yinLightColor: Color {
        colorScheme == .dark ? Color(red: 0.15, green: 0.2, blue: 0.28) : Color(red: 0.96, green: 0.97, blue: 0.98)
    }

    // MARK: - Sequence

    @MainActor
    private func runSequence() async throws {
        spinRotation = 180
        morphProgress = 0

        try await Task.sleep(for: .milliseconds(50))

        withAnimation(.timingCurve(0.4, 0.0, 0.2, 1.0, duration: 1.4)) {
            spinRotation = 460  // 180 + 280 — same arc, white starts on right
        }
        try await Task.sleep(for: .seconds(1.4))

        withAnimation(.spring(response: 0.55, dampingFraction: 0.82, blendDuration: 0.12)) {
            morphProgress = 1
        }
        try await Task.sleep(for: .milliseconds(600))

        withAnimation(.easeOut(duration: 0.45)) {
            isReadyForDismiss = true
        }
    }
}

// MARK: - Clouds

/// Soft, layered clouds drifting horizontally across the sky.
private struct FloatingCloudsSky: View {
    var colorScheme: ColorScheme

    private struct CloudSpec {
        var baseYNorm: CGFloat
        var scale: CGFloat
        var speed: CGFloat
        var phase: CGFloat
        var opacity: Double
    }

    /// `baseYNorm` is 0…1 from top to bottom of the full sky (entire view height).
    private let specs: [CloudSpec] = [
        CloudSpec(baseYNorm: 0.06, scale: 0.95, speed: 20, phase: 0.05, opacity: 0.48),
        CloudSpec(baseYNorm: 0.14, scale: 1.1, speed: 24, phase: 0.0, opacity: 0.52),
        CloudSpec(baseYNorm: 0.22, scale: 0.8, speed: 16, phase: 0.35, opacity: 0.4),
        CloudSpec(baseYNorm: 0.30, scale: 1.05, speed: 18, phase: 0.52, opacity: 0.46),
        CloudSpec(baseYNorm: 0.38, scale: 0.65, speed: 30, phase: 0.68, opacity: 0.34),
        CloudSpec(baseYNorm: 0.46, scale: 0.9, speed: 14, phase: 0.22, opacity: 0.44),
        CloudSpec(baseYNorm: 0.54, scale: 1.12, speed: 22, phase: 0.41, opacity: 0.5),
        CloudSpec(baseYNorm: 0.62, scale: 0.72, speed: 26, phase: 0.78, opacity: 0.36),
        CloudSpec(baseYNorm: 0.70, scale: 0.88, speed: 12, phase: 0.12, opacity: 0.42),
        CloudSpec(baseYNorm: 0.78, scale: 0.58, speed: 32, phase: 0.88, opacity: 0.32),
        CloudSpec(baseYNorm: 0.86, scale: 0.98, speed: 17, phase: 0.63, opacity: 0.4),
        CloudSpec(baseYNorm: 0.93, scale: 0.75, speed: 21, phase: 0.29, opacity: 0.35),
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: false)) { ctx in
            let t = CGFloat(ctx.date.timeIntervalSinceReferenceDate)
            Canvas { context, size in
                for spec in specs {
                    drawCloudTiled(
                        context: &context,
                        size: size,
                        time: t,
                        spec: spec
                    )
                }
            }
        }
    }

    /// Horizontal repeat distance: independent of full view width so wide layouts (e.g. iPad) get
    /// several tiled instances across the sky instead of one sparse lap where the left edge stays bare.
    private func horizontalPeriod(for size: CGSize) -> CGFloat {
        let byWidth = size.width / 2.35
        return max(320, min(540, byWidth))
    }

    /// Scales cloud artwork so coverage matches wider aspect ratios; phone-sized widths stay ~1:1.
    private func cloudSizeScale(for size: CGSize) -> CGFloat {
        max(1.0, min(1.45, size.width / 400))
    }

    private func drawCloudTiled(
        context: inout GraphicsContext,
        size: CGSize,
        time: CGFloat,
        spec: CloudSpec
    ) {
        let period = horizontalPeriod(for: size)
        let drift = spec.phase * period + time * spec.speed
        let baseX = drift.truncatingRemainder(dividingBy: period) - period * 0.35
        let copyCount = max(3, Int(ceil(size.width / period)) + 2)

        for k in 0..<copyCount {
            let x = baseX + CGFloat(k) * period
            drawCloudInstance(
                context: &context,
                size: size,
                time: time,
                spec: spec,
                originX: x,
                sizeScale: cloudSizeScale(for: size)
            )
        }
    }

    private func drawCloudInstance(
        context: inout GraphicsContext,
        size: CGSize,
        time: CGFloat,
        spec: CloudSpec,
        originX: CGFloat,
        sizeScale: CGFloat
    ) {
        let baseY = spec.baseYNorm * size.height
        let bob = sin(Double(time) * 0.65 + Double(spec.phase) * 5.0) * 5
        let cloudColor: Color = colorScheme == .dark
            ? Color.white.opacity(0.14 * spec.opacity)
            : Color.white.opacity(spec.opacity)

        var layer = context
        layer.translateBy(x: originX, y: baseY + CGFloat(bob))
        layer.scaleBy(x: spec.scale * sizeScale, y: spec.scale * sizeScale)

        let blobs: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (0, 0, 52, 28),
            (-32, 4, 40, 24),
            (28, 6, 44, 26),
            (-14, -10, 36, 22),
            (14, 12, 38, 20),
        ]
        for (dx, dy, w, h) in blobs {
            let rect = CGRect(x: dx - w / 2, y: dy - h / 2, width: w, height: h)
            layer.fill(
                Path(ellipseIn: rect),
                with: .color(cloudColor)
            )
        }
    }
}

// MARK: - Previews

#Preview("Launch splash") {
    SkyLaunchSplashView {
    }
}

#Preview("Dark") {
    SkyLaunchSplashView {
    }
    .preferredColorScheme(.dark)
}

#Preview("Smallest iPhone — AX5") {
    SkyLaunchSplashView {
    }
    .environment(\.dynamicTypeSize, .accessibility5)
}
