//
//  Info2View.swift
//  InnerWhisper
//
//  Created by Robin O'Brien on 2026-01-23.
//
//  Zen about / info page — a living canvas with no cards, no borders.
//  Content floats over an animated gradient background whose personality
//  is defined entirely by the active InfoPageSkin.
//
//  Five skins are built in; users switch between them via the dot-row
//  at the bottom. The selection persists in AppStorage.

import SwiftUI

// MARK: - Main view

/// Zen about screen — skin-driven, meditative, interactive.
struct Info2View: View {

    /// When provided, called instead of the environment dismiss action (used for overlay presentation).
    var dismissAction: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // MARK: Skin persistence
    @AppStorage("InnerWhisper.InfoPageSkinID") private var selectedSkinID: String = "movingTruth"
    /// Currently active skin, resolved from AppStorage each time selectedSkinID changes.
    private var skin: InfoPageSkin { InfoPageSkin.skin(for: selectedSkinID) }

    // MARK: Animation state
    /// Drives glow pulse opacity and scale; 0 = dim, 1 = bright.
    @State private var breathePhase: Double = 0.0
    /// Drives concentric ring opacity around the Robin photo.
    @State private var ringOpacity: Double = 0.4
    /// Triggers staggered appearance of feature icons.
    @State private var featuresVisible = false
    /// True until the initial onAppear skin swap has completed; forces the hero icon's
    /// `.id()`-driven insertion/removal to use `.identity` (no animation) for that one
    /// swap, since it's otherwise liable to inherit whatever ambient animation happens
    /// to be current (e.g. the breathing repeatForever kicked off by startBreathing())
    /// and crossfade the old, persisted icon into the new one over several seconds.
    @State private var suppressIconTransition = true

    // MARK: Navigation
    @State private var showingDisclaimer = false
    private let websiteURL  = URL(string: "https://movingtruth.com")!
    private let developerURL = URL(string: "https://inner-whisper.movingtruth.com/")!
    private let privacyURL  = URL(string: "https://inner-whisper.movingtruth.com/privacy_policy.html")!

    // MARK: Helpers
    private var isIPad: Bool { horizontalSizeClass == .regular }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }

    private var appName: String {
        Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ??
        Bundle.main.infoDictionary?["CFBundleName"] as? String ??
        "InnerWhisper"
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // Layer 1: skin gradient — cross-fades on skin change
                LinearGradient(
                    colors: skin.backgroundColors,
                    startPoint: skin.backgroundGradientStart,
                    endPoint: skin.backgroundGradientEnd
                )
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.6), value: selectedSkinID)

                // Layer 2: breathing radial glow
                RadialGradient(
                    colors: [
                        skin.glowColor.opacity(0.08 + breathePhase * 0.10),
                        .clear
                    ],
                    center: .center,
                    startRadius: 60,
                    endRadius: 440
                )
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.6), value: selectedSkinID)

                // Layer 3: ambient floating motes (disabled when Reduce Motion is on)
                if !reduceMotion {
                    AmbientMotesView(skin: skin)
                        .ignoresSafeArea()
                        .animation(.easeInOut(duration: 0.6), value: selectedSkinID)
                }

                // Layer 4: scrollable content
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        zenLeafSection
                        dotSeparator
                        descriptionSection
                        dotSeparator
                        featuresRow
                        dotSeparator
                        developerSection
                        linksRow
                        skinSwitcherRow
                        InnerWhisperLogoView()
                            .padding(.top, 12)
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, isIPad ? 48 : 28)
                }

                // Layer 5: corner spiral ornaments — decorative, non-interactive
                CornerOrnamentsView(skin: skin)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .animation(.easeInOut(duration: 0.6), value: selectedSkinID)
            }
            .preferredColorScheme(skin.preferredColorScheme)
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        HapticFeedback.light()
                        if let action = dismissAction { action() } else { dismiss() }
                    }
                    .foregroundStyle(skin.textColor)
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingDisclaimer) {
                QuoteSourceDisclaimerView(onDismiss: { showingDisclaimer = false })
            }
            .onAppear {
                UIAccessibility.post(notification: .screenChanged, argument: "About screen")
                // Pin this to a non-animated transaction so the icon (and other
                // skin-driven elements) appear once, instantly — the withAnimation
                // calls below (via startBreathing) must not bleed into this change
                // and crossfade the freshly-persisted icon into the new one.
                var noAnimation = Transaction()
                noAnimation.disablesAnimations = true
                withTransaction(noAnimation) {
                    selectedSkinID = randomSkinID()
                }
                startBreathing()
                // Release the .identity guard on the next runloop tick, once the
                // instant swap above has committed, so later skin changes (dot tap,
                // 15s auto-advance) get their intended crossfade back.
                DispatchQueue.main.async {
                    suppressIconTransition = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    withAnimation(.easeOut(duration: 0.8)) {
                        featuresVisible = true
                    }
                }
            }
            .onChange(of: selectedSkinID) {
                // Restart breathing so the new skin's pulseSpeed takes effect immediately.
                startBreathing()
            }
            // Re-armed every time selectedSkinID changes (manual tap or auto-advance),
            // so a manual choice always gets a fresh 15s window before the next auto-advance.
            .task(id: selectedSkinID) {
                guard !reduceMotion else { return }
                try? await Task.sleep(for: .seconds(15))
                guard !Task.isCancelled else { return }
                advanceToNextSkin()
            }
        }
    }

    // MARK: - Animation

    /// Starts (or restarts) the two interleaved breathing animations driven by skin.pulseSpeed.
    /// Resetting breathePhase and ringOpacity first ensures the new skin's timing applies immediately.
    private func startBreathing() {
        guard !reduceMotion else { return }
        breathePhase = 0
        ringOpacity = 0.4
        withAnimation(
            .easeInOut(duration: skin.pulseSpeed)
            .repeatForever(autoreverses: true)
        ) {
            breathePhase = 1.0
        }
        withAnimation(
            .easeInOut(duration: skin.pulseSpeed * 0.9)
            .repeatForever(autoreverses: true)
        ) {
            ringOpacity = 0.85
        }
    }

    // MARK: - Skin Selection

    /// Switches to the given skin id with the standard cross-fade + feature re-stagger animation.
    private func selectSkin(_ id: String) {
        withAnimation(.easeInOut(duration: 0.6)) {
            selectedSkinID = id
            featuresVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeOut(duration: 0.5)) {
                featuresVisible = true
            }
        }
    }

    /// Advances to the next skin in `InfoPageSkin.all`, wrapping around at the end.
    private func advanceToNextSkin() {
        let all = InfoPageSkin.all
        guard let currentIndex = all.firstIndex(where: { $0.id == selectedSkinID }) else { return }
        let nextIndex = (currentIndex + 1) % all.count
        selectSkin(all[nextIndex].id)
    }

    /// Picks a random skin, excluding the currently selected one so each visit to this
    /// screen visibly opens on a different theme. The 15s auto-advance then proceeds
    /// from this starting point, same as always.
    private func randomSkinID() -> String {
        let candidates = InfoPageSkin.all.map(\.id).filter { $0 != selectedSkinID }
        return candidates.randomElement() ?? selectedSkinID
    }

    // MARK: - View Sections

    @ViewBuilder
    private func skinIcon(size: CGFloat) -> some View {
        switch skin.iconType {
        case .leaf:          LeafView(size: size)
        case .moon:          MoonView(size: size)
        case .compassRose:   CompassRoseView(size: size)
        case .lotus:         LotusFlowerView(size: size)
        case .flame:         FlameView(size: size)
        case .enso:          EnsoView(size: size)
        case .cherryBlossom: CherryBlossomView(size: size)
        case .waterDroplet:  WaterDropletView(size: size)
        case .snowflake:     SnowflakeView(size: size)
        }
    }

    /// Hero: skin-specific interactive icon, letter-spaced app name, monospaced version.
    private var zenLeafSection: some View {
        VStack(spacing: 20) {
            skinIcon(size: isIPad ? 190 : 160)
                .id(skin.iconType)
                .transition(suppressIconTransition ? .identity : .opacity)
                .padding(.top, isIPad ? 44 : 28)
                .background(
                    Circle()
                        .fill(skin.glowColor.opacity(0.06 + breathePhase * 0.06))
                        .frame(width: isIPad ? 230 : 200)
                        .blur(radius: 32)
                )
                .accessibilityLabel(String(localized: "Interactive icon. Drag to spin."))

            Text(appName.uppercased())
                .font(.title2.bold())
                .tracking(dynamicTypeSize.isAccessibilitySize ? 2 : 6)
                .foregroundStyle(skin.textColor)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .animation(.easeInOut(duration: 0.6), value: selectedSkinID)

            Text("v\(appVersion)")
                .font(.caption.monospaced())
                .foregroundStyle(skin.secondaryTextColor)
                .animation(.easeInOut(duration: 0.6), value: selectedSkinID)
        }
        .frame(maxWidth: .infinity)
    }

    /// A quiet row of small dots used as a section divider.
    private var dotSeparator: some View {
        HStack(spacing: 8) {
            ForEach(0..<9, id: \.self) { _ in
                Circle()
                    .fill(skin.separatorColor)
                    .frame(width: 3, height: 3)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .animation(.easeInOut(duration: 0.6), value: selectedSkinID)
    }

    /// Skin-specific tagline and about paragraph, both centered with generous line spacing.
    private var descriptionSection: some View {
        VStack(spacing: 16) {
            Text(skin.tagline)
                .font(.body)
                .italic()
                .tracking(dynamicTypeSize.isAccessibilitySize ? 0.5 : 2)
                .foregroundStyle(skin.textColor.opacity(0.90))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(skin.aboutText)
                .font(.callout)
                .foregroundStyle(skin.textColor.opacity(0.80))
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .frame(maxWidth: isIPad ? 540 : .infinity)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 8)
        .animation(.easeInOut(duration: 0.6), value: selectedSkinID)
    }

    /// Five feature icons with skin-specific short labels below each — no borders, no cards.
    @ViewBuilder
    private var featuresRow: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(featureItems.enumerated()), id: \.offset) { index, item in
                    HStack(spacing: 16) {
                        featureIcon(item)
                        Text(skin.featureLabels[index])
                            .font(.body.weight(.medium))
                            .foregroundStyle(skin.secondaryTextColor)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .modifier(FeatureAppearanceModifier(
                        label: skin.featureLabels[index],
                        isVisible: featuresVisible,
                        animationDelay: Double(index) * 0.08
                    ))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        } else {
            HStack(alignment: .top, spacing: isIPad ? 28 : 14) {
                ForEach(Array(featureItems.enumerated()), id: \.offset) { index, item in
                    VStack(spacing: 8) {
                        featureIcon(item)

                        Text(skin.featureLabels[index])
                            .font(.caption.weight(.medium))
                            .fontDesign(.rounded)
                            .foregroundStyle(skin.secondaryTextColor)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)
                            .fixedSize(horizontal: false, vertical: true)
                            .animation(.easeInOut(duration: 0.6), value: selectedSkinID)
                    }
                    .frame(maxWidth: .infinity)
                    .modifier(FeatureAppearanceModifier(
                        label: skin.featureLabels[index],
                        isVisible: featuresVisible,
                        animationDelay: Double(index) * 0.08
                    ))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
    }

    private func featureIcon(_ item: FeatureItem) -> some View {
        ZStack {
            Circle()
                .fill(skin.accentColor.opacity(0.10 + breathePhase * 0.06))
                .frame(width: 52, height: 52)
                .blur(radius: 8)
            Image(systemName: item.icon)
                .font(.title3.weight(.medium))
                .foregroundStyle(item.color)
        }
        .frame(width: 52, height: 52)
    }

    /// Logo in an animated circular frame, developer name and credit below.
    private var developerSection: some View {
        VStack(spacing: 14) {
            Button {
                HapticFeedback.light()
                if UIApplication.shared.canOpenURL(websiteURL) {
                    UIApplication.shared.open(websiteURL)
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(skin.glowColor.opacity(0.18))
                        .frame(width: 114, height: 114)
                        .blur(radius: 14)
                    Circle()
                        .strokeBorder(skin.accentColor.opacity(ringOpacity * 0.45), lineWidth: 2)
                        .frame(width: 126, height: 126)
                    Circle()
                        .strokeBorder(skin.accentColor.opacity(ringOpacity), lineWidth: 1.5)
                        .frame(width: 112, height: 112)
                    Image("MovingTruthLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                }
                .shadow(color: skin.glowColor.opacity(0.22), radius: 22, x: 0, y: 8)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Moving Truth logo. Opens movingtruth.com"))
            .accessibilityHint(String(localized: "Double tap to open the Moving Truth website"))

            VStack(spacing: 3) {
                Text("Inner Whisper")
                    .font(.headline.bold())
                    .foregroundStyle(skin.textColor)
                Text("by Moving Truth")
                    .font(.subheadline)
                    .foregroundStyle(skin.secondaryTextColor)
            }

            Text("Made with \u{2665} by Skylaur Roe")
                .font(.subheadline)
                .foregroundStyle(skin.secondaryTextColor)

            Button {
                HapticFeedback.light()
                if UIApplication.shared.canOpenURL(websiteURL) {
                    UIApplication.shared.open(websiteURL)
                }
            } label: {
                Text("movingtruth.com")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(skin.accentColor)
                    .underline(color: skin.accentColor.opacity(0.5))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Moving Truth website"))
            .accessibilityHint(String(localized: "Opens movingtruth.com in Safari"))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .animation(.easeInOut(duration: 0.6), value: selectedSkinID)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Moving Truth. Made with love by Skylaur Roe. movingtruth.com"))
    }

    /// Structured links — Inner Whisper group, ornamental divider, Quote Sources.
    private var linksRow: some View {
        VStack(spacing: 0) {

            // ── Inner Whisper group ───────────────────────────────────────────
            VStack(spacing: 12) {
                linkButton(
                    label: String(localized: "Inner Whisper Website"),
                    icon:  "globe",
                    url:   developerURL,
                    hint:  String(localized: "Opens the Inner Whisper website in Safari")
                )
                linkButton(
                    label: String(localized: "Privacy Policy"),
                    icon:  "lock.shield",
                    url:   privacyURL,
                    hint:  String(localized: "Opens the privacy policy in Safari")
                )
            }
            .padding(.vertical, 20)

            // ── Ornamental divider ────────────────────────────────────────────
            linksDivider

            // ── Quote Sources ─────────────────────────────────────────────────
            Button {
                HapticFeedback.light()
                showingDisclaimer = true
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "quote.bubble")
                        .font(.subheadline.weight(.medium))
                    Text("Quote Sources")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(skin.accentColor)
            }
            .buttonStyle(.plain)
            .padding(.top, 18)
            .accessibilityLabel(String(localized: "Quote Sources and Attribution"))
            .accessibilityHint(String(localized: "View information about quote sources and accuracy"))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
        .animation(.easeInOut(duration: 0.6), value: selectedSkinID)
    }

    /// Thin rule with a centred diamond ornament — visually separates link groups.
    private var linksDivider: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(skin.separatorColor)
                .frame(height: 0.5)
            Image(systemName: "diamond.fill")
                .font(.system(size: 5))
                .foregroundStyle(skin.separatorColor)
            Rectangle()
                .fill(skin.separatorColor)
                .frame(height: 0.5)
        }
        .padding(.horizontal, 24)
    }

    /// Reusable tappable link row with a leading SF Symbol icon.
    private func linkButton(label: String, icon: String, url: URL, hint: String) -> some View {
        Button {
            HapticFeedback.light()
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            } else {
                HapticFeedback.error()
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.medium))
                Text(label)
                    .font(.subheadline.weight(.medium))
                    .underline(color: skin.accentColor.opacity(0.45))
            }
            .foregroundStyle(skin.accentColor)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityHint(hint)
    }

    /// Five coloured dots at the bottom — tap to switch skins with a cross-fade.
    private var skinSwitcherRow: some View {
        HStack(spacing: 16) {
            ForEach(InfoPageSkin.all) { s in
                Button {
                    guard s.id != selectedSkinID else { return }
                    HapticFeedback.selection()
                    selectSkin(s.id)
                } label: {
                    ZStack {
                        // Background swatch hint from the darkest background colour
                        Circle()
                            .fill(s.backgroundColors.last ?? .clear)
                            .frame(width: 14, height: 14)

                        if s.id == selectedSkinID {
                            Circle()
                                .fill(s.accentColor)
                                .frame(width: 14, height: 14)
                            Circle()
                                .strokeBorder(s.accentColor.opacity(0.55), lineWidth: 1.5)
                                .frame(width: 22, height: 22)
                        } else {
                            Circle()
                                .strokeBorder(s.accentColor.opacity(0.55), lineWidth: 1.5)
                                .frame(width: 14, height: 14)
                        }
                    }
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: selectedSkinID)
                }
                .buttonStyle(.plain)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel(String(localized: "\(s.name) skin\(s.id == selectedSkinID ? String(localized: ", selected") : "")"))
                .accessibilityAddTraits(s.id == selectedSkinID ? [.isSelected] : [])
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 28)
    }
}

/// Applies the shared reveal animation and accessibility semantics to both
/// horizontal and accessibility feature layouts.
private struct FeatureAppearanceModifier: ViewModifier {
    let label: String
    let isVisible: Bool
    let animationDelay: Double

    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.7)
            .animation(
                .spring(response: 0.5, dampingFraction: 0.72)
                    .delay(animationDelay),
                value: isVisible
            )
    }
}

// MARK: - Corner ornaments

/// Delicate Archimedean spirals drawn in each screen corner — purely decorative, non-interactive.
private struct CornerOrnamentsView: View {
    let skin: InfoPageSkin

    var body: some View {
        Canvas { ctx, size in
            let maxR = min(size.width, size.height) * 0.20
            let corners: [(CGFloat, CGFloat, Double)] = [
                (0,           0,            .pi * 0.75),
                (size.width,  0,            .pi * 0.25),
                (0,           size.height,  .pi * 1.25),
                (size.width,  size.height,  .pi * 1.75),
            ]
            for (cx, cy, startAngle) in corners {
                drawSpiral(ctx, cx: cx, cy: cy, startAngle: startAngle, maxR: maxR)
            }
        }
        .allowsHitTesting(false)
    }

    private func drawSpiral(
        _ ctx: GraphicsContext,
        cx: CGFloat, cy: CGFloat,
        startAngle: Double,
        maxR: CGFloat
    ) {
        let steps = 120
        var path  = Path()
        for i in 0...steps {
            let t     = Double(i) / Double(steps)
            let angle = startAngle + t * .pi * 2 * 1.6
            let r     = CGFloat(t) * maxR
            let pt    = CGPoint(x: cx + cos(angle) * r, y: cy + sin(angle) * r)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        ctx.stroke(
            path,
            with: .color(skin.accentColor.opacity(0.18)),
            style: StrokeStyle(lineWidth: 1.1, lineCap: .round, lineJoin: .round)
        )
    }
}

// MARK: - Feature items

/// Static data carrier for feature icon rows — icon name, fixed colour.
private struct FeatureItem {
    let icon: String
    let color: Color
}

/// Five feature items; labels come from the active skin.
private let featureItems: [FeatureItem] = [
    FeatureItem(icon: "quote.bubble.fill",  color: Color(red: 0.45, green: 0.70, blue: 0.98)),
    FeatureItem(icon: "bell.badge.fill",    color: Color(red: 0.95, green: 0.60, blue: 0.25)),
    FeatureItem(icon: "heart.fill",         color: Color(red: 0.92, green: 0.35, blue: 0.52)),
    FeatureItem(icon: "lock.shield.fill",   color: Color(red: 0.35, green: 0.78, blue: 0.48)),
    FeatureItem(icon: "sparkles",           color: Color(red: 0.75, green: 0.50, blue: 0.98)),
]

// MARK: - Ambient motes

/// 15 slowly drifting particles rendered via Canvas — adds life without visual noise.
private struct AmbientMotesView: View {
    let skin: InfoPageSkin

    /// Deterministic pseudo-random particle descriptor — seeded from index, no @State needed.
    private struct Mote {
        let xNorm: Double    // normalised horizontal position 0…1
        let yNorm: Double    // initial normalised vertical position 0…1
        let size: Double     // radius in pts
        let speed: Double    // upward drift speed (pts / second)
        let phase: Double    // opacity cycle phase offset 0…2π
        let cycleLen: Double // opacity oscillation period in seconds
    }

    private let motes: [Mote] = (0..<15).map { i in
        let f = Double(i)
        return Mote(
            xNorm:    (f * 0.137 + 0.05).truncatingRemainder(dividingBy: 0.94) + 0.03,
            yNorm:    (f * 0.211 + 0.08).truncatingRemainder(dividingBy: 0.92) + 0.04,
            size:     2.0 + (f * 0.37).truncatingRemainder(dividingBy: 2.0),
            speed:    8.0 + (f * 3.1).truncatingRemainder(dividingBy: 18.0),
            phase:    (f * 0.73).truncatingRemainder(dividingBy: .pi * 2),
            cycleLen: 4.0 + (f * 0.6).truncatingRemainder(dividingBy: 5.0)
        )
    }

    var body: some View {
        // 30 fps cap keeps battery impact negligible
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                for mote in motes {
                    drawMote(context: context, size: size, t: t, mote: mote)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func drawMote(context: GraphicsContext, size: CGSize, t: Double, mote: Mote) {
        let driftY = (t * mote.speed).truncatingRemainder(dividingBy: size.height)
        let y = (mote.yNorm * size.height - driftY + size.height)
                    .truncatingRemainder(dividingBy: size.height)
        let x = mote.xNorm * size.width
        let opCycle = (sin(t / mote.cycleLen * .pi * 2 + mote.phase) + 1.0) / 2.0
        let opacity = opCycle * skin.particleOpacity * 0.5
        let r = mote.size
        context.fill(
            Path(ellipseIn: CGRect(x: x - r / 2, y: y - r / 2, width: r, height: r)),
            with: .color(skin.accentColor.opacity(opacity))
        )
    }
}

// MARK: - Previews

#Preview("Moonlit") {
    Info2View()
}

#Preview("Wabi (Light)") {
    Info2View()
        .onAppear {
            UserDefaults.standard.set("wabi", forKey: "InnerWhisper.InfoPageSkinID")
        }
}

#Preview("Ember Night") {
    Info2View()
        .onAppear {
            UserDefaults.standard.set("emberNight", forKey: "InnerWhisper.InfoPageSkinID")
        }
}

#Preview("Sakura") {
    Info2View()
        .onAppear {
            UserDefaults.standard.set("sakura", forKey: "InnerWhisper.InfoPageSkinID")
        }
}
