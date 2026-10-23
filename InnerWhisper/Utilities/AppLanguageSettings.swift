//
//  AppLanguageSettings.swift
//  InnerWhisper
//
//  Created for InnerWhisper.
//

import Foundation

/// The language used for both quote content and the app's own interface
/// (Settings, onboarding, buttons, menus).
///
/// Independent of the iOS system language — users can choose any supported
/// language regardless of their device locale. Quote content updates
/// immediately; interface text updates the next time the app launches,
/// since iOS resolves `Bundle.main`'s localized resources at process start.
enum AppLanguage: String, CaseIterable, Identifiable {
    case systemDefault = "system"
    case english       = "en"
    case spanish       = "es"
    case french        = "fr"
    case german        = "de"
    case japanese      = "ja"
    case portugueseBR  = "pt-BR"
    case russian       = "ru"
    case chineseSimplified = "zh-Hans"
    case arabic        = "ar"
    case korean        = "ko"
    case thai          = "th"

    var id: String { rawValue }

    static let storageKey = "InnerWhisper.QuoteLanguage"

    /// The key iOS uses to resolve which localized resources `Bundle.main` loads at launch.
    private static let appleLanguagesKey = "AppleLanguages"

    /// The language code to use when loading quote files.
    /// If `.systemDefault`, resolves to the system locale if supported, else `"en"`.
    var resolvedLanguageCode: String {
        guard self == .systemDefault else { return rawValue }

        let supportedCodes = Set(AppLanguage.allCases.compactMap {
            $0 == .systemDefault ? nil : $0.rawValue
        })

        for preferred in Locale.preferredLanguages {
            let locale = Locale(identifier: preferred)
            let language = locale.language

            // Exact match — covers a preferred entry that's already fully qualified
            // (e.g. the device list literally contains "pt-BR").
            if supportedCodes.contains(preferred) { return preferred }

            // Chinese needs script/region awareness: deliberately does not fall back
            // Traditional (Hant / TW / HK / MO) to the Simplified we ship — falls
            // through to the next preferred language (and eventually "en") instead,
            // since forcing an unrequested script on a reader is worse than English.
            if language.languageCode?.identifier == "zh" {
                let script = language.script?.identifier
                let region = locale.region?.identifier
                let isSimplified = script == "Hans"
                    || (script == nil && !["TW", "HK", "MO"].contains(region ?? ""))
                if isSimplified, supportedCodes.contains("zh-Hans") { return "zh-Hans" }
                continue
            }

            // Portuguese is region-agnostic — we only ship pt-BR, so any pt-*
            // preference (including pt-PT) resolves to it rather than "en".
            if language.languageCode?.identifier == "pt", supportedCodes.contains("pt-BR") {
                return "pt-BR"
            }

            // Bare language-subtag match for everything else (es-MX -> es, etc.)
            if let bare = language.languageCode?.identifier, supportedCodes.contains(bare) {
                return bare
            }
        }
        return "en"
    }

    /// Human-readable display name, always shown in the language's own script.
    var displayName: String {
        switch self {
        case .systemDefault:       return String(localized: "Match device language")
        case .english:             return "English"
        case .spanish:             return "Español"
        case .french:              return "Français"
        case .german:              return "Deutsch"
        case .japanese:            return "日本語"
        case .portugueseBR:        return "Português"
        case .russian:             return "Русский"
        case .chineseSimplified:   return "简体中文"
        case .arabic:              return "العربية"
        case .korean:              return "한국어"
        case .thai:                return "ไทย"
        }
    }

    /// Reads the current persisted preference. Thread-safe (reads UserDefaults on any thread).
    static var current: AppLanguage {
        let raw = UserDefaults.standard.string(forKey: storageKey) ?? AppLanguage.systemDefault.rawValue
        return AppLanguage(rawValue: raw) ?? .systemDefault
    }

    /// Applies this language as the app's interface-language override.
    ///
    /// Takes effect on the next app launch — iOS resolves `Bundle.main`'s
    /// localized resources against this preference before any of our code runs,
    /// so there is no way to re-localize already-loaded interface strings mid-session.
    func applyAsInterfaceLanguageOverride() {
        if self == .systemDefault {
            UserDefaults.standard.removeObject(forKey: AppLanguage.appleLanguagesKey)
        } else {
            UserDefaults.standard.set([rawValue], forKey: AppLanguage.appleLanguagesKey)
        }
    }
}
