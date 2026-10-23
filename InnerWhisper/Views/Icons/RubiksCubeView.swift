//
//  RubiksCubeView.swift
//  InnerWhisper
//

import SwiftUI

/// An animated 3D Rubik's cube fidget icon that can be spun in any direction.
///
/// Renders a fully solved 3×3×3 Rubik's cube with:
/// - Six face colours: white top, yellow bottom, red front, orange back, blue right, green left
/// - Nine stickers per face separated by dark-plastic gaps
/// - Back-face culling so only the up-to-three visible faces are drawn
/// - Diffuse lighting (ambient + directional) plus a face-level gloss overlay
/// - Painter's algorithm depth sort so nearer faces composite correctly
///
/// Drag in any direction to spin it; friction decays momentum back to a
/// slow, steady showcase rotation.
struct RubiksCubeView: View {
    /// Diameter of the cube's bounding frame.
    var size: CGFloat = 120

    // MARK: - Physics state

    @State private var rotX: Double = 22
    @State private var rotY: Double = -30
    @State private var vX: Double = Self.idleVX
    @State private var vY: Double = Self.idleVY
    @State private var lastUpdate: Date = .now
    @State private var isDragging: Bool = false

    // MARK: - Gesture tracking

    @State private var lastDragLoc: CGPoint? = nil
    @State private var lastDragTime: Date? = nil

    // MARK: - Constants

    private static let idleVX: Double = 4
    private static let idleVY: Double = -18
    private static let friction: Double = 0.983
    private static let maxSpeed: Double = 720

    /// Gap between stickers in local cube units (face spans −1 … +1).
    private static let gap: Double = 0.048
    /// Half-size of a single sticker.
    private static let stickerHS: Double = 1.0 / 3.0 - gap

    // MARK: - Face definitions

    /// One face of the cube: outward normal, two tangent axes, and RGB sticker colour.
    private struct Face {
        let normal: SIMD3<Double>
        let uAxis:  SIMD3<Double>   // +u = rightward across the face
        let vAxis:  SIMD3<Double>   // +v = upward across the face
        let r, g, b: Double         // base sticker colour (sRGB)
    }

    /// Six faces ordered so the most-commonly-visible ones come last
    /// (they win in the back-to-front painter sort for typical orientations).
    private static let faces: [Face] = [
        // Top    — White
        Face(normal: SIMD3( 0,  1,  0), uAxis: SIMD3( 1, 0,  0), vAxis: SIMD3(0, 0, -1),
             r: 0.96, g: 0.96, b: 0.94),
        // Bottom — Yellow
        Face(normal: SIMD3( 0, -1,  0), uAxis: SIMD3( 1, 0,  0), vAxis: SIMD3(0, 0,  1),
             r: 1.00, g: 0.85, b: 0.00),
        // Back   — Orange
        Face(normal: SIMD3( 0,  0, -1), uAxis: SIMD3(-1, 0,  0), vAxis: SIMD3(0, 1,  0),
             r: 1.00, g: 0.44, b: 0.00),
        // Left   — Green
        Face(normal: SIMD3(-1,  0,  0), uAxis: SIMD3( 0, 0,  1), vAxis: SIMD3(0, 1,  0),
             r: 0.00, g: 0.60, b: 0.18),
        // Right  — Blue
        Face(normal: SIMD3( 1,  0,  0), uAxis: SIMD3( 0, 0, -1), vAxis: SIMD3(0, 1,  0),
             r: 0.00, g: 0.30, b: 0.90),
        // Front  — Red
        Face(normal: SIMD3( 0,  0,  1), uAxis: SIMD3( 1, 0,  0), vAxis: SIMD3(0, 1,  0),
             r: 0.95, g: 0.10, b: 0.10),
    ]

    // MARK: - Body

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, canvasSize in
                drawCube(ctx, size: canvasSize)
            }
            .frame(width: size, height: size)
            .shadow(
                color: .black.opacity(0.38),
                radius: size * 0.08,
                x: size * 0.03,
                y: size * 0.06
            )
            .gesture(flickGesture)
            .onChange(of: timeline.date) { date in tick(to: date) }
        }
        .onAppear { lastUpdate = .now }
    }

    // MARK: - Drawing

    /// Renders the cube into a Canvas context.
    ///
    /// Rendering order per face (all clipped to face quad):
    /// 1. Dark-plastic background
    /// 2. Nine lit stickers
    /// 3. Face-level gloss sheen
    /// 4. Radial vignette to darken sticker edges
    ///
    /// Then, outside the clip layer:
    /// 5. Thin face-outline stroke (the visible plastic ridges)
    private func drawCube(_ ctx: GraphicsContext, size: CGSize) {
        let cx    = size.width  / 2
        let cy    = size.height / 2
        // Scale must satisfy s ≤ 1/√3 ≈ 0.577 so that the cube's space-diagonal corner
        // (max projected distance = √3 · s · halfSize) never exceeds the frame half-width.
        let scale = min(size.width, size.height) / 2 * 0.56

        // ── Rotation matrix  R = Ry · Rx ─────────────────────────────────────
        let rx = rotX * .pi / 180.0
        let ry = rotY * .pi / 180.0
        let cX = cos(rx), sX = sin(rx)
        let cY = cos(ry), sY = sin(ry)

        func rot(_ v: SIMD3<Double>) -> SIMD3<Double> {
            SIMD3(
                 v.x * cY + v.y * sX * sY + v.z * cX * sY,
                             v.y * cX       - v.z * sX,
                -v.x * sY + v.y * sX * cY  + v.z * cX * cY
            )
        }

        func proj(_ v: SIMD3<Double>) -> CGPoint {
            CGPoint(x: cx + v.x * scale, y: cy - v.y * scale)
        }

        func vdot(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
            a.x*b.x + a.y*b.y + a.z*b.z
        }

        func vnorm(_ v: SIMD3<Double>) -> SIMD3<Double> {
            let l = sqrt(v.x*v.x + v.y*v.y + v.z*v.z)
            return l > 1e-9 ? v / l : v
        }

        let lightDir = vnorm(SIMD3<Double>(0.35, 0.55, 1.0))

        // ── Back-face cull and depth sort ─────────────────────────────────────

        struct RenderFace {
            let face: Face
            let depth: Double       // rotated face-centre z (larger = nearer)
            let lighting: Double    // 0.60 ambient + 0.40 diffuse
        }

        var renderFaces: [RenderFace] = []
        for face in Self.faces {
            let rn = rot(face.normal)
            guard rn.z > 0 else { continue }                       // back-face cull
            let ndotl    = max(0.0, vdot(rn, lightDir))
            let lighting = 0.60 + 0.40 * ndotl
            renderFaces.append(RenderFace(face: face, depth: rn.z, lighting: lighting))
        }
        renderFaces.sort { $0.depth < $1.depth }                   // back → front

        // ── Draw each visible face ────────────────────────────────────────────

        let offsets: [Double] = [-2.0 / 3.0, 0.0, 2.0 / 3.0]
        let hs = Self.stickerHS

        for rf in renderFaces {
            let face = rf.face
            let L    = rf.lighting

            // Full face quad (includes the black rim / plastic boundary)
            let fCorners: [SIMD3<Double>] = [
                face.normal + face.uAxis * (-1) + face.vAxis * (-1),
                face.normal + face.uAxis * ( 1) + face.vAxis * (-1),
                face.normal + face.uAxis * ( 1) + face.vAxis * ( 1),
                face.normal + face.uAxis * (-1) + face.vAxis * ( 1),
            ]
            let fp = fCorners.map { proj(rot($0)) }
            var facePath = Path()
            facePath.move(to: fp[0])
            fp.dropFirst().forEach { facePath.addLine(to: $0) }
            facePath.closeSubpath()

            let fCenter = proj(rot(face.normal))
            let glossPt = CGPoint(x: fCenter.x - scale * 0.20,
                                  y: fCenter.y - scale * 0.20)

            ctx.drawLayer { layer in
                layer.clip(to: facePath)

                // 1. Dark plastic body between stickers
                layer.fill(facePath, with: .color(Color(white: 0.07)))

                // 2. Nine stickers — lit with ambient + diffuse
                for i in 0..<3 {
                    for j in 0..<3 {
                        let uc = offsets[i]
                        let vc = offsets[j]
                        let sCorners: [SIMD3<Double>] = [
                            face.normal + face.uAxis * (uc - hs) + face.vAxis * (vc - hs),
                            face.normal + face.uAxis * (uc + hs) + face.vAxis * (vc - hs),
                            face.normal + face.uAxis * (uc + hs) + face.vAxis * (vc + hs),
                            face.normal + face.uAxis * (uc - hs) + face.vAxis * (vc + hs),
                        ]
                        let sp = sCorners.map { proj(rot($0)) }
                        var sPath = Path()
                        sPath.move(to: sp[0])
                        sp.dropFirst().forEach { sPath.addLine(to: $0) }
                        sPath.closeSubpath()

                        layer.fill(sPath, with: .color(
                            Color(red: face.r * L, green: face.g * L, blue: face.b * L)
                        ))
                    }
                }

                // 3. Gloss sheen — upper-left catch light across the whole face
                layer.fill(facePath, with: .radialGradient(
                    Gradient(stops: [
                        .init(color: .white.opacity(0.24), location: 0.00),
                        .init(color: .white.opacity(0.06), location: 0.50),
                        .init(color: .clear,               location: 1.00),
                    ]),
                    center: glossPt,
                    startRadius: 0,
                    endRadius: scale * 0.95
                ))

                // 4. Radial vignette — darkens sticker edges, reinforces cube body depth
                layer.fill(facePath, with: .radialGradient(
                    Gradient(stops: [
                        .init(color: .clear,               location: 0.50),
                        .init(color: .black.opacity(0.22), location: 1.00),
                    ]),
                    center: fCenter,
                    startRadius: scale * 0.28,
                    endRadius: scale * 0.95
                ))
            }

            // Thin dark outline — the visible plastic ridge between adjacent faces
            ctx.stroke(facePath,
                       with: .color(Color(white: 0.04).opacity(0.88)),
                       lineWidth: max(0.5, scale * 0.020))
        }
    }

    // MARK: - Physics

    private func tick(to date: Date) {
        let dt = date.timeIntervalSince(lastUpdate)
        lastUpdate = date
        guard dt > 0, dt < 0.1 else { return }

        if !isDragging {
            let f = pow(Self.friction, dt * 60.0)
            vX *= f
            vY *= f
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

    /// Converts tangential drag motion into angular velocity for both axes.
    ///
    /// - Horizontal drag → `vY` (spin around vertical Y axis, left–right)
    /// - Vertical drag   → `vX` (tilt around horizontal X axis, up–down)
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

#Preview("Light") {
    ZStack {
        Color(.systemBackground)
        RubiksCubeView(size: 140)
    }
    .frame(width: 300, height: 300)
}

#Preview("Dark") {
    ZStack {
        Color(red: 0.06, green: 0.06, blue: 0.08)
        RubiksCubeView(size: 140)
    }
    .frame(width: 300, height: 300)
    .preferredColorScheme(.dark)
}

#Preview("Large") {
    ZStack {
        Color(red: 0.07, green: 0.07, blue: 0.09)
        RubiksCubeView(size: 220)
    }
    .frame(width: 400, height: 400)
    .preferredColorScheme(.dark)
}
