//
//  Environment+QuoteFont.swift
//  InnerWhisper
//
//  Created for InnerWhisper.
//

import SwiftUI

// MARK: - Quote font environment key

private struct QuoteFontKey: EnvironmentKey {
    static let defaultValue: Font? = nil
}

extension EnvironmentValues {
    /// Font used for the main quote text. Nil means use the view default (.title2).
    var quoteFont: Font? {
        get { self[QuoteFontKey.self] }
        set { self[QuoteFontKey.self] = newValue }
    }
}

// MARK: - Quote theme style environment key

private struct QuoteThemeStyleKey: EnvironmentKey {
    static let defaultValue: QuoteThemeStyle? = nil
}

extension EnvironmentValues {
    /// Resolved theme style so child views can render theme-driven UI (e.g. the decorative icon).
    /// Nil means use fallback defaults.
    var quoteThemeStyle: QuoteThemeStyle? {
        get { self[QuoteThemeStyleKey.self] }
        set { self[QuoteThemeStyleKey.self] = newValue }
    }
}
