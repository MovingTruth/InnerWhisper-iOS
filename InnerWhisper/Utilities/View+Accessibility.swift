//
//  View+Accessibility.swift
//  InnerWhisper
//
//  Created for InnerWhisper.
//

import SwiftUI

/// Convenience extensions for common accessibility patterns.
///
/// These extensions provide reusable, semantic methods for adding accessibility
/// features to SwiftUI views, ensuring consistent and comprehensive support
/// for vision-impaired users.
///
/// ## Usage Example
/// ```swift
/// Button("Save") {
///     save()
/// }
/// .accessibleButton(
///     label: "Save document",
///     hint: "Double tap to save your changes to the cloud"
/// )
/// ```
extension View {
    /// Configures a button with proper accessibility label and hint.
    ///
    /// Use this modifier for all interactive buttons to ensure VoiceOver users
    /// understand the button's purpose and action.
    ///
    /// - Parameters:
    ///   - label: Clear description of what the button is (required)
    ///   - hint: Description of what happens when activated (optional)
    /// - Returns: The modified view with accessibility configuration
    func accessibleButton(label: String, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isButton)
            .modifier(AccessibilityHintModifier(hint: hint))
    }

    /// Configures static text content with proper accessibility.
    ///
    /// Use this for text that doesn't change frequently and isn't interactive.
    ///
    /// - Parameter label: Description of the text content
    /// - Returns: The modified view with accessibility configuration
    func accessibleStaticText(label: String) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isStaticText)
    }

    /// Marks an element as a heading for VoiceOver navigation.
    ///
    /// Use this for section headers and titles to help users navigate
    /// the screen hierarchy efficiently.
    ///
    /// - Parameter label: The heading text
    /// - Returns: The modified view with heading trait
    func accessibleHeading(label: String) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isHeader)
    }

    /// Hides decorative elements from accessibility.
    ///
    /// Use this for purely visual elements (decorative images, spacers, etc.)
    /// that don't convey meaningful information.
    ///
    /// - Returns: The modified view hidden from VoiceOver
    func accessibleDecorative() -> some View {
        self.accessibilityHidden(true)
    }

    /// Groups child elements and provides a combined accessibility label.
    ///
    /// Use this to combine related elements (like quote text + author)
    /// into a single semantic unit for VoiceOver.
    ///
    /// - Parameter label: The combined label for all child elements
    /// - Returns: The modified view with combined accessibility
    func accessibleGroup(label: String) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
    }
    
    /// Conditionally applies a transformation to the view.
    ///
    /// - Parameters:
    ///   - condition: Whether to apply the transformation
    ///   - transform: The transformation to apply if condition is true
    /// - Returns: The modified view if condition is true, otherwise the original view
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

}

/// Private helper modifier for adding hints conditionally.
private struct AccessibilityHintModifier: ViewModifier {
    let hint: String?

    func body(content: Content) -> some View {
        if let hint = hint {
            content.accessibilityHint(hint)
        } else {
            content
        }
    }
}
