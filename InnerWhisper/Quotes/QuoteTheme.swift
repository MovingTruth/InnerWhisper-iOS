//
//  QuoteTheme.swift
//  InnerWhisper
//
//  Created for InnerWhisper.
//

import Foundation
import SwiftUI

// MARK: - Theme background

/// How a theme draws its background: solid color, gradient, or image from resources.
enum ThemeBackground {
    case color(Color)
    case gradient(colors: [Color], startPoint: UnitPoint, endPoint: UnitPoint)
    case image(assetName: String)
    case custom(AnyView)
}

// MARK: - Theme background view

/// Renders a `ThemeBackground` as a full-bleed SwiftUI view.
struct ThemeBackgroundView: View {
    let background: ThemeBackground

    var body: some View {
        switch background {
        case .color(let color):
            color
                .ignoresSafeArea()
        case .gradient(let colors, let startPoint, let endPoint):
            LinearGradient(colors: colors, startPoint: startPoint, endPoint: endPoint)
                .ignoresSafeArea()
        case .image(let assetName):
            Image(assetName)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
        case .custom(let customView):
            customView
                .ignoresSafeArea()
        }
    }
}

// MARK: - Theme icon

/// How a theme draws its decorative icon: SF Symbol, image from resources, or a custom SwiftUI view.
enum ThemeIcon {
    case systemImage(String)
    case image(assetName: String)
    /// A factory that receives the requested icon size and returns the view to display.
    case custom((CGFloat) -> AnyView)
}

// MARK: - Theme icon view

/// Renders a `ThemeIcon` at a consistent size (e.g. for the quote header).
struct ThemeIconView: View {
    let icon: ThemeIcon
    var size: CGFloat = 155

    var body: some View {
        Group {
            switch icon {
            case .systemImage(let name):
                Image(systemName: name)
                    .font(.system(size: size))
                    .imageScale(.large)
                    .foregroundStyle(.primary)
            case .image(let assetName):
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            case .custom(let factory):
                factory(size)
            }
        }
        .accessibleDecorative()
    }
}

// MARK: - Theme style

/// The resolved visual and audio style applied to the quote screen.
/// Built from the user's independent background, icon, and sound selections.
struct QuoteThemeStyle {
    var background: ThemeBackground
    var icon: ThemeIcon
    var quoteFont: Font
    /// Notification sound: "default" for system default, or a bundle filename (e.g. "chime.caf").
    var defaultNotificationSoundIdentifier: String
    /// When non-nil, content uses this color scheme for contrast on the background.
    var preferredColorScheme: ColorScheme?
    /// Explicit foreground color for text. When nil, uses system default based on color scheme.
    var foregroundColor: Color?
}

// MARK: - Background catalog

/// All available backgrounds, selectable independently of icon and sound.
///
/// To add a new background:
/// 1. Add a case with a descriptive rawValue.
/// 2. Add its `displayName`, `background`, `preferredColorScheme`, and `foregroundColor` below.
enum AppBackground: String, CaseIterable, Identifiable {
    case systemGrouped
    case space
    case aurora
    case forest
    case sportGreen
    case lunarDark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .systemGrouped: return String(localized: "Neutral")
        case .space:         return String(localized: "Space")
        case .aurora:        return String(localized: "Aurora")
        case .forest:        return String(localized: "Forest")
        case .sportGreen:    return String(localized: "Sport")
        case .lunarDark:     return String(localized: "Lunar")
        }
    }

    var background: ThemeBackground {
        switch self {
            case .systemGrouped:
                return .color(Color(.systemGroupedBackground))
            case .space:
                //            return .gradient(
                //                colors: [Color(red: 0.03, green: 0.03, blue: 0.18),
                //                         Color(red: 0.07, green: 0.04, blue: 0.28)],
                //                startPoint: .topLeading, endPoint: .bottomTrailing
                //            )
                return .custom(AnyView(AnimatedSpaceBackground()))
            case .aurora:
                return .custom(AnyView(AnimatedAuroraBackground()))
            case .forest:
                return .custom(AnyView(AnimatedForestBackground()))
            case .sportGreen:
                return .gradient(
                    colors: [Color(red: 0.18, green: 0.42, blue: 0.12),
                             Color(red: 0.10, green: 0.28, blue: 0.08)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            case .lunarDark:
                return .gradient(
                    colors: [Color(red: 0.04, green: 0.04, blue: 0.14),
                             Color(red: 0.08, green: 0.06, blue: 0.20)],
                    startPoint: .top, endPoint: .bottom
                )
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .systemGrouped: return nil
        default:             return .dark
        }
    }

    var foregroundColor: Color? {
        switch self {
        case .systemGrouped: return nil
        case .lunarDark:     return Color(white: 0.90)
        default:             return .white
        }
    }
}

// MARK: - Icon catalog

/// All available decorative icons, selectable independently of background and sound.
///
/// To add a new icon:
/// 1. Add a case with a descriptive rawValue.
/// 2. Add its `displayName` and `icon` factory below.
enum AppIcon: String, CaseIterable, Identifiable {
    case yinYang
    case space
    case soccerBall
    case moon
    case gem
    case leaf
    case rubiksCube
    case compassRose
    case lotus
    case flame
    case enso
    case cherryBlossom
    case waterDroplet
    case snowflake

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .yinYang:      return String(localized: "Yin Yang")
        case .space:        return String(localized: "Space")
        case .soccerBall:   return String(localized: "Soccer Ball")
        case .moon:         return String(localized: "Moon")
        case .gem:          return String(localized: "Gem")
        case .leaf:         return String(localized: "Leaf")
        case .rubiksCube:   return String(localized: "Rubik's Cube")
        case .compassRose:  return String(localized: "Compass Rose")
        case .lotus:        return String(localized: "Lotus")
        case .flame:        return String(localized: "Flame")
        case .enso:         return String(localized: "Ensō")
        case .cherryBlossom: return String(localized: "Cherry Blossom")
        case .waterDroplet: return String(localized: "Water Droplet")
        case .snowflake:    return String(localized: "Snowflake")
        }
    }

    var icon: ThemeIcon {
        switch self {
        case .yinYang:      return .custom({ size in AnyView(YinYangView(size: size)) })
        case .space:        return .custom({ size in AnyView(StarView(size: size, spikeCount: 24)) })
        case .soccerBall:   return .custom({ size in AnyView(SoccerBallView(size: size)) })
        case .moon:         return .custom({ size in AnyView(MoonView(size: size)) })
        case .gem:          return .custom({ size in AnyView(GemView(size: size, pointCount: 8)) })
        case .leaf:         return .custom({ size in AnyView(LeafView(size: size)) })
        case .rubiksCube:   return .custom({ size in AnyView(RubiksCubeView(size: size)) })
        case .compassRose:  return .custom({ size in AnyView(CompassRoseView(size: size)) })
        case .lotus:        return .custom({ size in AnyView(LotusFlowerView(size: size)) })
        case .flame:        return .custom({ size in AnyView(FlameView(size: size)) })
        case .enso:         return .custom({ size in AnyView(EnsoView(size: size)) })
        case .cherryBlossom: return .custom({ size in AnyView(CherryBlossomView(size: size)) })
        case .waterDroplet: return .custom({ size in AnyView(WaterDropletView(size: size)) })
        case .snowflake:    return .custom({ size in AnyView(SnowflakeView(size: size)) })
        }
    }
}

// MARK: - Sound catalog

/// All available notification sounds, selectable independently of background and icon.
///
/// To add a new sound:
/// 1. Add the .caf (or .wav) file to the app bundle.
/// 2. Add a case whose rawValue matches the bundle filename (e.g. `case chime = "chime.caf"`).
/// 3. Add its `displayName` below.
///
/// The special rawValue `"default"` always resolves to the system notification sound.
enum AppSound: String, CaseIterable, Identifiable {
    case `default` = "default"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .default: return String(localized: "Default")
        }
    }

    /// The identifier passed to `UNNotificationSound` / `NotificationManager`.
    var soundIdentifier: String { rawValue }

    /// Raw values removed from the catalog; users who still have one in `UserDefaults` are migrated to default.
    private static let retiredRawValues: Set<String> = [
        "soft-bell-low.mp3",
        "soft-bell-high.mp3",
        "soft-bell-ding-dong.mp3",
        "singing-bowl-resonant.mp3",
        "temple-bowl.mp3",
    ]

    /// Call once at launch so `AppStorage` and notification scheduling never reference removed sounds.
    static func migrateRetiredSoundsIfNeeded() {
        let key = "InnerWhisper.SelectedSound"
        guard let raw = UserDefaults.standard.string(forKey: key),
              retiredRawValues.contains(raw) else { return }
        UserDefaults.standard.set(AppSound.default.rawValue, forKey: key)
    }
}
