//
//  FlameView.swift
//  InnerWhisper
//

import SwiftUI

/// Animated flickering flame — three bezier layers (amber outer, orange mid, yellow core).
/// Drag horizontally to blow the flame sideways; it recovers on release.
struct FlameView: View {
    var size: CGFloat = 120

    @State private var elapsed: Double = 0
    @State private var blowX: Double = 0          // horizontal push from drag, decays to 0
    @State private var lastUpdate: Date = .now
    @State private var lastDragLoc: CGPoint? = nil
    @State private var lastDragTime: Date? = nil

    private static let blowFriction: Double = 0.972

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, sz in drawFlame(ctx, canvasSize: sz) }
                .frame(width: size, height: size)
                .shadow(color: Color(red: 0.95, green: 0.55, blue: 0.15, opacity: 0.55),
                        radius: size * 0.18)
                .shadow(color: Color(red: 0.95, green: 0.55, blue: 0.15, opacity: 0.25),
                        radius: size * 0.35)
                .gesture(blowGesture)
                .onChange(of: timeline.date) { date in tick(to: date) }
        }
        .onAppear { lastUpdate = .now }
    }

    // MARK: - Drawing

    private func drawFlame(_ ctx: GraphicsContext, canvasSize: CGSize) {
        let cx = canvasSize.width  / 2
        let cy = canvasSize.height * 0.82   // base sits at 82% down
        let r  = min(canvasSize.width, canvasSize.height) / 2 * 0.78

        // Layer params: (height factor, base width factor, color, wobble intensity)
        let layers: [(CGFloat, CGFloat, Color, Double)] = [
            (1.70, 0.68, Color(red: 0.76, green: 0.28, blue: 0.05), 1.00),
            (1.30, 0.50, Color(red: 0.96, green: 0.52, blue: 0.10), 0.72),
            (0.82, 0.32, Color(red: 1.00, green: 0.88, blue: 0.32), 0.40),
            (0.44, 0.18, Color(red: 1.00, green: 0.97, blue: 0.82), 0.20),
        ]

        for (heightF, widthF, color, wobble) in layers {
            let path = flamePath(
                cx: cx, cy: cy,
                height: r * heightF,
                baseW:  r * widthF,
                time:   elapsed,
                wobble: wobble,
                blowX:  CGFloat(blowX) * r * 0.30
            )
            ctx.fill(path, with: .color(color))
        }
    }

    private func flamePath(cx: CGFloat, cy: CGFloat, height: CGFloat,
                            baseW: CGFloat, time: Double, wobble: Double,
                            blowX: CGFloat) -> Path {
        let w1 = CGFloat(sin(time * 2.3)        * wobble * 7.0) + blowX * 0.55
        let w2 = CGFloat(sin(time * 3.1 + 1.4)  * wobble * 5.5) + blowX * 0.38
        let w3 = CGFloat(sin(time * 1.7 + 2.6)  * wobble * 4.0) + blowX * 0.25
        let tipX = cx + w1 * 1.05
        let tipY = cy - height

        var p = Path()
        p.move(to: CGPoint(x: cx - baseW, y: cy))
        p.addCurve(
            to: CGPoint(x: tipX, y: tipY),
            control1: CGPoint(x: cx - baseW * 0.55 + w2 * 0.5, y: cy - height * 0.32),
            control2: CGPoint(x: tipX - baseW * 0.28 + w3,      y: cy - height * 0.70)
        )
        p.addCurve(
            to: CGPoint(x: cx + baseW, y: cy),
            control1: CGPoint(x: tipX + baseW * 0.28 + w3,      y: cy - height * 0.70),
            control2: CGPoint(x: cx + baseW * 0.55 + w2 * 0.5, y: cy - height * 0.32)
        )
        p.closeSubpath()
        return p
    }

    // MARK: - Physics

    private func tick(to date: Date) {
        let dt = date.timeIntervalSince(lastUpdate)
        lastUpdate = date
        guard dt > 0, dt < 0.1 else { return }
        elapsed += dt
        blowX *= pow(Self.blowFriction, dt * 60)
    }

    // MARK: - Gesture

    private var blowGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                let now = Date()
                if let prev = lastDragLoc, let prevTime = lastDragTime {
                    let dt = now.timeIntervalSince(prevTime)
                    if dt > 0 {
                        let dv = Double(value.location.x - prev.x) / dt
                        blowX = blowX * 0.4 + dv * 0.6
                        blowX = max(-60, min(60, blowX))
                    }
                }
                lastDragLoc  = value.location
                lastDragTime = now
            }
            .onEnded { _ in
                lastDragLoc  = nil
                lastDragTime = nil
            }
    }
}

// MARK: - Previews

#Preview("Ember Night bg") {
    ZStack {
        Color(red: 0.06, green: 0.04, blue: 0.02)
        FlameView(size: 160)
    }
    .frame(width: 300, height: 300)
    .preferredColorScheme(.dark)
}

#Preview("Large") {
    ZStack {
        Color(red: 0.06, green: 0.04, blue: 0.02)
        FlameView(size: 220)
    }
    .frame(width: 400, height: 400)
    .preferredColorScheme(.dark)
}
