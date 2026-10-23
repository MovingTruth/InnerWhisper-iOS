//
//  QuoteCardView.swift
//  InnerWhisper
//
//  Created for InnerWhisper.
//

import SwiftUI
import UIKit

/// Displays a single quote's text and author.
///
/// This view is intentionally simple — it only needs a `Quote` value,
/// making it easy to reuse anywhere a quote should be displayed.
///
/// ## Usage
/// ```swift
/// QuoteCardView(quote: myQuote)
/// ```
struct QuoteCardView: View {
    let quote: Quote
    /// When `false`, the card does not attach its own context menu (e.g. when a parent row provides copy, share, and favorites).
    var showContextMenu: Bool = true
    @Environment(\.quoteFont) private var quoteFont

    var body: some View {
        Group {
            if showContextMenu {
                cardContent
                    .contextMenu {
                        Button {
                            UIPasteboard.general.string = quote.shareableText
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        ShareLink(
                            item: quote.shareableText,
                            subject: Text("A whisper from Moving Truth"),
                            message: Text(quote.shareableText)
                        ) {
                            Label("Share Quote", systemImage: "square.and.arrow.up")
                        }
                    }
                    .accessibleGroup(label: "\(quote.text), by \(quote.author)")
                    .environment(\.locale, Locale(identifier: AppLanguage.current.resolvedLanguageCode))
                    .accessibilityHint(String(localized: "Long press to share or copy"))
            } else {
                cardContent
                    .accessibleGroup(label: "\(quote.text), by \(quote.author)")
                    .environment(\.locale, Locale(identifier: AppLanguage.current.resolvedLanguageCode))
            }
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(quote.text)
                .font(quoteFont ?? .title2)
                .multilineTextAlignment(.leading)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal)

            Text("— \(quote.author)")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical)
        .contentShape(Rectangle())
    }
}

// MARK: - Previews

#Preview {
    QuoteCardView(quote: Quote(id: "00000001-0000-4000-a000-000000000000", displayNumber: 1, text: "The only way to do great work is to love what you do.", author: "Steve Jobs"))
        .padding()
}

#Preview("Dark Mode") {
    QuoteCardView(quote: Quote(id: "00000001-0000-4000-a000-000000000000", displayNumber: 1, text: "The only way to do great work is to love what you do.", author: "Steve Jobs"))
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Large Text") {
    QuoteCardView(quote: Quote(id: "00000001-0000-4000-a000-000000000000", displayNumber: 1, text: "The only way to do great work is to love what you do. If you haven't found it yet, keep looking. Don't settle.", author: "Steve Jobs"))
        .padding()
        .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
}
