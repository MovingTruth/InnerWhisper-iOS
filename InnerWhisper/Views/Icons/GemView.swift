//
//  StarView.swift
//  InnerWhisper
//

import SwiftUI

/// An animated 3D multi-pointed star fidget icon that can be spun in any direction.
///
/// The star renders as a 3D polyhedron with multiple pointed tips extending from the center.
/// Each tip is rendered with depth shading and specular highlights for a convincing 3D effect.
///
/// Drag in any direction to impart spin; friction decays momentum back to a
/// gentle idle tumble. The star responds to both horizontal and vertical drags,
/// behaving like a physical object in hand.
struct GemView: View {
    /// Diameter of the star's bounding sphere.
    var size: CGFloat = 100
    
    /// Number of points on the star (minimum 4, maximum 12).
    var pointCount: Int = 4
    
    // MARK: - Physics state
    
    /// Rotation around the X axis (degrees). Positive = star tilts top-toward-viewer.
    @State private var rotX: Double = 15
    /// Rotation around the Y axis (degrees). Positive = star turns right.
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
    
    private static let idleVX: Double = 10
    private static let idleVY: Double = -30
    private static let friction: Double = 0.982
    /// Maximum spin speed (deg/sec) — 2 full rotations per second.
    private static let maxSpeed: Double = 720
    
    // MARK: - Star geometry
    
    /// Inner radius factor (how far inward the star points go).
    private static let innerRadiusFactor: Double = 0.4
    
    /// Generate star point positions in 3D.
    /// Points alternate between outer (on unit sphere) and inner (recessed) positions.
    private func starPoints() -> [SIMD3<Double>] {
        let n = max(4, min(12, pointCount))
        var points: [SIMD3<Double>] = []
        
        // Create points around the equator
        for i in 0..<n {
            let angle = Double(i) * 2.0 * .pi / Double(n)
            let outer = SIMD3(cos(angle), sin(angle), 0.0)
            points.append(outer)
        }
        
        // Add top and bottom caps
        points.append(SIMD3(0, 0, 1.2))  // top point
        points.append(SIMD3(0, 0, -1.2)) // bottom point
        
        return points
    }
    
    /// Generate star faces (triangles) for rendering.
    /// Each face is defined by 3 vertex indices and has a normal for lighting.
    private func starFaces() -> [StarFace] {
        let n = max(4, min(12, pointCount))
        var faces: [StarFace] = []
        
        let topIdx = n
        let bottomIdx = n + 1
        
        // Top cap triangles
        for i in 0..<n {
            let next = (i + 1) % n
            faces.append(StarFace(v0: topIdx, v1: i, v2: next))
        }
        
        // Bottom cap triangles
        for i in 0..<n {
            let next = (i + 1) % n
            faces.append(StarFace(v0: bottomIdx, v1: next, v2: i))
        }
        
        return faces
    }
    
    // MARK: - Body
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, canvasSize in
                drawStar(ctx, size: canvasSize)
            }
            .frame(width: size, height: size)
            .shadow(
                color: .black.opacity(0.3),
                radius: size * 0.12,
                x: size * 0.05,
                y: size * 0.08
            )
            .gesture(flickGesture)
            .onChange(of: timeline.date) { date in tick(to: date) }
        }
        .onAppear { lastUpdate = .now }
    }
    
    // MARK: - Drawing
    
    /// Renders the star into a Canvas context.
    private func drawStar(_ ctx: GraphicsContext, size: CGSize) {
        let cx = size.width  / 2
        let cy = size.height / 2
        let radius = min(size.width, size.height) / 2 * 0.85
        
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
        
        let points = starPoints()
        let faces = starFaces()
        
        // Transform all points
        let rotatedPoints = points.map { rot($0) }
        
        // Build and sort faces
        struct RenderFace {
            let z: Double
            let path: Path
            let normal: SIMD3<Double>
        }
        
        var renderFaces: [RenderFace] = []
        
        for face in faces {
            let p0 = rotatedPoints[face.v0]
            let p1 = rotatedPoints[face.v1]
            let p2 = rotatedPoints[face.v2]
            
            // Calculate face normal (cross product)
            let edge1 = SIMD3(p1.x - p0.x, p1.y - p0.y, p1.z - p0.z)
            let edge2 = SIMD3(p2.x - p0.x, p2.y - p0.y, p2.z - p0.z)
            let normal = SIMD3(
                edge1.y * edge2.z - edge1.z * edge2.y,
                edge1.z * edge2.x - edge1.x * edge2.z,
                edge1.x * edge2.y - edge1.y * edge2.x
            )
            
            // Back-face culling
            guard normal.z > 0 else { continue }
            
            // Build path
            var path = Path()
            path.move(to: proj(p0))
            path.addLine(to: proj(p1))
            path.addLine(to: proj(p2))
            path.closeSubpath()
            
            let avgZ = (p0.z + p1.z + p2.z) / 3.0
            renderFaces.append(RenderFace(z: avgZ, path: path, normal: normal))
        }
        
        // Sort back to front
        renderFaces.sort { $0.z < $1.z }
        
        // ── Draw faces ───────────────────────────────────────────────────────
        
        // Light direction (normalized)
        let lightDir = SIMD3<Double>(-0.5, -0.3, 1.0)
        let lightLen = (lightDir.x * lightDir.x + lightDir.y * lightDir.y + lightDir.z * lightDir.z).squareRoot()
        let light = lightDir / lightLen
        
        for face in renderFaces {
            // Calculate lighting
            let normalLen = (face.normal.x * face.normal.x + 
                           face.normal.y * face.normal.y + 
                           face.normal.z * face.normal.z).squareRoot()
            let n = face.normal / normalLen
            
            let diffuse = max(0.0, n.x * light.x + n.y * light.y + n.z * light.z)
            
            // Base color with lighting
            let brightness = 0.3 + diffuse * 0.7
            let color = Color(
                red: 1.0 * brightness,
                green: 0.85 * brightness,
                blue: 0.3 * brightness
            )
            
            ctx.fill(face.path, with: .color(color))
            
            // Edge outline for definition
            ctx.stroke(face.path, with: .color(.black.opacity(0.15)), lineWidth: 0.5)
        }
        
        // Add specular highlights on the front-most faces
        if let frontFace = renderFaces.last {
            ctx.fill(frontFace.path, with: .radialGradient(
                Gradient(stops: [
                    .init(color: .white.opacity(0.4), location: 0.0),
                    .init(color: .clear, location: 1.0),
                ]),
                center: CGPoint(x: cx - radius * 0.2, y: cy - radius * 0.3),
                startRadius: 0,
                endRadius: radius * 0.6
            ))
        }
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

// MARK: - Supporting Types

/// Represents a triangular face of the star.
private struct StarFace {
    let v0: Int  // vertex index
    let v1: Int
    let v2: Int
}

// MARK: - Previews

#Preview("Default – Light") {
    ZStack {
        Color(.systemBackground)
        GemView(size: 120, pointCount: 8)
    }
    .frame(width: 300, height: 300)
}

#Preview("Default – Dark") {
    ZStack {
        Color(.systemBackground)
        GemView(size: 120, pointCount: 8)
    }
    .frame(width: 300, height: 300)
    .preferredColorScheme(.dark)
}

#Preview("Large 5-pointed") {
    ZStack {
        Color(.systemBackground)
        GemView(size: 200, pointCount: 5)
    }
    .frame(width: 400, height: 400)
}

#Preview("12-pointed") {
    ZStack {
        Color(.systemBackground)
        GemView(size: 150, pointCount: 12)
    }
    .frame(width: 400, height: 400)
}
