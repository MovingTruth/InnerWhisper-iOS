//
//  InnerWhisperLogoView.swift
//  InnerWhisper
//
//  Created by Robin O'Brien on 2026-03-12.
//

import SwiftUI

struct InnerWhisperLogoView: View {
    private let text = "Inner Whisper"
    private let captionText = "by MovingTruth.com"

    @State private var rippleStart: Date?       = nil
    @State private var touchNorm:   CGFloat     = 0.5   // tap x as 0…1 across the view
    @State private var viewWidth:   CGFloat     = 130

    // Ripple physics
    private let waveSpeed: Double  = 1.6   // how fast the wave travels (text-widths / s)
    private let frequency: Double  = 7.0   // oscillations per second
    private let damping:   Double  = 4.5   // exponential decay rate
    private let amplitude: CGFloat = 5.0   // peak vertical displacement in pts
    private let duration:  Double  = 0.8   // seconds before ripple resets (wave is fully damped by ~0.7s)

    var body: some View {
        VStack(spacing: 2) {
            lineView(text, font: .title3, italic: true)
            lineView(captionText, font: .caption2, italic: false)
        }
        // Both lines still grow with the user's text-size preference, but capped below the
        // accessibility range: past that, the ripple's per-character HStack (which can't wrap)
        // would run wider than the screen and get clipped by the enclosing ScrollView.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { val in
                    touchNorm   = max(0, min(1, val.location.x / viewWidth))
                    rippleStart = Date()
                }
        )
        // Measure the view width so we can convert tap.x → normalised position.
        .background {
            GeometryReader { geo in
                Color.clear.onAppear { viewWidth = geo.size.width }
            }
        }
        // Automatically clear the ripple state after it has fully damped out.
        .task(id: rippleStart) {
            guard rippleStart != nil else { return }
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            rippleStart = nil
        }
    }

    // MARK: - Private helpers

    /// Renders one line at rest, or rippling with the travelling wave when active.
    @ViewBuilder
    private func lineView(_ line: String, font: Font, italic: Bool) -> some View {
        if let start = rippleStart {
            // Drive per-character offsets from the display clock while rippling.
            TimelineView(.animation) { tl in
                rippleLetters(line, font: font, italic: italic, elapsed: tl.date.timeIntervalSince(start))
            }
            .transition(.identity)   // no cross-fade; swap is imperceptible mid-tap
        } else {
            // At rest, render as a single Text so kerning is pixel-perfect.
            Text(line)
                .font(font)
                .foregroundStyle(.tertiary)
                .italic(italic)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .transition(.identity)
        }
    }

    /// Renders each character of `line` individually so each can be nudged
    /// vertically by the travelling wave at its own arrival time.
    @ViewBuilder
    private func rippleLetters(_ line: String, font: Font, italic: Bool, elapsed: Double) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(line.enumerated()), id: \.offset) { idx, char in
                Text(String(char))
                    .font(font)
                    .foregroundStyle(.tertiary)
                    .italic(italic)
                    .offset(y: waveOffset(charIndex: idx, lineLength: line.count, elapsed: elapsed))
            }
        }
    }

    /// Returns the vertical offset (pts) for character `charIndex` (out of `lineLength`)
    /// at `elapsed` seconds after the tap. The wave radiates from `touchNorm`, reaching each
    /// character after a travel-time proportional to its distance from the tap point. Both
    /// lines share the same `touchNorm`/`elapsed`, so they ripple in sync with each other.
    private func waveOffset(charIndex: Int, lineLength: Int, elapsed: Double) -> CGFloat {
        guard elapsed > 0 else { return 0 }

        let charPos  = Double(charIndex) / Double(max(1, lineLength - 1))  // 0…1
        let distance = abs(charPos - Double(touchNorm))                    // 0…1
        let local    = elapsed - distance / waveSpeed                      // time since wave arrived

        guard local > 0 else { return 0 }

        // Damped sine: full amplitude at arrival, decaying exponentially.
        return CGFloat(sin(local * frequency * .pi * 2) * exp(-local * damping)) * amplitude
    }
}

#Preview {
    VStack(spacing: 32) {
        InnerWhisperLogoView()
        InnerWhisperLogoView()
            .preferredColorScheme(.dark)
    }
    .padding(32)
}
