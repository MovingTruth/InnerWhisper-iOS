//
//  StarView.swift
//  InnerWhisper
//

import SwiftUI

/// An animated 3D star fidget icon that can be spun in any direction.
///
/// The star renders as a glowing central sphere with sharp spikes radiating outward.
/// Each spike is rendered with depth shading and the entire star has a glowing yellow appearance.
///
/// Drag in any direction to impart spin; friction decays momentum back to a
/// gentle idle tumble. The star responds to both horizontal and vertical drags,
/// behaving like a physical object in hand.
struct StarView: View {
    /// Diameter of the star's bounding sphere.
    var size: CGFloat = 120
    
    /// Number of spikes radiating from the center (minimum 4, maximum 32).
    var spikeCount: Int = 16
    
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
    
    private static let idleVX: Double = 12
    private static let idleVY: Double = -35
    private static let friction: Double = 0.980
    /// Maximum spin speed (deg/sec) — 2 full rotations per second.
    private static let maxSpeed: Double = 720
    
    // MARK: - Star geometry
    
    /// Core sphere radius (relative to unit scale).
    private static let coreRadius: Double = 0.35
    
    /// Spike length from core surface.
    private static let spikeLength: Double = 0.85
    
    /// Generate spike directions in 3D space.
    /// Uses a fibonacci sphere algorithm for even distribution.
    private func spikeDirections() -> [SIMD3<Double>] {
        let n = max(4, min(32, spikeCount))
        var directions: [SIMD3<Double>] = []
        
        let goldenRatio = (1.0 + sqrt(5.0)) / 2.0
        let angleIncrement = .pi * 2.0 * goldenRatio
        
        for i in 0..<n {
            let t = Double(i) / Double(n)
            let inclination = acos(1.0 - 2.0 * t)
            let azimuth = angleIncrement * Double(i)
            
            let x = sin(inclination) * cos(azimuth)
            let y = sin(inclination) * sin(azimuth)
            let z = cos(inclination)
            
            directions.append(SIMD3(x, y, z))
        }
        
        return directions
    }
    
    /// Generate spike geometry.
    /// Each spike is a cone extending from the core sphere.
    private func generateSpikes() -> [Spike] {
        let directions = spikeDirections()
        var spikes: [Spike] = []
        
        for dir in directions {
            // Base of spike (on core surface)
            let base = dir * Self.coreRadius
            // Tip of spike
            let tip = dir * (Self.coreRadius + Self.spikeLength)
            
            spikes.append(Spike(base: base, tip: tip, direction: dir))
        }
        
        return spikes
    }
    
    // MARK: - Body
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, canvasSize in
                drawStar(ctx, size: canvasSize)
            }
            .frame(width: size, height: size)
            .shadow(
                color: .yellow.opacity(0.4),
                radius: size * 0.15,
                x: 0,
                y: 0
            )
            .shadow(
                color: .yellow.opacity(0.3),
                radius: size * 0.25,
                x: 0,
                y: 0
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
        
        let spikes = generateSpikes()
        
        // Transform and prepare spikes for rendering
        struct RenderSpike {
            let z: Double
            let basePos: SIMD3<Double>
            let tipPos: SIMD3<Double>
            let direction: SIMD3<Double>
            let facingViewer: Bool
        }
        
        var renderSpikes: [RenderSpike] = []
        
        for spike in spikes {
            let rotBase = rot(spike.base)
            let rotTip = rot(spike.tip)
            let rotDir = rot(spike.direction)
            
            // Check if spike is facing viewer
            let facingViewer = rotDir.z > 0
            
            // Use tip Z for sorting
            renderSpikes.append(RenderSpike(
                z: rotTip.z,
                basePos: rotBase,
                tipPos: rotTip,
                direction: rotDir,
                facingViewer: facingViewer
            ))
        }
        
        // Sort back to front for proper layering
        renderSpikes.sort { $0.z < $1.z }
        
        // ── Draw spikes ──────────────────────────────────────────────────────
        
        // Light direction (normalized)
        let lightDir = SIMD3<Double>(-0.4, -0.3, 1.0)
        let lightLen = sqrt(lightDir.x * lightDir.x + lightDir.y * lightDir.y + lightDir.z * lightDir.z)
        let light = lightDir / lightLen
        
        for spike in renderSpikes {
            guard spike.facingViewer else { continue }
            
            // Calculate lighting
            let dirLen = sqrt(spike.direction.x * spike.direction.x + 
                            spike.direction.y * spike.direction.y + 
                            spike.direction.z * spike.direction.z)
            let normDir = spike.direction / dirLen
            
            let diffuse = max(0.0, normDir.x * light.x + normDir.y * light.y + normDir.z * light.z)
            
            // Glow intensity based on facing
            let facingAmount = max(0.0, normDir.z)
            let glowIntensity = 0.4 + diffuse * 0.4 + facingAmount * 0.3
            
            // Yellow glow color
            let color = Color(
                red: 1.0,
                green: 0.95 * glowIntensity,
                blue: 0.2 * glowIntensity
            )
            
            // Draw spike as a triangle (simple side view)
            let tipPoint = proj(spike.tipPos)
            let basePoint = proj(spike.basePos)
            
            // Calculate perpendicular for spike width
            let dx = tipPoint.x - basePoint.x
            let dy = tipPoint.y - basePoint.y
            let len = sqrt(dx * dx + dy * dy)
            
            if len > 0.1 {
                let perpX = -dy / len * radius * 0.08
                let perpY = dx / len * radius * 0.08
                
                var spikePath = Path()
                spikePath.move(to: tipPoint)
                spikePath.addLine(to: CGPoint(x: basePoint.x + perpX, y: basePoint.y + perpY))
                spikePath.addLine(to: CGPoint(x: basePoint.x - perpX, y: basePoint.y - perpY))
                spikePath.closeSubpath()
                
                ctx.fill(spikePath, with: .color(color))
                
                // Brighter edge on the lit side
                if diffuse > 0.5 {
                    var edgePath = Path()
                    edgePath.move(to: tipPoint)
                    edgePath.addLine(to: CGPoint(x: basePoint.x + perpX, y: basePoint.y + perpY))
                    ctx.stroke(edgePath, with: .color(.white.opacity(diffuse * 0.6)), lineWidth: 1.0)
                }
            }
        }
        
        // ── Draw core sphere ─────────────────────────────────────────────────
        
        let coreRadius = Self.coreRadius * radius
        let coreRect = CGRect(
            x: cx - coreRadius,
            y: cy - coreRadius,
            width: coreRadius * 2,
            height: coreRadius * 2
        )
        let corePath = Path(ellipseIn: coreRect)
        
        // Base glow
        ctx.fill(corePath, with: .radialGradient(
            Gradient(stops: [
                .init(color: Color(red: 1.0, green: 1.0, blue: 0.7), location: 0.0),
                .init(color: Color(red: 1.0, green: 0.9, blue: 0.3), location: 0.5),
                .init(color: Color(red: 0.95, green: 0.75, blue: 0.15), location: 1.0),
            ]),
            center: CGPoint(x: cx, y: cy),
            startRadius: 0,
            endRadius: coreRadius
        ))
        
        // Specular highlight on core
        ctx.fill(corePath, with: .radialGradient(
            Gradient(stops: [
                .init(color: .white.opacity(0.9), location: 0.0),
                .init(color: .white.opacity(0.3), location: 0.3),
                .init(color: .clear, location: 0.6),
            ]),
            center: CGPoint(x: cx - coreRadius * 0.3, y: cy - coreRadius * 0.3),
            startRadius: 0,
            endRadius: coreRadius * 0.7
        ))
        
        // Outer glow
        ctx.fill(corePath, with: .radialGradient(
            Gradient(stops: [
                .init(color: .clear, location: 0.7),
                .init(color: Color.yellow.opacity(0.15), location: 1.0),
            ]),
            center: CGPoint(x: cx, y: cy),
            startRadius: coreRadius * 0.7,
            endRadius: coreRadius * 1.3
        ))
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

/// Represents a spike extending from the core.
private struct Spike {
    let base: SIMD3<Double>      // Position on core surface
    let tip: SIMD3<Double>       // Tip of the spike
    let direction: SIMD3<Double> // Normalized direction
}

// MARK: - Previews

#Preview("Default – Light") {
    ZStack {
        Color(.systemBackground)
        StarView(size: 120, spikeCount: 16)
    }
    .frame(width: 300, height: 300)
}

#Preview("Default – Dark") {
    ZStack {
        Color(.systemBackground)
        StarView(size: 120, spikeCount: 16)
    }
    .frame(width: 300, height: 300)
    .preferredColorScheme(.dark)
}

#Preview("Large 24-spike") {
    ZStack {
        Color.black
        StarView(size: 200, spikeCount: 24)
    }
    .frame(width: 400, height: 400)
}

#Preview("Maximum 32-spike") {
    ZStack {
        Color(.systemBackground)
        StarView(size: 150, spikeCount: 32)
    }
    .frame(width: 400, height: 400)
}
