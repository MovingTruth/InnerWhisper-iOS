//
//  SnowflakeView.swift
//  InnerWhisper
//

import SwiftUI

/// Animated 3D ice-crystal snowflake — 6 arms with two tiers of branches and a visible disc rim.
///
/// The crystal has real thickness: tilting reveals the icy edge.
/// Idle motion slowly tumbles on X and Y axes; drag to spin freely on any axis.
struct SnowflakeView: View {
    var size: CGFloat = 120

    @State private var rotX: Double = 12
    @State private var rotY: Double = 0
    @State private var vX: Double = Self.idleVX
    @State private var vY: Double = Self.idleVY
    @State private var lastUpdate: Date = .now
    @State private var isDragging: Bool = false
    @State private var lastDragLoc: CGPoint? = nil
    @State private var lastDragTime: Date? = nil

    private static let idleVX: Double = 5
    private static let idleVY: Double = -14
    private static let friction: Double = 0.983
    private static let maxSpeed: Double = 720

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, sz in draw(ctx, canvasSize: sz) }
                .frame(width: size, height: size)
                .shadow(color: Color(red: 0.78, green: 0.90, blue: 0.98, opacity: 0.50),
                        radius: size * 0.16)
                .gesture(flickGesture)
                .onChange(of: timeline.date) { date in tick(to: date) }
        }
        .onAppear { lastUpdate = .now }
    }

    // MARK: - Drawing

    private func draw(_ ctx: GraphicsContext, canvasSize: CGSize) {
        let cx = canvasSize.width  / 2
        let cy = canvasSize.height / 2
        let r  = min(canvasSize.width, canvasSize.height) / 2 * 0.90

        let rx = rotX * .pi / 180.0
        let ry = rotY * .pi / 180.0
        let cX = cos(rx), sX = sin(rx), cY = cos(ry), sY = sin(ry)

        func rot(_ p: SIMD3<Double>) -> SIMD3<Double> {
            SIMD3(
                 p.x * cY + p.y * sX * sY + p.z * cX * sY,
                             p.y * cX       - p.z * sX,
                -p.x * sY + p.y * sX * cY  + p.z * cX * cY
            )
        }
        func proj(_ p: SIMD3<Double>) -> CGPoint {
            CGPoint(x: cx + p.x * r, y: cy - p.y * r)
        }
        // arm-local (u=perp, v=along) → canvas point
        func armPt(_ u: Double, _ v: Double, theta: Double, z: Double) -> CGPoint {
            let cθ = cos(theta), sθ = sin(theta)
            return proj(rot(SIMD3(u * cθ + v * sθ, -u * sθ + v * cθ, z)))
        }

        let t        = 0.10
        let iceBlue  = Color(red: 0.80, green: 0.92, blue: 0.99)
        let iceDim   = Color(red: 0.65, green: 0.82, blue: 0.94)
        let rimColor = Color(red: 0.55, green: 0.75, blue: 0.90)
        let mainW    = max(1.5, r * 0.045)
        let branchW  = max(1.0, r * 0.030)
        let tipW     = max(0.8, r * 0.022)
        let sin60    = sin(Double.pi / 3)
        let cos60    = cos(Double.pi / 3)
        let sinTwig  = sin(Double.pi / 3 * 0.7)
        let cosTwig  = cos(Double.pi / 3 * 0.7)

        let frontVisible = rot(SIMD3(0, 0, 1)).z > 0
        let faceZ        = frontVisible ? t : -t
        let dimFactor    = frontVisible ? 1.0 : 0.65

        // Rim
        let rimSteps = 48
        for i in 0..<rimSteps {
            let a0 = Double(i)     / Double(rimSteps) * 2 * .pi
            let a1 = Double(i + 1) / Double(rimSteps) * 2 * .pi
            let rimNorm = rot(SIMD3(cos((a0 + a1) / 2), sin((a0 + a1) / 2), 0))
            guard rimNorm.z > 0 else { continue }
            let brightness = 0.5 + max(0, rimNorm.z) * 0.5
            var q = Path()
            q.move(to:    proj(rot(SIMD3(cos(a0), sin(a0),  t))))
            q.addLine(to: proj(rot(SIMD3(cos(a1), sin(a1),  t))))
            q.addLine(to: proj(rot(SIMD3(cos(a1), sin(a1), -t))))
            q.addLine(to: proj(rot(SIMD3(cos(a0), sin(a0), -t))))
            q.closeSubpath()
            ctx.fill(q, with: .color(rimColor.opacity(brightness)))
        }

        // Snowflake arms
        let center = proj(rot(SIMD3(0, 0, faceZ)))
        for i in 0..<6 {
            let θ = Double(i) * .pi / 3

            var mainPath = Path()
            mainPath.move(to: center)
            mainPath.addLine(to: armPt(0, 0.92, theta: θ, z: faceZ))
            ctx.stroke(mainPath, with: .color(iceBlue.opacity(dimFactor)), lineWidth: mainW)

            let tiers: [(tFrac: Double, bLen: Double)] = [(0.35, 0.30), (0.60, 0.20)]
            for (tFrac, bLen) in tiers {
                let bBaseV = 0.92 * tFrac
                let bTipV  = bBaseV + bLen * cos60
                for sign: Double in [-1, 1] {
                    let bTipU  = sign * bLen * sin60
                    let bTipPt = armPt(bTipU, bTipV, theta: θ, z: faceZ)
                    var bp = Path()
                    bp.move(to: armPt(0, bBaseV, theta: θ, z: faceZ))
                    bp.addLine(to: bTipPt)
                    ctx.stroke(bp, with: .color(iceDim.opacity(dimFactor)), lineWidth: branchW)

                    let twigLen = bLen * 0.40
                    let tw1Pt = armPt(bTipU + sign * sinTwig * twigLen * 0.7,
                                      bTipV + cosTwig * twigLen * 0.7, theta: θ, z: faceZ)
                    let tw2Pt = armPt(bTipU - sign * sinTwig * twigLen * 0.5,
                                      bTipV + cosTwig * twigLen * 0.5, theta: θ, z: faceZ)
                    var tw1 = Path(); tw1.move(to: bTipPt); tw1.addLine(to: tw1Pt)
                    var tw2 = Path(); tw2.move(to: bTipPt); tw2.addLine(to: tw2Pt)
                    ctx.stroke(tw1, with: .color(iceDim.opacity(dimFactor * 0.70)), lineWidth: tipW)
                    ctx.stroke(tw2, with: .color(iceDim.opacity(dimFactor * 0.70)), lineWidth: tipW)
                }
            }

            let tipPt = armPt(0, 0.92, theta: θ, z: faceZ)
            for sign: Double in [-1, 1] {
                var tb = Path()
                tb.move(to: tipPt)
                tb.addLine(to: armPt(sign * sin60 * 0.12, 0.92 + cos60 * 0.12, theta: θ, z: faceZ))
                ctx.stroke(tb, with: .color(iceBlue.opacity(0.85 * dimFactor)), lineWidth: tipW)
            }
        }

        let dotR = r * 0.055
        ctx.fill(Path(ellipseIn: CGRect(x: center.x - dotR, y: center.y - dotR,
                                        width: dotR * 2, height: dotR * 2)),
                 with: .color(iceBlue))
    }

    // MARK: - Physics

    private func tick(to date: Date) {
        let dt = date.timeIntervalSince(lastUpdate)
        lastUpdate = date
        guard dt > 0, dt < 0.1 else { return }
        if !isDragging {
            let f = pow(Self.friction, dt * 60.0)
            vX *= f; vY *= f
            if abs(vX) < abs(Self.idleVX) * 2 { vX += (Self.idleVX - vX) * min(1.0, dt * 1.5) }
            if abs(vY) < abs(Self.idleVY) * 2 { vY += (Self.idleVY - vY) * min(1.0, dt * 1.5) }
        }
        rotX += vX * dt
        rotY += vY * dt
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
                        let sVY = (value.location.x - prev.x) / dt
                        let sVX = (value.location.y - prev.y) / dt
                        vY = vY * 0.3 + sVY * 0.7
                        vX = vX * 0.3 + sVX * 0.7
                        vX = max(-Self.maxSpeed, min(Self.maxSpeed, vX))
                        vY = max(-Self.maxSpeed, min(Self.maxSpeed, vY))
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

#Preview("Dark bg") {
    ZStack {
        Color(red: 0.06, green: 0.08, blue: 0.14)
        SnowflakeView(size: 160)
    }
    .frame(width: 300, height: 300)
    .preferredColorScheme(.dark)
}

#Preview("Large") {
    ZStack {
        Color(red: 0.04, green: 0.06, blue: 0.12)
        SnowflakeView(size: 220)
    }
    .frame(width: 400, height: 400)
    .preferredColorScheme(.dark)
}
