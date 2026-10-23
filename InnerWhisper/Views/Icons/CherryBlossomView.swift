//
//  CherryBlossomView.swift
//  InnerWhisper
//

import SwiftUI

/// Animated cherry blossom — 5 heart-notched pink petals with cream stamens.
/// Idles with a gentle rotation; drag to spin.
struct CherryBlossomView: View {
    var size: CGFloat = 120

    @State private var rotation: Double = 0
    @State private var angularVelocity: Double = Self.idleSpeed
    @State private var lastUpdate: Date = .now
    @State private var isDragging = false
    @State private var lastDragLoc: CGPoint? = nil
    @State private var lastDragTime: Date? = nil

    private static let idleSpeed: Double = 5.5
    private static let friction:  Double = 0.983
    private static let maxSpeed:  Double = 720.0

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, sz in drawBlossom(ctx, canvasSize: sz) }
                .frame(width: size, height: size)
                .shadow(color: Color(red: 0.90, green: 0.48, blue: 0.68, opacity: 0.45),
                        radius: size * 0.14)
                .gesture(flickGesture)
                .onChange(of: timeline.date) { date in tick(to: date) }
        }
        .onAppear { lastUpdate = .now }
    }

    // MARK: - Drawing

    private func drawBlossom(_ ctx: GraphicsContext, canvasSize: CGSize) {
        let cx = canvasSize.width  / 2
        let cy = canvasSize.height / 2
        let r  = min(canvasSize.width, canvasSize.height) / 2 * 0.88

        let petalFill   = Color(red: 0.95, green: 0.75, blue: 0.82)
        let petalDeep   = Color(red: 0.88, green: 0.60, blue: 0.72)
        let petalStroke = Color(red: 0.72, green: 0.34, blue: 0.52).opacity(0.40)
        let stamenColor = Color(red: 1.00, green: 0.94, blue: 0.74)

        var base = ctx
        base.translateBy(x: cx, y: cy)
        base.rotate(by: .init(degrees: rotation))

        let petalR = r * 0.88
        let halfW  = petalR * 0.42

        // 5 petals at 72° intervals
        for i in 0..<5 {
            var pctx = base
            pctx.rotate(by: .init(radians: Double(i) * 2 * .pi / 5))
            let petal = cherryPetalPath(length: petalR, halfW: halfW)

            // Radial gradient: lighter centre, deeper edge
            pctx.fill(petal, with: .radialGradient(
                Gradient(colors: [petalFill, petalDeep]),
                center: CGPoint(x: 0, y: -petalR * 0.30),
                startRadius: petalR * 0.08,
                endRadius:   petalR * 0.95
            ))
            pctx.stroke(petal, with: .color(petalStroke), lineWidth: 0.8)
        }

        // Centre dot
        let cR = r * 0.10
        let cRect = CGRect(x: -cR, y: -cR, width: cR * 2, height: cR * 2)
        base.fill(Path(ellipseIn: cRect), with: .color(Color(red: 0.98, green: 0.88, blue: 0.55)))

        // Stamens: 8 short lines ending in tiny dots
        let stamenLen = r * 0.28
        let dotR = r * 0.028
        for i in 0..<8 {
            let θ = Double(i) * .pi / 4
            let ex = CGFloat(sin(θ)) * stamenLen
            let ey = CGFloat(-cos(θ)) * stamenLen
            var seg = Path()
            seg.move(to: .zero)
            seg.addLine(to: CGPoint(x: ex, y: ey))
            base.stroke(seg, with: .color(stamenColor.opacity(0.80)), lineWidth: 0.8)
            let dRect = CGRect(x: ex - dotR, y: ey - dotR, width: dotR * 2, height: dotR * 2)
            base.fill(Path(ellipseIn: dRect), with: .color(stamenColor))
        }
    }

    /// Cherry blossom petal pointing upward (-y) with a small notch at the tip.
    private func cherryPetalPath(length: CGFloat, halfW: CGFloat) -> Path {
        let notch = length * 0.09
        var p = Path()
        p.move(to: .zero)
        // Left curve up to left lobe
        p.addCurve(
            to: CGPoint(x: -halfW * 0.18, y: -(length - notch)),
            control1: CGPoint(x: -halfW * 0.92, y: -length * 0.20),
            control2: CGPoint(x: -halfW * 0.72, y: -(length - notch) * 0.84)
        )
        // Left lobe to notch centre
        p.addCurve(
            to: CGPoint(x: 0, y: -(length - notch * 0.5)),
            control1: CGPoint(x: -halfW * 0.14, y: -(length - notch * 0.28)),
            control2: CGPoint(x: -halfW * 0.05, y: -(length - notch * 0.58))
        )
        // Notch centre to right lobe
        p.addCurve(
            to: CGPoint(x: halfW * 0.18, y: -(length - notch)),
            control1: CGPoint(x: halfW * 0.05, y: -(length - notch * 0.58)),
            control2: CGPoint(x: halfW * 0.14, y: -(length - notch * 0.28))
        )
        // Right curve back to base
        p.addCurve(
            to: .zero,
            control1: CGPoint(x: halfW * 0.72, y: -(length - notch) * 0.84),
            control2: CGPoint(x: halfW * 0.92, y: -length * 0.20)
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

#Preview("Sakura bg") {
    ZStack {
        Color(red: 0.28, green: 0.08, blue: 0.16)
        CherryBlossomView(size: 160)
    }
    .frame(width: 300, height: 300)
    .preferredColorScheme(.dark)
}

#Preview("Large") {
    ZStack {
        Color(red: 0.18, green: 0.06, blue: 0.10)
        CherryBlossomView(size: 220)
    }
    .frame(width: 400, height: 400)
    .preferredColorScheme(.dark)
}
