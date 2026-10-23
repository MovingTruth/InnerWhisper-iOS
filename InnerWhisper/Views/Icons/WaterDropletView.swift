//
//  WaterDropletView.swift
//  InnerWhisper
//

import SwiftUI

/// Animated 3D water sphere — a glass globe that can be spun in any direction.
///
/// Caustic light patterns orbit the sphere's surface as it rotates, giving a sense
/// of light refracting through water. Ripple rings expand outward beneath it.
/// Drag to spin; friction decays back to a gentle idle tumble.
struct WaterDropletView: View {
    var size: CGFloat = 120

    @State private var rotX: Double = 10
    @State private var rotY: Double = 0
    @State private var vX: Double = Self.idleVX
    @State private var vY: Double = Self.idleVY
    @State private var ripplePhase: Double = 0
    @State private var lastUpdate: Date = .now
    @State private var isDragging: Bool = false
    @State private var lastDragLoc: CGPoint? = nil
    @State private var lastDragTime: Date? = nil

    private static let idleVX: Double = 8
    private static let idleVY: Double = -20
    private static let friction: Double = 0.981
    private static let maxSpeed: Double = 720

    // Caustic centres on unit sphere (roughly evenly distributed)
    private let causticPoles: [SIMD3<Double>] = [
        SIMD3( 0.40,  0.60,  0.69),
        SIMD3(-0.55, -0.10,  0.83),
        SIMD3( 0.10, -0.65,  0.75),
        SIMD3(-0.30,  0.50,  0.81),
        SIMD3( 0.65, -0.40,  0.65),
    ]

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, sz in draw(ctx, canvasSize: sz) }
                .frame(width: size, height: size)
                .shadow(color: Color(red: 0.35, green: 0.68, blue: 0.92, opacity: 0.45),
                        radius: size * 0.18)
                .gesture(flickGesture)
                .onChange(of: timeline.date) { date in tick(to: date) }
        }
        .onAppear { lastUpdate = .now }
    }

    // MARK: - Drawing

    private func draw(_ ctx: GraphicsContext, canvasSize: CGSize) {
        let cx  = canvasSize.width  / 2
        let cy  = canvasSize.height / 2
        let r   = min(canvasSize.width, canvasSize.height) / 2 * 0.78

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

        let sphereRect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
        let spherePath = Path(ellipseIn: sphereRect)

        // Ripple rings beneath sphere
        let maxRipR = r * 1.55
        let rippleBlue = Color(red: 0.50, green: 0.78, blue: 0.96)
        for i in 0..<3 {
            let phase = (ripplePhase + Double(i) / 3.0).truncatingRemainder(dividingBy: 1.0)
            let ripR  = CGFloat(phase) * maxRipR
            let alpha = (1.0 - phase) * 0.45
            let rect  = CGRect(x: cx - ripR, y: cy - ripR, width: ripR * 2, height: ripR * 2)
            ctx.stroke(Path(ellipseIn: rect),
                       with: .color(rippleBlue.opacity(alpha)),
                       lineWidth: max(0.5, CGFloat(1.0 - phase) * 1.6))
        }

        // Sphere base — deep water gradient
        ctx.fill(spherePath, with: .radialGradient(
            Gradient(stops: [
                .init(color: Color(red: 0.42, green: 0.72, blue: 0.95), location: 0.0),
                .init(color: Color(red: 0.22, green: 0.52, blue: 0.80), location: 0.55),
                .init(color: Color(red: 0.08, green: 0.28, blue: 0.58), location: 1.0),
            ]),
            center: CGPoint(x: cx - r * 0.15, y: cy - r * 0.15),
            startRadius: 0,
            endRadius: r * 1.1
        ))

        // Caustic light patterns — bright pools that move with rotation
        for pole in causticPoles {
            let rp = rot(pole)
            guard rp.z > 0.05 else { continue }
            let intensity = max(0, rp.z)
            let causticPt = proj(rp * 0.7)   // inward projection keeps caustic inside sphere
            let causticR  = r * CGFloat(0.18 + intensity * 0.22)
            ctx.fill(spherePath, with: .radialGradient(
                Gradient(stops: [
                    .init(color: Color(red: 0.70, green: 0.92, blue: 1.0, opacity: intensity * 0.35), location: 0.0),
                    .init(color: .clear, location: 1.0),
                ]),
                center: causticPt,
                startRadius: 0,
                endRadius: causticR
            ))
        }

        // Fresnel darkening at rim
        ctx.fill(spherePath, with: .radialGradient(
            Gradient(stops: [
                .init(color: .clear, location: 0.60),
                .init(color: Color(red: 0.04, green: 0.18, blue: 0.40, opacity: 0.65), location: 1.0),
            ]),
            center: CGPoint(x: cx, y: cy),
            startRadius: r * 0.60,
            endRadius: r
        ))

        // Specular highlight — always fixed top-left (light source)
        ctx.fill(spherePath, with: .radialGradient(
            Gradient(stops: [
                .init(color: .white.opacity(0.80), location: 0.0),
                .init(color: .white.opacity(0.25), location: 0.30),
                .init(color: .clear, location: 0.65),
            ]),
            center: CGPoint(x: cx - r * 0.32, y: cy - r * 0.35),
            startRadius: 0,
            endRadius: r * 0.42
        ))

        // Secondary smaller catch-light
        ctx.fill(spherePath, with: .radialGradient(
            Gradient(stops: [
                .init(color: .white.opacity(0.45), location: 0.0),
                .init(color: .clear, location: 1.0),
            ]),
            center: CGPoint(x: cx + r * 0.28, y: cy + r * 0.38),
            startRadius: 0,
            endRadius: r * 0.18
        ))

        // Edge stroke
        ctx.stroke(spherePath,
                   with: .color(Color(red: 0.30, green: 0.65, blue: 0.92, opacity: 0.35)),
                   lineWidth: 1.0)
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
        rotX       += vX * dt
        rotY       += vY * dt
        ripplePhase += dt * 0.36
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
        Color(red: 0.05, green: 0.10, blue: 0.18)
        WaterDropletView(size: 160)
    }
    .frame(width: 300, height: 300)
    .preferredColorScheme(.dark)
}

#Preview("Light bg") {
    ZStack {
        Color(red: 0.88, green: 0.93, blue: 0.98)
        WaterDropletView(size: 160)
    }
    .frame(width: 300, height: 300)
}
