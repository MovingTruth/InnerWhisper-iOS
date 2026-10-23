//
//  LeafView.swift
//  InnerWhisper
//

import SwiftUI

/// An animated 3D leaf fidget icon that can be spun in any direction.
///
/// The leaf is modelled as a genuine curved surface in 3D space:
/// - A parametric pointed-oval outline with real Z-depth (edges cup backward)
/// - Pinnate venation: a central midrib with 8 pairs of angled secondary veins
/// - Front face: rich forest green with a lighter midrib channel and specular sheen
/// - Back face: pale sage green with visible raised-vein highlights
/// - A short petiole (stem) at the base
///
/// Drag in any direction to spin it; idle motion rotates around the X axis (nodding)
/// while a Y-axis spring prevents it from settling edge-on.
struct LeafView: View {
    /// Diameter of the leaf's bounding frame.
    var size: CGFloat = 120

    // MARK: - Physics state

    @State private var rotX: Double = 15
    @State private var rotY: Double = -15     // slight Y offset so the spring sway is visible on first load
    @State private var vX: Double = Self.idleVX
    @State private var vY: Double = 0
    @State private var lastUpdate: Date = .now
    @State private var isDragging: Bool = false

    // MARK: - Gesture tracking

    @State private var lastDragLoc: CGPoint? = nil
    @State private var lastDragTime: Date? = nil

    // MARK: - Constants

    private static let friction: Double = 0.983
    private static let maxSpeed: Double = 720
    /// Continuous idle rotation around the X axis (leaf nods forward/backward).
    /// X rotation keeps the face visible throughout its cycle, unlike Y which goes edge-on.
    private static let idleVX: Double = 10
    /// Spring constant pulling rotY back toward face-forward (0°).
    /// Allows gentle Y sway after a fling but prevents it from settling edge-on.
    private static let springK: Double = 10

    // MARK: - Leaf surface helpers

    /// Half-width of the leaf at normalised height t ∈ [0,1] (0 = stem base, 1 = tip).
    ///
    /// The exponent on the sin keeps the midsection broad; the skewed inner exponent
    /// shifts the widest point to ~43 % from base, matching real leaf proportions.
    private static func halfWidth(_ t: Double) -> Double {
        guard t > 0, t < 1 else { return 0 }
        return 0.56 * pow(sin(.pi * pow(t, 0.85)), 0.70)
    }

    /// Z coordinate for any point on the leaf surface.
    ///
    /// The leaf is gently cupped transversely (edges bow backward) and slightly
    /// arched lengthwise, so it reads as a real three-dimensional surface when
    /// spinning edge-on.
    private static func surfaceZ(x: Double, t: Double) -> Double {
        let hw = halfWidth(t)
        let xNorm = hw > 0.01 ? (x / hw) : 0   // −1 … +1 across width
        let cup   = -0.065 * xNorm * xNorm       // edges dip back
        let arch  =  0.022 * sin(.pi * t)        // lengthwise arch
        return cup + arch
    }

    // MARK: - Body

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, canvasSize in
                drawLeaf(ctx, size: canvasSize)
            }
            .frame(width: size, height: size)
            .shadow(
                color: Color(red: 0.10, green: 0.45, blue: 0.10, opacity: 0.45),
                radius: size * 0.10,
                x: size * 0.03,
                y: size * 0.06
            )
            .gesture(flickGesture)
            .onChange(of: timeline.date) { date in tick(to: date) }
        }
        .onAppear { lastUpdate = .now }
    }

    // MARK: - Drawing

    /// Renders the full leaf into a Canvas context.
    ///
    /// Rendering order:
    /// 1. Leaf body (clipped layer): base gradient → midrib glow → edge shadow → specular
    /// 2. Midrib (central vein)
    /// 3. Eight pairs of secondary veins (pinnate venation)
    /// 4. Outline stroke
    /// 5. Petiole (stem)
    private func drawLeaf(_ ctx: GraphicsContext, size: CGSize) {
        let cx    = size.width  / 2
        let cy    = size.height / 2
        let scale = min(size.width, size.height) / 2 * 0.86

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

        // ── Face orientation & lighting ───────────────────────────────────────
        let worldNormal = rot(SIMD3(0, 0, 1))
        let isFront     = worldNormal.z > 0
        // Flip normal for back face so diffuse lighting stays positive
        let surfNormal  = isFront ? worldNormal : -worldNormal
        let lightDir    = vnorm(SIMD3<Double>(-0.25, 0.55, 1.0))
        // Ambient 30% + diffuse 70% — leaf is always legible
        let lighting    = 0.30 + 0.70 * max(0.0, vdot(surfNormal, lightDir))

        // ── Leaf outline (52-segment parametric curve) ────────────────────────
        let steps = 52
        var rightSide: [SIMD3<Double>] = []
        var leftSide:  [SIMD3<Double>] = []

        for i in 0...steps {
            let t  = Double(i) / Double(steps)
            let y  = -0.9 + t * 1.9
            let hw = Self.halfWidth(t)
            rightSide.append(SIMD3( hw, y, Self.surfaceZ(x:  hw, t: t)))
            leftSide .append(SIMD3(-hw, y, Self.surfaceZ(x: -hw, t: t)))
        }

        // Build path: right side base→tip, then left side tip→base
        var outlinePath = Path()
        let rpRight = rightSide.map { proj(rot($0)) }
        let rpLeft  = leftSide .map { proj(rot($0)) }

        outlinePath.move(to: rpRight[0])
        for pt in rpRight.dropFirst() { outlinePath.addLine(to: pt) }
        for pt in rpLeft.reversed().dropFirst() { outlinePath.addLine(to: pt) }
        outlinePath.closeSubpath()

        // Gradient anchor points in canvas space
        let tipPt  = proj(rot(SIMD3(0,  1.00, 0)))
        let basePt = proj(rot(SIMD3(0, -0.90, 0)))
        let midPt  = proj(rot(SIMD3(0,  0.05, 0)))
        let specPt = proj(rot(SIMD3(-0.08, 0.28, 0.07)))

        // ── Leaf body (all fills clipped to outline) ──────────────────────────
        ctx.drawLayer { layer in
            layer.clip(to: outlinePath)

            if isFront {
                let L = lighting

                // 1. Base: tip-to-base gradient, lighter at tip
                layer.fill(outlinePath, with: .linearGradient(
                    Gradient(stops: [
                        .init(color: Color(red: 0.22*L, green: 0.60*L, blue: 0.16*L), location: 0.0),
                        .init(color: Color(red: 0.12*L, green: 0.40*L, blue: 0.10*L), location: 1.0),
                    ]),
                    startPoint: tipPt,
                    endPoint: basePt
                ))

                // 2. Midrib channel: radial yellow-green glow along centre axis
                layer.fill(outlinePath, with: .radialGradient(
                    Gradient(stops: [
                        .init(color: Color(red: 0.50, green: 0.82, blue: 0.28).opacity(0.40 * L), location: 0.00),
                        .init(color: .clear,                                                        location: 0.30),
                    ]),
                    center: midPt,
                    startRadius: 0,
                    endRadius: scale * 0.28
                ))

                // 3. Edge darkening
                layer.fill(outlinePath, with: .radialGradient(
                    Gradient(stops: [
                        .init(color: .clear,               location: 0.45),
                        .init(color: .black.opacity(0.32), location: 1.00),
                    ]),
                    center: midPt,
                    startRadius: scale * 0.20,
                    endRadius: scale * 0.90
                ))

                // 4. Specular sheen (upper-left catch light)
                layer.fill(outlinePath, with: .radialGradient(
                    Gradient(stops: [
                        .init(color: .white.opacity(0.32), location: 0.00),
                        .init(color: .white.opacity(0.08), location: 0.45),
                        .init(color: .clear,               location: 0.90),
                    ]),
                    center: specPt,
                    startRadius: 0,
                    endRadius: scale * 0.36
                ))

            } else {
                // Back face: pale sage underside
                let L = lighting

                // 1. Flat sage base
                layer.fill(outlinePath, with: .color(
                    Color(red: 0.60*L, green: 0.74*L, blue: 0.48*L)
                ))

                // 2. Midrib lightness (veins are raised and visible from below)
                layer.fill(outlinePath, with: .radialGradient(
                    Gradient(stops: [
                        .init(color: Color(red: 0.82, green: 0.92, blue: 0.66).opacity(0.45 * L), location: 0.00),
                        .init(color: .clear,                                                        location: 0.28),
                    ]),
                    center: midPt,
                    startRadius: 0,
                    endRadius: scale * 0.22
                ))

                // 3. Soft edge shadow
                layer.fill(outlinePath, with: .radialGradient(
                    Gradient(stops: [
                        .init(color: .clear,               location: 0.50),
                        .init(color: .black.opacity(0.18), location: 1.00),
                    ]),
                    center: midPt,
                    startRadius: scale * 0.18,
                    endRadius: scale * 0.90
                ))
            }
        }

        // ── Midrib ────────────────────────────────────────────────────────────
        var midribPath = Path()
        var firstPt = true
        for i in 0...24 {
            let t  = Double(i) / 24.0
            let y  = -0.9 + t * 1.9
            let pt = proj(rot(SIMD3(0, y, Self.surfaceZ(x: 0, t: t))))
            if firstPt { midribPath.move(to: pt); firstPt = false }
            else        { midribPath.addLine(to: pt) }
        }
        let midribColor = isFront
            ? Color(red: 0.55, green: 0.80, blue: 0.28).opacity(0.75)
            : Color(red: 0.70, green: 0.84, blue: 0.55).opacity(0.58)
        ctx.stroke(midribPath, with: .color(midribColor),
                   lineWidth: max(1.0, scale * 0.030))

        // ── Secondary veins: 8 pairs, pinnate arrangement ─────────────────────
        // Positions along the midrib (t = 0 base … 1 tip)
        let veinTs: [Double] = [0.12, 0.21, 0.30, 0.40, 0.49, 0.57, 0.65, 0.73]
        let veinColor = isFront
            ? Color(red: 0.42, green: 0.72, blue: 0.22).opacity(0.50)
            : Color(red: 0.62, green: 0.80, blue: 0.48).opacity(0.40)
        let veinW = max(0.5, scale * 0.013)

        for t in veinTs {
            let y      = -0.9 + t * 1.9
            let hw     = Self.halfWidth(t) * 0.83  // reach 83 % toward margin
            let deltaY = hw * 0.40                  // upward angle ~22°
            let yEnd   = y + deltaY
            let tEnd   = min(1.0, (yEnd + 0.9) / 1.9)

            let zMid   = Self.surfaceZ(x: 0,  t: t)
            let zEdgeR = Self.surfaceZ(x:  hw, t: tEnd)
            let zEdgeL = Self.surfaceZ(x: -hw, t: tEnd)

            let vStart = proj(rot(SIMD3(0,  y,    zMid)))
            let vEndR  = proj(rot(SIMD3( hw, yEnd, zEdgeR)))
            let vEndL  = proj(rot(SIMD3(-hw, yEnd, zEdgeL)))

            var vr = Path(); vr.move(to: vStart); vr.addLine(to: vEndR)
            var vl = Path(); vl.move(to: vStart); vl.addLine(to: vEndL)
            ctx.stroke(vr, with: .color(veinColor), lineWidth: veinW)
            ctx.stroke(vl, with: .color(veinColor), lineWidth: veinW)
        }

        // ── Outline stroke ────────────────────────────────────────────────────
        let edgeColor = isFront
            ? Color(red: 0.08, green: 0.30, blue: 0.10).opacity(0.55)
            : Color(red: 0.35, green: 0.52, blue: 0.28).opacity(0.48)
        ctx.stroke(outlinePath, with: .color(edgeColor),
                   lineWidth: max(0.5, scale * 0.016))

        // ── Petiole (stem) ────────────────────────────────────────────────────
        let stemTop = proj(rot(SIMD3(0,     -0.90,  0.00)))
        let stemBot = proj(rot(SIMD3(0.015, -1.22, -0.02)))
        var stemPath = Path()
        stemPath.move(to: stemTop)
        stemPath.addLine(to: stemBot)
        ctx.stroke(stemPath,
                   with: .color(Color(red: 0.28, green: 0.50, blue: 0.14).opacity(0.88)),
                   lineWidth: max(1.0, scale * 0.025))
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

            // X: continuous idle rotation — leaf nods forward/backward, face stays readable.
            if abs(vX) < abs(Self.idleVX) * 2 {
                vX += (Self.idleVX - vX) * min(1.0, dt * 1.5)
            }

            // Y: spring toward face-forward (rotY = 0°) so the leaf never settles edge-on.
            // Normalise to −180…180 so the spring always takes the shortest path back.
            let yMod = rotY.truncatingRemainder(dividingBy: 360)
            let yErr = yMod > 180 ? yMod - 360 : (yMod < -180 ? yMod + 360 : yMod)
            vY -= yErr * Self.springK * dt
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
        LeafView(size: 140)
    }
    .frame(width: 300, height: 300)
}

#Preview("Dark") {
    ZStack {
        Color(red: 0.04, green: 0.10, blue: 0.04)
        LeafView(size: 140)
    }
    .frame(width: 300, height: 300)
    .preferredColorScheme(.dark)
}

#Preview("Large") {
    ZStack {
        Color(red: 0.06, green: 0.06, blue: 0.06)
        LeafView(size: 220)
    }
    .frame(width: 400, height: 400)
    .preferredColorScheme(.dark)
}
