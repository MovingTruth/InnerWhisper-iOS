//
//  SoccerBallView.swift
//  InnerWhisper
//

import SwiftUI

/// An animated 3D soccer ball fidget icon that can be spun in any direction.
///
/// The ball renders a classic truncated-icosahedron patch pattern (12 black pentagons)
/// using a per-frame rotation matrix to project 3D sphere geometry onto the canvas.
/// A radial shading gradient and specular highlight give convincing depth.
///
/// Drag in any direction to impart spin; friction decays momentum back to a
/// gentle idle tumble. The ball responds to both horizontal and vertical drags,
/// unlike a Z-axis-only spin, so it behaves like a real ball in the hand.
struct SoccerBallView: View {
    /// Diameter of the ball.
    var size: CGFloat = 60

    // MARK: - Physics state

    /// Rotation around the X axis (degrees). Positive = ball tilts top-toward-viewer.
    @State private var rotX: Double = 15
    /// Rotation around the Y axis (degrees). Positive = ball turns right.
    @State private var rotY: Double = 0
    /// Angular velocity around X (deg/sec), driven by vertical drags.
    @State private var vX: Double = Self.idleVX
    /// Angular velocity around Y (deg/sec), driven by horizontal drags.
    @State private var vY: Double = Self.idleVY
    @State private var lastUpdate: Date = .now
    @State private var isDragging: Bool = false

    // MARK: - Gesture tracking

    @State private var lastDragLoc: CGPoint? = nil
    @State private var lastDragTime: Date? = nil

    // MARK: - Constants

    private static let idleVX: Double = 7
    private static let idleVY: Double = -24
    private static let friction: Double = 0.980
    /// Maximum spin speed (deg/sec) — 2 full rotations per second.
    private static let maxSpeed: Double = 720

    // MARK: - Geometry: pentagon face centers

    /// The 12 pentagon face centers of a truncated icosahedron lie on the unit
    /// sphere at the positions of the 12 vertices of a regular icosahedron.
    private static let φ: Double = (1.0 + 5.0.squareRoot()) / 2.0
    private static let _norm: Double = (1.0 + φ * φ).squareRoot()
    private static let _s: Double = 1.0 / _norm   // shorter component
    private static let _l: Double = φ / _norm      // longer  component

    private static let pentCenters: [SIMD3<Double>] = {
        let s = _s, l = _l
        return [
            SIMD3( 0,  s,  l), SIMD3( 0,  s, -l),
            SIMD3( 0, -s,  l), SIMD3( 0, -s, -l),
            SIMD3( s,  l,  0), SIMD3(-s,  l,  0),
            SIMD3( s, -l,  0), SIMD3(-s, -l,  0),
            SIMD3( l,  0,  s), SIMD3( l,  0, -s),
            SIMD3(-l,  0,  s), SIMD3(-l,  0, -s),
        ]
    }()

    /// Angular circumradius of each pentagon on the sphere (~21.8°).
    private static let pentAngle: Double = 0.38

    // MARK: - Body

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, canvasSize in
                drawBall(ctx, size: canvasSize)
            }
            .frame(width: size, height: size)
            .shadow(
                color: .black.opacity(0.28),
                radius: size * 0.10,
                x: size * 0.04,
                y: size * 0.07
            )
            .gesture(flickGesture)
            .onChange(of: timeline.date) { date in tick(to: date) }
        }
        .onAppear { lastUpdate = .now }
    }

    // MARK: - Drawing

    /// Renders the soccer ball into a Canvas context.
    ///
    /// Layers (all clipped to the ball circle):
    /// 1. White fill — ball base
    /// 2. Black pentagons projected from the current 3D orientation, sorted back-to-front
    ///    with a limb-fade to soften patches that are nearly tangent to the viewer
    /// 3. Dark radial gradient — spherical shading / ambient occlusion
    /// 4. White radial gradient — specular highlight (top-left)
    private func drawBall(_ ctx: GraphicsContext, size: CGSize) {
        let cx = size.width  / 2
        let cy = size.height / 2
        let radius = min(size.width, size.height) / 2 * 0.95

        // ── Rotation matrix  R = Ry · Rx ───────────────────────────────────
        let rx = rotX * .pi / 180.0
        let ry = rotY * .pi / 180.0
        let cX = cos(rx), sX = sin(rx)
        let cY = cos(ry), sY = sin(ry)

        func rot(_ p: SIMD3<Double>) -> SIMD3<Double> {
            SIMD3(
                 p.x * cY + p.y * sX * sY + p.z * cX * sY,
                             p.y * cX       - p.z * sX,
                -p.x * sY + p.y * sX * cY  + p.z * cX * cY
            )
        }

        /// Orthographic projection to canvas 2D (Y axis flipped for screen coords).
        func proj(_ p: SIMD3<Double>) -> CGPoint {
            CGPoint(x: cx + p.x * radius, y: cy - p.y * radius)
        }

        let ballRect = CGRect(x: cx - radius, y: cy - radius,
                              width: radius * 2, height: radius * 2)
        let ballPath = Path(ellipseIn: ballRect)

        // ── Pentagon patches ─────────────────────────────────────────────────
        // For each face center, build the 5 pentagon vertices on the sphere
        // surface and project them to 2D. Cull back-facing patches, sort
        // survivors back-to-front so front patches draw on top.
        struct Patch { let z: Double; let path: Path }
        var patches: [Patch] = []
        patches.reserveCapacity(12)

        let cosA = cos(Self.pentAngle)
        let sinA = sin(Self.pentAngle)

        for center in Self.pentCenters {
            let n = rot(center)
            guard n.z > -0.25 else { continue }   // cull; small margin avoids pop-in

            // Build an orthonormal basis {u, v} perpendicular to n.
            let up: SIMD3<Double> = abs(n.y) < 0.9 ? SIMD3(0, 1, 0) : SIMD3(1, 0, 0)
            let dot = n.x * up.x + n.y * up.y + n.z * up.z
            var u = SIMD3<Double>(up.x - n.x * dot, up.y - n.y * dot, up.z - n.z * dot)
            let uLen = (u.x*u.x + u.y*u.y + u.z*u.z).squareRoot()
            u /= uLen
            // v = n × u  (right-hand cross product)
            let v = SIMD3<Double>(
                n.y * u.z - n.z * u.y,
                n.z * u.x - n.x * u.z,
                n.x * u.y - n.y * u.x
            )

            // 5 vertices at angular distance pentAngle from n, evenly spaced.
            var penPath = Path()
            for i in 0..<5 {
                let θ = Double(i) * 2.0 * .pi / 5.0
                let pt = n * cosA + (u * cos(θ) + v * sin(θ)) * sinA
                let p2 = proj(pt)
                if i == 0 { penPath.move(to: p2) } else { penPath.addLine(to: p2) }
            }
            penPath.closeSubpath()
            patches.append(Patch(z: n.z, path: penPath))
        }
        patches.sort { $0.z < $1.z }   // painter's order: draw back patches first

        // ── Composite drawing ────────────────────────────────────────────────
        ctx.drawLayer { layer in
            layer.clip(to: ballPath)

            // 1. White ball base
            layer.fill(ballPath, with: .color(.white))

            // 2. Black pentagons — fade toward the limb for a soft silhouette
            for patch in patches {
                // (n.z + 0.25) / 1.25 maps [-0.25 … 1] → [0 … 1]
                let alpha = max(0.08, min(0.93, (patch.z + 0.25) / 1.25))
                layer.fill(patch.path, with: .color(.black.opacity(alpha)))
            }

            // 3. Spherical shading — dark radial gradient on the shadowed side
            layer.fill(ballPath, with: .radialGradient(
                Gradient(stops: [
                    .init(color: .clear,                   location: 0.25),
                    .init(color: .black.opacity(0.55),     location: 1.00),
                ]),
                center: CGPoint(x: cx - radius * 0.18, y: cy - radius * 0.22),
                startRadius: radius * 0.25,
                endRadius:   radius * 1.20
            ))

            // 4. Specular highlight — bright spot top-left
            layer.fill(ballPath, with: .radialGradient(
                Gradient(stops: [
                    .init(color: .white.opacity(0.72), location: 0.0),
                    .init(color: .clear,               location: 1.0),
                ]),
                center: CGPoint(x: cx - radius * 0.33, y: cy - radius * 0.43),
                startRadius: 0,
                endRadius:   radius * 0.52
            ))
        }

        // Thin outline to define the ball edge against any background
        ctx.stroke(ballPath, with: .color(.black.opacity(0.14)), lineWidth: 0.6)
    }

    // MARK: - Physics

    /// Advances the physics simulation by one display frame.
    private func tick(to date: Date) {
        let dt = date.timeIntervalSince(lastUpdate)
        lastUpdate = date
        guard dt > 0, dt < 0.1 else { return }

        if !isDragging {
            let f = pow(Self.friction, dt * 60.0)
            vX *= f
            vY *= f
            // Smoothly restore toward idle spin once momentum has decayed.
            if abs(vX) < abs(Self.idleVX) * 2 {
                vX += (Self.idleVX - vX) * min(1.0, dt * 1.5)
            }
            if abs(vY) < abs(Self.idleVY) * 2 {
                vY += (Self.idleVY - vY) * min(1.0, dt * 1.5)
            }
        }

        rotX += vX * dt
        rotY += vY * dt
    }

    // MARK: - Gesture

    /// Converts tangential drag motion into angular velocity for both X and Y axes.
    ///
    /// - Horizontal drag → `vY` (rotation around the vertical Y axis, i.e. left–right spin)
    /// - Vertical drag   → `vX` (rotation around the horizontal X axis, i.e. top–bottom tilt)
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

#Preview("Default – Light") {
    ZStack {
        Color(.systemBackground)
        SoccerBallView(size: 120)
    }
    .frame(width: 300, height: 300)
}

#Preview("Default – Dark") {
    ZStack {
        Color(.systemBackground)
        SoccerBallView(size: 120)
    }
    .frame(width: 300, height: 300)
    .preferredColorScheme(.dark)
}

#Preview("Large") {
    ZStack {
        Color(.systemBackground)
        SoccerBallView(size: 200)
    }
    .frame(width: 400, height: 400)
}
