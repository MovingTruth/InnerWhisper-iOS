//
//  InfoPageSkin.swift
//  InnerWhisper
//
//  Created by Robin O'Brien on 2026-05-22.
//
//  Defines the visual and textual personality of the zen info / about page.
//  Each skin is a self-contained value: gradient, glow, typography colours,
//  animation timing, and its own written voice (tagline, about text, feature labels).
//
//  To add a new skin:
//  1. Add a static let with a unique id string.
//  2. Add it to the `all` array below.
//  AppStorage key "InnerWhisper.InfoPageSkinID" persists the selected skin id.

import SwiftUI

// MARK: - Icon type

/// The fidget icon displayed in the hero section of the about page.
enum SkinIconType {
    case leaf
    case moon
    case compassRose
    case lotus
    case flame
    case enso
    case cherryBlossom
    case waterDroplet
    case snowflake
}

// MARK: - Skin definition

/// Self-contained visual and textual theme for the zen info page.
struct InfoPageSkin: Identifiable {
    let id: String
    let name: String

    // MARK: Background
    let backgroundColors: [Color]
    let backgroundGradientStart: UnitPoint
    let backgroundGradientEnd: UnitPoint

    // MARK: Accent / glow
    /// Radial glow colour layered over the gradient background.
    let glowColor: Color
    /// Primary interactive / highlight colour (skin switcher dots, link text, icon halos).
    let accentColor: Color

    // MARK: Typography
    let textColor: Color
    let secondaryTextColor: Color
    /// Colour for the dot-separator rows and inactive skin-switcher dots.
    let separatorColor: Color

    // MARK: Animation tuning
    /// Duration (seconds) of one full breathe-in / breathe-out glow cycle.
    let pulseSpeed: Double
    /// Scales the opacity of ambient floating motes; 0 = invisible, 1 = full.
    let particleOpacity: Double
    /// Forces light or dark system colour scheme so `.tertiary` resolves correctly.
    let preferredColorScheme: ColorScheme

    // MARK: Hero icon
    /// The fidget icon shown in the hero section; each skin has its own.
    let iconType: SkinIconType

    // MARK: Skin-specific text voice
    let tagline: String
    let aboutText: String
    /// Exactly 5 short labels, one per feature icon row entry.
    let featureLabels: [String]
}

// MARK: - Presets

extension InfoPageSkin {

    /// Moving Truth — near-black / warm gold. The default skin.
    static let movingTruth = InfoPageSkin(
        id: "movingTruth",
        name: String(localized: "Moving Truth"),
        backgroundColors: [
            Color(red: 0.051, green: 0.051, blue: 0.051),   // #0D0D0D
            Color(red: 0.086, green: 0.086, blue: 0.086),   // #161616
            Color(red: 0.075, green: 0.068, blue: 0.055)    // warm-dark
        ],
        backgroundGradientStart: .topLeading,
        backgroundGradientEnd: .bottomTrailing,
        glowColor: Color(red: 0.79, green: 0.66, blue: 0.30),     // #C9A84C gold
        accentColor: Color(red: 0.60, green: 0.47, blue: 0.19),   // #9A7A30 gold dim
        textColor: Color(red: 0.91, green: 0.88, blue: 0.82),     // #E8E0D0 cream
        secondaryTextColor: Color(red: 0.54, green: 0.50, blue: 0.44).opacity(0.85), // #8A8070 taupe
        separatorColor: Color(red: 0.79, green: 0.66, blue: 0.30).opacity(0.20),
        pulseSpeed: 6.5,
        particleOpacity: 0.18,
        preferredColorScheme: .dark,
        iconType: .compassRose,
        tagline: String(localized: "A quiet word, exactly when you need it."),
        aboutText: String(localized: "One quiet word, placed gently in your day. From Moving Truth — over a thousand quotes drawn from the world's deepest thinkers, delivered with care."),
        featureLabels: [String(localized: "Chosen words"), String(localized: "Your pace"), String(localized: "Held close"), String(localized: "Kept private"), String(localized: "Simply made")]
    )

    /// Deep indigo / silver — calm and contemplative.
    static let moonlit = InfoPageSkin(
        id: "moonlit",
        name: String(localized: "Moonlit"),
        backgroundColors: [
            Color(red: 0.07, green: 0.07, blue: 0.22),
            Color(red: 0.12, green: 0.08, blue: 0.32),
            Color(red: 0.18, green: 0.10, blue: 0.40)
        ],
        backgroundGradientStart: .topLeading,
        backgroundGradientEnd: .bottomTrailing,
        glowColor: Color(red: 0.70, green: 0.72, blue: 0.95),
        accentColor: Color(red: 0.60, green: 0.65, blue: 0.92),
        textColor: .white,
        secondaryTextColor: Color(white: 1.0).opacity(0.60),
        separatorColor: Color(white: 1.0).opacity(0.18),
        pulseSpeed: 5.5,
        particleOpacity: 0.22,
        preferredColorScheme: .dark,
        iconType: .moon,
        tagline: String(localized: "Let stillness speak."),
        aboutText: String(localized: "A daily word from the world's deepest thinkers, arriving in its own time. Gather what resonates. Let the rest pass."),
        featureLabels: [String(localized: "Curated wisdom"), String(localized: "Your schedule"), String(localized: "Held close"), String(localized: "Kept private"), String(localized: "Simply beautiful")]
    )

    /// Forest green / jade — earthy, grounding, organic.
    static let zenGarden = InfoPageSkin(
        id: "zenGarden",
        name: String(localized: "Zen Garden"),
        backgroundColors: [
            Color(red: 0.04, green: 0.14, blue: 0.07),
            Color(red: 0.06, green: 0.20, blue: 0.10),
            Color(red: 0.08, green: 0.28, blue: 0.14)
        ],
        backgroundGradientStart: .top,
        backgroundGradientEnd: .bottom,
        glowColor: Color(red: 0.30, green: 0.78, blue: 0.45),
        accentColor: Color(red: 0.25, green: 0.72, blue: 0.40),
        textColor: Color(red: 0.90, green: 0.98, blue: 0.92),
        secondaryTextColor: Color(red: 0.65, green: 0.85, blue: 0.70).opacity(0.75),
        separatorColor: Color(red: 0.30, green: 0.70, blue: 0.40).opacity(0.20),
        pulseSpeed: 7.0,
        particleOpacity: 0.18,
        preferredColorScheme: .dark,
        iconType: .lotus,
        tagline: String(localized: "Roots. Stillness. Growth."),
        aboutText: String(localized: "Daily wisdom, drawn from the well of human experience. Arrive here, breath by breath, day by day. Some words take root immediately. Others need time."),
        featureLabels: [String(localized: "Tended quotes"), String(localized: "Morning ritual"), String(localized: "Gathered"), String(localized: "Private space"), String(localized: "Natural feel")]
    )

    /// Near-black / warm amber — intimate, cosy, quietly glowing.
    static let emberNight = InfoPageSkin(
        id: "emberNight",
        name: String(localized: "Ember Night"),
        backgroundColors: [
            Color(red: 0.06, green: 0.04, blue: 0.02),
            Color(red: 0.10, green: 0.06, blue: 0.03),
            Color(red: 0.14, green: 0.08, blue: 0.04)
        ],
        backgroundGradientStart: .topLeading,
        backgroundGradientEnd: .bottomTrailing,
        glowColor: Color(red: 0.95, green: 0.55, blue: 0.15),
        accentColor: Color(red: 0.90, green: 0.50, blue: 0.12),
        textColor: Color(red: 0.98, green: 0.92, blue: 0.80),
        secondaryTextColor: Color(red: 0.82, green: 0.72, blue: 0.55).opacity(0.72),
        separatorColor: Color(red: 0.80, green: 0.50, blue: 0.20).opacity(0.20),
        pulseSpeed: 6.0,
        particleOpacity: 0.25,
        preferredColorScheme: .dark,
        iconType: .flame,
        tagline: String(localized: "Something small. Sustained."),
        aboutText: String(localized: "A single ember doesn't demand your attention — it simply glows, patient and warm. One quote. One moment. Yours to keep or release."),
        featureLabels: [String(localized: "Chosen words"), String(localized: "Timed arrival"), String(localized: "Kept warm"), String(localized: "Protected"), String(localized: "Refined")]
    )

    /// Warm grey / cream, light mode — quiet, imperfect, grounded.
    static let wabi = InfoPageSkin(
        id: "wabi",
        name: String(localized: "Wabi"),
        backgroundColors: [
            Color(red: 0.93, green: 0.91, blue: 0.87),
            Color(red: 0.88, green: 0.86, blue: 0.82),
            Color(red: 0.83, green: 0.80, blue: 0.76)
        ],
        backgroundGradientStart: .top,
        backgroundGradientEnd: .bottom,
        glowColor: Color(red: 0.55, green: 0.45, blue: 0.35),
        accentColor: Color(red: 0.50, green: 0.40, blue: 0.30),
        textColor: Color(red: 0.18, green: 0.15, blue: 0.12),
        secondaryTextColor: Color(red: 0.40, green: 0.35, blue: 0.28).opacity(0.80),
        separatorColor: Color(red: 0.40, green: 0.35, blue: 0.28).opacity(0.22),
        pulseSpeed: 8.0,
        particleOpacity: 0.12,
        preferredColorScheme: .light,
        iconType: .enso,
        tagline: String(localized: "Imperfect. Enough."),
        aboutText: String(localized: "Wabi-sabi finds beauty in impermanence and imperfection. This space collects the kind of words that remind you — nothing needs to be perfect to be worth keeping."),
        featureLabels: [String(localized: "Honest words"), String(localized: "Gentle rhythm"), String(localized: "Cherished"), String(localized: "Simple"), String(localized: "Grounded")]
    )

    /// Deep rose / mauve — brief, beautiful, fleeting.
    static let sakura = InfoPageSkin(
        id: "sakura",
        name: String(localized: "Sakura"),
        backgroundColors: [
            Color(red: 0.18, green: 0.06, blue: 0.10),
            Color(red: 0.28, green: 0.08, blue: 0.16),
            Color(red: 0.35, green: 0.10, blue: 0.22)
        ],
        backgroundGradientStart: .topLeading,
        backgroundGradientEnd: .bottomTrailing,
        glowColor: Color(red: 0.95, green: 0.55, blue: 0.72),
        accentColor: Color(red: 0.90, green: 0.48, blue: 0.68),
        textColor: Color(red: 1.00, green: 0.92, blue: 0.95),
        secondaryTextColor: Color(red: 0.88, green: 0.70, blue: 0.78).opacity(0.72),
        separatorColor: Color(red: 0.90, green: 0.55, blue: 0.70).opacity(0.20),
        pulseSpeed: 5.0,
        particleOpacity: 0.20,
        preferredColorScheme: .dark,
        iconType: .cherryBlossom,
        tagline: String(localized: "Brief and beautiful."),
        aboutText: String(localized: "Cherry blossoms don't cling to the branch. Words are delivered the same way — arriving fully, then letting go. What stays with you, stays."),
        featureLabels: [String(localized: "Fleeting wisdom"), String(localized: "Timed release"), String(localized: "Remembered"), String(localized: "Quiet beauty"), String(localized: "Softly made")]
    )

    // MARK: - Catalog

    /// All available skins in display order. Moving Truth is the default (index 0).
    static let all: [InfoPageSkin] = [movingTruth, moonlit, zenGarden, emberNight, wabi, sakura]

    /// Returns the skin matching `id`, falling back to `.movingTruth` when not found.
    static func skin(for id: String) -> InfoPageSkin {
        all.first { $0.id == id } ?? .movingTruth
    }
}
