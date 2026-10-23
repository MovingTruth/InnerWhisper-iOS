//
//  MoonView.swift
//  InnerWhisper
//

import SwiftUI

/// An animated 3D moon fidget that can be spun in any direction.
///
/// The moon surface is built from real geographic features:
/// - 9 maria (dark basaltic plains) placed at their actual lunar coordinates
/// - 15+ craters with a lighter rim and variable-brightness interior
///
/// All features are projected from their 3D unit-sphere positions using a
/// per-frame rotation matrix, sorted back-to-front (painter's algorithm),
/// and faded at the limb for a naturalistic silhouette.
///
/// Drag in any direction to spin it; friction decays momentum back to a
/// slow, serene idle tumble.
struct MoonView: View {
    /// Diameter of the moon.
    var size: CGFloat = 60

    // MARK: - Physics state

    @State private var rotX: Double = 10
    @State private var rotY: Double = 0
    @State private var vX: Double = Self.idleVX
    @State private var vY: Double = Self.idleVY
    @State private var lastUpdate: Date = .now
    @State private var isDragging: Bool = false

    // MARK: - Gesture tracking

    @State private var lastDragLoc: CGPoint? = nil
    @State private var lastDragTime: Date? = nil

    // MARK: - Constants

    private static let idleVX: Double = 3
    private static let idleVY: Double = -12
    private static let friction: Double = 0.983
    private static let maxSpeed: Double = 720

    // MARK: - Moon surface features

    /// A single surface feature: a mare or a crater.
    struct Feature {
        /// Unit-sphere position (lon=0 lat=0 faces the viewer by default).
        let center: SIMD3<Double>
        /// Angular circumradius in radians.
        let angR: Double
        /// Fill brightness of the interior (0 = black, 1 = white).
        let fill: Double
        /// Brightness of the crater rim ring (0 = no rim, 1 = white). Unused for mare.
        let rim: Double
        let isMare: Bool

        /// Convenience init using geodetic degrees and brightness fractions.
        init(lon: Double, lat: Double, deg: Double,
             fill: Double, rim: Double = 0, mare: Bool = false) {
            let lonR = lon * .pi / 180
            let latR = lat * .pi / 180
            // lon=0, lat=0 → (0,0,1) = toward viewer; lat=+90 → top of sphere.
            self.center = SIMD3(
                cos(latR) * sin(lonR),
                sin(latR),
                cos(latR) * cos(lonR)
            )
            self.angR  = deg * .pi / 180
            self.fill  = fill
            self.rim   = rim
            self.isMare = mare
        }
    }

    /// Lunar features ordered roughly by geological importance (drawing order
    /// is re-sorted at render time, so this order doesn't affect visuals).
    private static let features: [Feature] = [
        // ── Maria (dark basaltic plains) ─────────────────────────────────────
        Feature(lon: -18, lat:  33, deg: 17.0, fill: 0.50, mare: true),  // Mare Imbrium
        Feature(lon:  18, lat:  28, deg: 12.0, fill: 0.52, mare: true),  // Mare Serenitatis
        Feature(lon:  30, lat:   8, deg: 14.0, fill: 0.48, mare: true),  // Mare Tranquillitatis
        Feature(lon:  58, lat:  17, deg:  7.5, fill: 0.46, mare: true),  // Mare Crisium
        Feature(lon: -55, lat:  15, deg: 26.0, fill: 0.50, mare: true),  // Oceanus Procellarum
        Feature(lon: -40, lat: -25, deg:  9.0, fill: 0.52, mare: true),  // Mare Humorum
        Feature(lon: -15, lat: -20, deg: 13.0, fill: 0.51, mare: true),  // Mare Nubium
        Feature(lon:   0, lat:  55, deg: 11.0, fill: 0.53, mare: true),  // Mare Frigoris
        Feature(lon:  55, lat: -30, deg:  8.0, fill: 0.50, mare: true),  // Mare Nectaris

        // ── Craters ──────────────────────────────────────────────────────────
        Feature(lon: -11, lat: -43, deg: 4.5, fill: 0.65, rim: 0.93),   // Tycho
        Feature(lon: -20, lat:  10, deg: 5.0, fill: 0.62, rim: 0.86),   // Copernicus
        Feature(lon: -14, lat: -58, deg: 7.5, fill: 0.66, rim: 0.81),   // Clavius
        Feature(lon:  -9, lat:  51, deg: 5.0, fill: 0.45, rim: 0.79),   // Plato (dark floor)
        Feature(lon:  -2, lat:  -9, deg: 6.0, fill: 0.60, rim: 0.79),   // Ptolemaeus
        Feature(lon:  26, lat: -12, deg: 4.0, fill: 0.63, rim: 0.83),   // Theophilus
        Feature(lon: -47, lat:  24, deg: 3.0, fill: 0.92, rim: 0.96),   // Aristarchus (very bright)
        Feature(lon: -68, lat:  -5, deg: 7.0, fill: 0.44, rim: 0.73),   // Grimaldi (dark)
        Feature(lon: -38, lat:   8, deg: 3.5, fill: 0.65, rim: 0.83),   // Kepler
        Feature(lon:  -3, lat: -13, deg: 5.0, fill: 0.60, rim: 0.79),   // Alphonsus
        Feature(lon:   5, lat: -17, deg: 4.5, fill: 0.61, rim: 0.81),   // Arzachel
        Feature(lon:  15, lat:  -9, deg: 5.5, fill: 0.58, rim: 0.83),   // Hipparchus
        Feature(lon:  20, lat: -16, deg: 3.5, fill: 0.63, rim: 0.81),   // Cyrillus
        Feature(lon:  12, lat:  42, deg: 3.0, fill: 0.65, rim: 0.83),   // Aristoteles
        Feature(lon: -34, lat:  36, deg: 4.0, fill: 0.64, rim: 0.81),   // Timocharis
    ]

    // MARK: - Body

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, canvasSize in
                drawMoon(ctx, size: canvasSize)
            }
            .frame(width: size, height: size)
            .shadow(
                color: Color(white: 0.3, opacity: 0.4),
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

    /// Renders the moon surface into a Canvas context.
    ///
    /// Rendering order (all clipped to the ball circle):
    /// 1. Base highland gray
    /// 2. Maria — dark plains, back-to-front, limb-faded
    /// 3. Craters — rim ring then interior, back-to-front, limb-faded
    /// 4. Spherical shading gradient (diffuse, not specular — moon albedo is ~12%)
    /// 5. Faint specular hint top-left
    private func drawMoon(_ ctx: GraphicsContext, size: CGSize) {
        let cx = size.width  / 2
        let cy = size.height / 2
        let radius = min(size.width, size.height) / 2 * 0.95

        // ── Rotation matrix  R = Ry · Rx ────────────────────────────────────
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

        func proj(_ p: SIMD3<Double>) -> CGPoint {
            CGPoint(x: cx + p.x * radius, y: cy - p.y * radius)
        }

        let ballRect = CGRect(x: cx - radius, y: cy - radius,
                              width: radius * 2, height: radius * 2)
        let ballPath = Path(ellipseIn: ballRect)

        // ── Project and cull features ────────────────────────────────────────
        struct Projected {
            let feature: Feature
            let rotZ: Double       // z after rotation — used for depth sorting & fade
            let center2D: CGPoint
            let projRadius: Double
        }

        var projected: [Projected] = []
        projected.reserveCapacity(Self.features.count)

        for f in Self.features {
            let n = rot(f.center)
            // Mare culling is gentler (they wrap over the limb visually).
            let cutoff: Double = f.isMare ? -0.35 : -0.15
            guard n.z > cutoff else { continue }
            let pr = Double(radius) * sin(f.angR)
            projected.append(Projected(
                feature: f,
                rotZ: n.z,
                center2D: proj(n),
                projRadius: pr
            ))
        }

        // ── Draw ─────────────────────────────────────────────────────────────
        ctx.drawLayer { layer in
            layer.clip(to: ballPath)

            // 1. Lunar highland base — warm light gray
            layer.fill(ballPath, with: .color(Color(red: 0.76, green: 0.75, blue: 0.74)))

            // 2. Maria — back-to-front
            let maria = projected.filter { $0.feature.isMare }.sorted { $0.rotZ < $1.rotZ }
            for p in maria {
                let depth = max(0.0, (p.rotZ + 0.35) / 1.35)
                let pr    = p.projRadius
                let pc    = p.center2D
                let rect  = CGRect(x: pc.x - pr, y: pc.y - pr, width: pr * 2, height: pr * 2)
                // Soft radial gradient instead of flat fill → natural "pooled lava" edge
                layer.fill(Path(ellipseIn: rect), with: .radialGradient(
                    Gradient(stops: [
                        .init(color: Color(white: p.feature.fill).opacity(depth * 0.88), location: 0.0),
                        .init(color: Color(white: p.feature.fill).opacity(depth * 0.55), location: 0.7),
                        .init(color: .clear,                                              location: 1.0),
                    ]),
                    center: pc,
                    startRadius: 0,
                    endRadius: pr
                ))
            }

            // 3. Craters — back-to-front
            let craters = projected.filter { !$0.feature.isMare }.sorted { $0.rotZ < $1.rotZ }
            for p in craters {
                let depth = max(0.0, (p.rotZ + 0.15) / 1.15)
                let pr    = p.projRadius
                let pc    = p.center2D
                let f     = p.feature

                // Rim ring: full-size circle in lighter gray
                if f.rim > 0 {
                    let rimRect = CGRect(x: pc.x - pr, y: pc.y - pr, width: pr * 2, height: pr * 2)
                    layer.fill(Path(ellipseIn: rimRect),
                               with: .color(Color(white: f.rim).opacity(depth)))
                }

                // Interior fill: 72% of rim radius
                let ip   = pr * 0.72
                let iRect = CGRect(x: pc.x - ip, y: pc.y - ip, width: ip * 2, height: ip * 2)
                layer.fill(Path(ellipseIn: iRect),
                           with: .color(Color(white: f.fill).opacity(depth)))
            }

            // 4. Spherical shading — diffuse gradient, dark on the "shadow" side.
            //    Moon is matte so this is broad and soft, not a sharp terminator.
            layer.fill(ballPath, with: .radialGradient(
                Gradient(stops: [
                    .init(color: .clear,               location: 0.18),
                    .init(color: .black.opacity(0.48), location: 1.00),
                ]),
                center: CGPoint(x: cx - radius * 0.14, y: cy - radius * 0.18),
                startRadius: radius * 0.18,
                endRadius:   radius * 1.18
            ))

            // 5. Faint specular — moon is matte, so keep this very subtle
            layer.fill(ballPath, with: .radialGradient(
                Gradient(stops: [
                    .init(color: .white.opacity(0.18), location: 0.0),
                    .init(color: .clear,               location: 1.0),
                ]),
                center: CGPoint(x: cx - radius * 0.28, y: cy - radius * 0.36),
                startRadius: 0,
                endRadius:   radius * 0.58
            ))
        }

        // Thin edge outline
        ctx.stroke(ballPath, with: .color(.black.opacity(0.10)), lineWidth: 0.5)
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
        MoonView(size: 140)
    }
    .frame(width: 300, height: 300)
}

#Preview("Default – Dark") {
    ZStack {
        Color(red: 0.04, green: 0.04, blue: 0.12)
        MoonView(size: 140)
    }
    .frame(width: 300, height: 300)
    .preferredColorScheme(.dark)
}

#Preview("Large") {
    ZStack {
        Color(red: 0.04, green: 0.04, blue: 0.12)
        MoonView(size: 220)
    }
    .frame(width: 400, height: 400)
    .preferredColorScheme(.dark)
}
