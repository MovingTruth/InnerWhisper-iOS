//
//  EnsoView.swift
//  InnerWhisper
//

import SwiftUI

/// Zen enso — a brushstroke circle, deliberately incomplete.
/// The stroke tapers at both ends to simulate a single brush pass.
/// Rotates very slowly; tap to redraw from scratch.
struct EnsoView: View {
    var size: CGFloat = 120

    /// 0…1 controls how much of the arc is visible (animated on appear and re-tap).
    @State private var drawProgress: Double = 0
    @State private var rotation: Double = 0
    @State private var elapsed: Double = 0
    @State private var lastUpdate: Date = .now

    private static let arcDegrees: Double = 308.0   // gap of 52° at top-right
    private static let idleRotSpeed: Double = 3.2   // degrees per second

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, sz in drawEnso(ctx, canvasSize: sz) }
                .frame(width: size, height: size)
                .shadow(color: Color(red: 0.40, green: 0.35, blue: 0.28, opacity: 0.30),
                        radius: size * 0.10)
                .onChange(of: timeline.date) { date in tick(to: date) }
        }
        .onAppear {
            lastUpdate = .now
            withAnimation(.easeOut(duration: 1.4)) { drawProgress = 1.0 }
        }
        .onTapGesture {
            drawProgress = 0
            withAnimation(.easeOut(duration: 1.2)) { drawProgress = 1.0 }
        }
    }

    // MARK: - Drawing

    private func drawEnso(_ ctx: GraphicsContext, canvasSize: CGSize) {
        let cx = canvasSize.width  / 2
        let cy = canvasSize.height / 2
        let r  = min(canvasSize.width, canvasSize.height) / 2 * 0.76

        let ink       = Color(red: 0.18, green: 0.15, blue: 0.12)
        let strokeMax = r * 0.22
        let segments  = 72
        let startAngle = -120.0 + rotation  // gap sits at top-right

        for i in 0..<segments {
            let tStart = Double(i) / Double(segments)
            let tEnd   = Double(i + 1) / Double(segments)
            guard tStart < drawProgress else { break }
            let tMid = (tStart + tEnd) / 2

            // Taper: thin at start and end, full in the middle
            let taperIn  = min(tMid / 0.10, 1.0)
            let taperOut = min((1.0 - tMid) / 0.08, 1.0)
            let lw = CGFloat(taperIn * taperOut) * strokeMax

            let aDeg  = startAngle + tStart * Self.arcDegrees * drawProgress
            let bDeg  = startAngle + tEnd   * Self.arcDegrees * drawProgress
            var seg = Path()
            seg.addArc(center: CGPoint(x: cx, y: cy), radius: r,
                       startAngle: .degrees(aDeg), endAngle: .degrees(bDeg),
                       clockwise: false)
            ctx.stroke(seg, with: .color(ink.opacity(0.88 + 0.12 * taperIn * taperOut)),
                       style: StrokeStyle(lineWidth: max(0.5, lw), lineCap: .round))
        }
    }

    // MARK: - Physics

    private func tick(to date: Date) {
        let dt = date.timeIntervalSince(lastUpdate)
        lastUpdate = date
        guard dt > 0, dt < 0.1 else { return }
        elapsed += dt
        rotation += Self.idleRotSpeed * dt
    }
}

// MARK: - Previews

#Preview("Wabi bg – Light") {
    ZStack {
        Color(red: 0.93, green: 0.91, blue: 0.87)
        EnsoView(size: 160)
    }
    .frame(width: 300, height: 300)
}

#Preview("Large") {
    ZStack {
        Color(red: 0.88, green: 0.86, blue: 0.82)
        EnsoView(size: 220)
    }
    .frame(width: 400, height: 400)
}
