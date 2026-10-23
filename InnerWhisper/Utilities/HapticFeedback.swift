//
//  HapticFeedback.swift
//  InnerWhisper
//
//  Created for InnerWhisper.
//

import UIKit

/// A utility for providing haptic feedback throughout the app.
///
/// This struct provides a consistent, easy-to-use interface for haptic feedback,
/// making the app more accessible and providing better user experience,
/// especially for users who rely on tactile feedback.
///
/// ## Usage Example
/// ```swift
/// Button("Next") {
///     HapticFeedback.light()
///     goToNext()
/// }
/// ```
struct HapticFeedback {
    /// Provides light impact feedback (e.g., for button taps, navigation).
    static func light() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }

    /// Provides medium impact feedback (e.g., for mode changes, toggles).
    static func medium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }

    /// Provides heavy impact feedback (e.g., for destructive actions).
    static func heavy() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
    }

    /// Provides success feedback (e.g., for completed actions).
    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    /// Provides warning feedback (e.g., for cautionary actions).
    static func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }

    /// Provides error feedback (e.g., for failed actions).
    static func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }

    /// Provides selection changed feedback (e.g., for picker changes).
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}
