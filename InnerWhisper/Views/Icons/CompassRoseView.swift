//
//  CompassRoseView.swift
//  InnerWhisper
//

import SwiftUI

/// Animated 3D compass rose — 4 cardinal and 4 intercardinal gold diamond points on a disc.
///
/// Horizontal drag spins the face; vertical drag tilts it forward.
/// The visible rim reveals real disc depth when the rose is tilted.
struct CompassRoseView: View {
    var size: CGFloat = 120

    @State private var spin: Double = 0       // Z-axis rotation of compass face (degrees)
    @State private var rotX: Double = 20      // forward/back tilt
    @State private var vSpin: Double = Self.idleVSpin
    @State private var vX: Double = 0
    @State private var lastUpdate: Date = .now
    @State private var isDragging: Bool = false
    @State private var lastDragLoc: CGPoint? = nil
    @State private var lastDragTime: Date? = nil

    private static let idleVSpin: Double = 10.0
    private static let friction:  Double = 0.982
    private static let maxSpeed:  Double = 720.0

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, sz in drawRose(ctx, canvasSize: sz) }
                .frame(width: size, height: size)
                .shadow(color: Color(red: 0.79, green: 0.66, blue: 0.30, opacity: 0.50),
                        radius: size * 0.14)
                .gesture(flickGesture)
                .onChange(of: timeline.date) { date in tick(to: date) }
        }
        .onAppear { lastUpdate = .now }
    }

    // MARK: - Drawing

    private func drawRose(_ ctx: GraphicsContext, canvasSize: CGSize) {
        let cx = canvasSize.width  / 2
        let cy = canvasSize.height / 2
        let r  = min(canvasSize.width, canvasSize.height) / 2 * 0.90

        // Only X-axis tilt (disc tilts forward/back; spin is around disc normal)
        let rx = rotX * .pi / 180.0
        let cX = cos(rx), sX = sin(rx)

        func rot(_ p: SIMD3<Double>) -> SIMD3<Double> {
            // Ry=0, so simplified Rx only
            SIMD3(p.x, p.y * cX - p.z * sX, p.y * sX + p.z * cX)
        }
        func proj(_ p: SIMD3<Double>) -> CGPoint {
            CGPoint(x: cx + p.x * r, y: cy - p.y * r)
        }

        let gold    = Color(red: 0.79, green: 0.66, blue: 0.30)
        let goldDim = Color(red: 0.55, green: 0.44, blue: 0.18)
        let cream   = Color(red: 0.91, green: 0.88, blue: 0.82)
        let rimGold = Color(red: 0.62, green: 0.50, blue: 0.20)
        let t       = 0.08   // half-thickness

        let frontVisible = rot(SIMD3(0, 0, 1)).z > 0
        let faceZ        = frontVisible ? t : -t
        let dimFactor    = frontVisible ? 1.0 : 0.60

        // Rim
        let rimSteps = 48
        for i in 0..<rimSteps {
            let a0 = Double(i)     / Double(rimSteps) * 2 * .pi
            let a1 = Double(i + 1) / Double(rimSteps) * 2 * .pi
            let midAngle = (a0 + a1) / 2
            let rimNorm = rot(SIMD3(cos(midAngle), sin(midAngle), 0))
            guard rimNorm.z > 0 else { continue }
            let brightness = 0.45 + max(0, rimNorm.z) * 0.55
            var q = Path()
            q.move(to:    proj(rot(SIMD3(cos(a0), sin(a0),  t))))
            q.addLine(to: proj(rot(SIMD3(cos(a1), sin(a1),  t))))
            q.addLine(to: proj(rot(SIMD3(cos(a1), sin(a1), -t))))
            q.addLine(to: proj(rot(SIMD3(cos(a0), sin(a0), -t))))
            q.closeSubpath()
            ctx.fill(q, with: .color(rimGold.opacity(brightness)))
        }

        // Guide ring (outer) — approximate ellipse by sampling
        let ringSteps = 64
        var outerRing = Path()
        for i in 0...ringSteps {
            let a = Double(i) / Double(ringSteps) * 2 * .pi
            let pt = proj(rot(SIMD3(cos(a), sin(a), faceZ)))
            if i == 0 { outerRing.move(to: pt) } else { outerRing.addLine(to: pt) }
        }
        outerRing.closeSubpath()
        ctx.stroke(outerRing, with: .color(gold.opacity(0.22 * dimFactor)), lineWidth: 0.8)

        var midRing = Path()
        for i in 0...ringSteps {
            let a = Double(i) / Double(ringSteps) * 2 * .pi
            let pt = proj(rot(SIMD3(cos(a) * 0.46, sin(a) * 0.46, faceZ)))
            if i == 0 { midRing.move(to: pt) } else { midRing.addLine(to: pt) }
        }
        midRing.closeSubpath()
        ctx.stroke(midRing, with: .color(gold.opacity(0.14 * dimFactor)), lineWidth: 0.5)

        // 8 diamond points
        let spinRad = spin * .pi / 180.0
        for i in 0..<8 {
            let θ = Double(i) * .pi / 4 + spinRad
            let st = sin(θ), ct = cos(θ)
            let isCardinal = i % 2 == 0
            let outerR = isCardinal ? 0.93 : 0.59
            let innerR = isCardinal ? 0.14 : 0.20
            let halfW  = isCardinal ? 0.14 : 0.09
            let midR   = (outerR + innerR) / 2

            // Diamond vertices in 3D (XY = disc plane)
            let vTip   = proj(rot(SIMD3(st * outerR,               ct * outerR,              faceZ)))
            let vLeft  = proj(rot(SIMD3(st * midR + ct * halfW,    ct * midR - st * halfW,   faceZ)))
            let vInner = proj(rot(SIMD3(st * innerR,               ct * innerR,              faceZ)))
            let vRight = proj(rot(SIMD3(st * midR - ct * halfW,    ct * midR + st * halfW,   faceZ)))

            var diamond = Path()
            diamond.move(to: vTip)
            diamond.addLine(to: vLeft)
            diamond.addLine(to: vInner)
            diamond.addLine(to: vRight)
            diamond.closeSubpath()

            let fillColor = isCardinal ? gold : goldDim
            ctx.fill(diamond, with: .color(fillColor.opacity(dimFactor)))
            ctx.stroke(diamond, with: .color(gold.opacity(0.28 * dimFactor)), lineWidth: 0.5)
        }

        // Centre circle
        let cR = r * 0.11
        let cPt = proj(rot(SIMD3(0, 0, faceZ)))
        let cRect = CGRect(x: cPt.x - cR, y: cPt.y - cR, width: cR * 2, height: cR * 2)
        ctx.fill(Path(ellipseIn: cRect), with: .color(cream.opacity(dimFactor)))
        ctx.stroke(Path(ellipseIn: cRect), with: .color(gold.opacity(dimFactor)), lineWidth: 1.2)
    }

    // MARK: - Physics

    private func tick(to date: Date) {
        let dt = date.timeIntervalSince(lastUpdate)
        lastUpdate = date
        guard dt > 0, dt < 0.1 else { return }
        if !isDragging {
            let f = pow(Self.friction, dt * 60)
            vSpin *= f
            vX    *= f
            if abs(vSpin) < abs(Self.idleVSpin) * 2 {
                vSpin += (Self.idleVSpin - vSpin) * min(1.0, dt * 1.8)
            }
            vX += (0 - vX) * min(1.0, dt * 0.6)   // tilt drifts back to 0
        }
        spin  += vSpin * dt
        rotX  += vX    * dt
        rotX = max(-75, min(75, rotX))   // clamp tilt so rose stays visible
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
                        let dSpin = (value.location.x - prev.x) / dt
                        let dX    = (value.location.y - prev.y) / dt
                        vSpin = vSpin * 0.3 + dSpin * 0.7
                        vX    = vX    * 0.3 + dX    * 0.7
                        vSpin = max(-Self.maxSpeed, min(Self.maxSpeed, vSpin))
                        vX    = max(-Self.maxSpeed, min(Self.maxSpeed, vX))
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

#Preview("Moving Truth bg") {
    ZStack {
        Color(red: 0.051, green: 0.051, blue: 0.051)
        CompassRoseView(size: 160)
    }
    .frame(width: 300, height: 300)
    .preferredColorScheme(.dark)
}

#Preview("Large") {
    ZStack {
        Color(red: 0.06, green: 0.05, blue: 0.04)
        CompassRoseView(size: 220)
    }
    .frame(width: 400, height: 400)
    .preferredColorScheme(.dark)
}
