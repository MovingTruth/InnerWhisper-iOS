//
//  LotusFlowerView.swift
//  InnerWhisper
//

import SwiftUI

/// Animated lotus flower — 8 outer petals and 8 inner petals over a warm gold centre.
/// Idles with a slow serene rotation; drag to spin.
struct LotusFlowerView: View {
    var size: CGFloat = 120

    @State private var rotation: Double = 0
    @State private var angularVelocity: Double = Self.idleSpeed
    @State private var lastUpdate: Date = .now
    @State private var isDragging = false
    @State private var lastDragLoc: CGPoint? = nil
    @State private var lastDragTime: Date? = nil

    private static let idleSpeed: Double = 4.5
    private static let friction:  Double = 0.984
    private static let maxSpeed:  Double = 720.0

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, sz in drawLotus(ctx, canvasSize: sz) }
                .frame(width: size, height: size)
                .shadow(color: Color(red: 0.25, green: 0.72, blue: 0.40, opacity: 0.38),
                        radius: size * 0.13)
                .gesture(flickGesture)
                .onChange(of: timeline.date) { date in tick(to: date) }
        }
        .onAppear { lastUpdate = .now }
    }

    // MARK: - Drawing

    private func drawLotus(_ ctx: GraphicsContext, canvasSize: CGSize) {
        let cx = canvasSize.width  / 2
        let cy = canvasSize.height / 2
        let r  = min(canvasSize.width, canvasSize.height) / 2 * 0.88

        let outerColor  = Color(red: 0.86, green: 0.96, blue: 0.88)
        let innerColor  = Color(red: 0.94, green: 0.99, blue: 0.96)
        let strokeColor = Color(red: 0.25, green: 0.70, blue: 0.40).opacity(0.38)

        var base = ctx
        base.translateBy(x: cx, y: cy)
        base.rotate(by: .init(degrees: rotation))

        // Outer 8 petals
        let outerR = r * 0.90
        for i in 0..<8 {
            var pctx = base
            pctx.rotate(by: .init(radians: Double(i) * .pi / 4))
            let petal = petalPath(length: outerR, halfW: outerR * 0.33)
            pctx.fill(petal, with: .color(outerColor.opacity(0.88)))
            pctx.stroke(petal, with: .color(strokeColor), lineWidth: 0.8)
        }

        // Inner 8 petals, offset 22.5°
        let innerR = r * 0.58
        for i in 0..<8 {
            var pctx = base
            pctx.rotate(by: .init(radians: Double(i) * .pi / 4 + .pi / 8))
            let petal = petalPath(length: innerR, halfW: innerR * 0.30)
            pctx.fill(petal, with: .color(innerColor.opacity(0.92)))
            pctx.stroke(petal, with: .color(strokeColor), lineWidth: 0.7)
        }

        // Gold centre
        let cR = r * 0.17
        let cRect = CGRect(x: -cR, y: -cR, width: cR * 2, height: cR * 2)
        base.fill(Path(ellipseIn: cRect), with: .radialGradient(
            Gradient(colors: [
                Color(red: 0.98, green: 0.94, blue: 0.42),
                Color(red: 0.84, green: 0.72, blue: 0.14)
            ]),
            center: CGPoint(x: -cR * 0.2, y: -cR * 0.2),
            startRadius: 0,
            endRadius: cR
        ))
        base.stroke(Path(ellipseIn: cRect),
                    with: .color(Color(red: 0.60, green: 0.50, blue: 0.08).opacity(0.55)),
                    lineWidth: 0.8)
    }

    /// Petal pointing upward (-y) in local coordinates.
    private func petalPath(length: CGFloat, halfW: CGFloat) -> Path {
        var p = Path()
        p.move(to: .zero)
        p.addCurve(
            to: CGPoint(x: 0, y: -length),
            control1: CGPoint(x:  halfW,        y: -length * 0.28),
            control2: CGPoint(x:  halfW * 0.78, y: -length * 0.72)
        )
        p.addCurve(
            to: .zero,
            control1: CGPoint(x: -halfW * 0.78, y: -length * 0.72),
            control2: CGPoint(x: -halfW,        y: -length * 0.28)
        )
        p.closeSubpath()
        return p
    }

    // MARK: - Physics

    private func tick(to date: Date) {
        let dt = date.timeIntervalSince(lastUpdate)
        lastUpdate = date
        guard dt > 0, dt < 0.1 else { return }
        if !isDragging {
            angularVelocity *= pow(Self.friction, dt * 60)
            if abs(angularVelocity) < abs(Self.idleSpeed) * 2 {
                angularVelocity += (Self.idleSpeed - angularVelocity) * min(1.0, dt * 1.8)
            }
        }
        rotation += angularVelocity * dt
    }

    // MARK: - Gesture

    private var flickGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                isDragging = true
                let now = Date()
                if let prev = lastDragLoc, let prevTime = lastDragTime {
                    let dt = now.timeIntervalSince(prevTime)
                    if dt > 0 {
                        let dv = (value.location.x - prev.x) / dt
                        angularVelocity = angularVelocity * 0.3 + dv * 0.7
                        angularVelocity = max(-Self.maxSpeed, min(Self.maxSpeed, angularVelocity))
                    }
                }
                lastDragLoc  = value.location
                lastDragTime = now
                lastUpdate   = now
            }
            .onEnded { _ in
                isDragging   = false
                lastDragLoc  = nil
                lastDragTime = nil
            }
    }
}

// MARK: - Previews

#Preview("Zen Garden bg") {
    ZStack {
        Color(red: 0.06, green: 0.20, blue: 0.10)
        LotusFlowerView(size: 160)
    }
    .frame(width: 300, height: 300)
    .preferredColorScheme(.dark)
}

#Preview("Large") {
    ZStack {
        Color(red: 0.04, green: 0.14, blue: 0.07)
        LotusFlowerView(size: 220)
    }
    .frame(width: 400, height: 400)
    .preferredColorScheme(.dark)
}
