//
//  YinYangView.swift
//  InnerWhisper
//

import SwiftUI

/// An animated 3D-style yin yang symbol that behaves like a wheel on a bearing.
///
/// The symbol spins continuously on its Z-axis while rhythmically tilting in 3D.
/// Drag or flick anywhere on it to add spin momentum — faster flicks produce higher
/// angular velocity. Friction then decays the momentum until the symbol returns to
/// its gentle idle spin.
///
/// Colors default to `.primary` / `.systemBackground` so the symbol adapts
/// automatically to light and dark mode and to any theme foreground colour.
struct YinYangView: View {
    /// Diameter of the symbol.
    var size: CGFloat = 60
    /// The dark (yin) fill.
    var darkColor: Color = Color(.label)
    /// The light (yang) fill.
    var lightColor: Color = Color(.systemBackground)
    /// When `true`, disables drag, 3D wobble, and internal spin so a parent `rotationEffect` fully controls rotation (e.g. launch splash).
    var isControlledRotation: Bool = false

    // MARK: - Physics state

    /// Current rotation in degrees (driven by physics, not a SwiftUI animation).
    @State private var spinAngle: Double = 0
    /// Angular velocity in degrees per second. Negative = counter-clockwise.
    @State private var angularVelocity: Double = Self.idleSpeed
    /// Timestamp of the last physics tick, used to compute Δt.
    @State private var lastUpdate: Date = .now
    /// Stable start for `TimelineView.periodic` — do not use `.now` inline or each `body`
    /// evaluation creates a new schedule and can main-thread spin / freeze the app.
    @State private var physicsTimelineStart = Date()
    /// True while a drag gesture is active (suppresses friction restore).
    @State private var isDragging: Bool = false

    // MARK: - Gesture tracking

    /// Angle of the previous touch point relative to the symbol centre (degrees).
    @State private var lastDragAngle: Double? = nil
    /// Timestamp of the previous touch sample, used to derive velocity.
    @State private var lastDragTime: Date? = nil

    // MARK: - Wobble (3D tilt; off when `isControlledRotation`)

    @State private var wobbleAngle: Double = 0

    // MARK: - Constants

    /// Gentle idle spin speed (degrees/sec). Negative = counter-clockwise.
    private static let idleSpeed: Double = -30
    /// Per-frame friction multiplier at 60 fps. Lower = more drag.
    private static let friction: Double = 0.982
    /// Maximum spin speed (degrees/sec) — 4 full rotations per second.
    private static let maxSpeed: Double = 1440
    /// Full back-and-forth wobble period (seconds); matches former 3.5s ease each way.
    private static let wobblePeriod: Double = 7.0
    /// Peak 3D tilt (degrees) for idle wobble.
    private static let wobbleAmplitude: Double = 14.0

    // MARK: - Body

    var body: some View {
        // Use a fixed cadence — drive wobble from the same `TimelineView` ticks as spin physics.
        // A separate `withAnimation(.repeatForever)` desyncs during navigation transitions and can
        // leave the icon stuck at a tilt until the view is recreated.
        TimelineView(.periodic(from: physicsTimelineStart, by: 1.0 / 60.0)) { context in
            symbolView
                .onChange(of: context.date) { _, date in
                    tick(to: date)
                }
        }
        .onAppear {
            lastUpdate = .now
            if isControlledRotation {
                wobbleAngle = 0
            }
        }
    }

    @ViewBuilder
    private var symbolView: some View {
        let base = symbol
            .frame(width: size, height: size)
            .rotationEffect(.degrees(spinAngle))
            .shadow(
                color: darkColor.opacity(0.3),
                radius: size * 0.12,
                x: 0,
                y: size * 0.06
            )

        if isControlledRotation {
            base
        } else {
            base
                .rotation3DEffect(
                    .degrees(wobbleAngle),
                    axis: (x: 1, y: 0.25, z: 0),
                    perspective: 0.7
                )
                .gesture(flickGesture)
        }
    }

    // MARK: - Symbol

    /// Builds the yin yang by layering filled shapes.
    ///
    /// Construction order:
    /// 1. Dark full circle (yin base)
    /// 2. Light right semicircle (yang base)
    /// 3. Light small circle offset upward — yang "head" that creates the upper S-curve
    /// 4. Dark small circle offset downward — yin "head" that reclaims the lower S-curve
    /// 5. Small dark dot inside the yang head
    /// 6. Small light dot inside the yin head
    /// 7. Clip the whole stack to the outer circle
    private var symbol: some View {
        ZStack {
            Circle()
                .fill(darkColor)

            RightSemicircle()
                .fill(lightColor)

            Circle()
                .fill(lightColor)
                .frame(width: size / 2, height: size / 2)
                .offset(y: -size / 4)

            Circle()
                .fill(darkColor)
                .frame(width: size / 2, height: size / 2)
                .offset(y: size / 4)

            Circle()
                .fill(darkColor)
                .frame(width: size / 6, height: size / 6)
                .offset(y: -size / 4)

            Circle()
                .fill(lightColor)
                .frame(width: size / 6, height: size / 6)
                .offset(y: size / 4)
        }
        .clipShape(Circle())
    }

    // MARK: - Physics

    /// Advances the spin simulation by one display frame.
    ///
    /// Each tick applies exponential friction to the current angular velocity,
    /// then smoothly restores toward idle speed once momentum has decayed.
    private func tick(to date: Date) {
        let dt = date.timeIntervalSince(lastUpdate)
        lastUpdate = date
        // Skip large gaps (e.g. view returning from background) to avoid jumps.
        guard dt > 0, dt < 0.1 else { return }
        guard !isControlledRotation else { return }

        if !isDragging {
            // Exponential friction: identical feel regardless of frame rate.
            let framesElapsed = dt * 60
            angularVelocity *= pow(Self.friction, framesElapsed)

            // Once momentum decays to within 2× idle, smoothly restore idle spin.
            if abs(angularVelocity) < abs(Self.idleSpeed) * 2 {
                // Lerp toward idle — converges in ~0.7 s so the restoration feels organic.
                angularVelocity += (Self.idleSpeed - angularVelocity) * min(1.0, dt * 1.5)
            }
        }

        let t = date.timeIntervalSince(physicsTimelineStart)
        let newWobble = sin(t * 2 * .pi / Self.wobblePeriod) * Self.wobbleAmplitude

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            spinAngle += angularVelocity * dt
            wobbleAngle = newWobble
        }
    }

    // MARK: - Gesture

    /// A drag gesture that converts tangential finger motion into angular momentum.
    ///
    /// The angular velocity is derived from the change in the angle of the touch
    /// point around the symbol's centre, giving an intuitive "spinning wheel" feel
    /// regardless of where on the disc the user drags.
    private var flickGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                isDragging = true

                let center = CGPoint(x: size / 2, y: size / 2)
                // Angle of the current touch point relative to the symbol centre.
                let angle = atan2(
                    value.location.y - center.y,
                    value.location.x - center.x
                ) * 180 / .pi

                let now = Date()

                if let prevAngle = lastDragAngle, let prevTime = lastDragTime {
                    let dt = now.timeIntervalSince(prevTime)
                    if dt > 0 {
                        // Shortest-arc delta so we handle the ±180° wrap correctly.
                        var delta = angle - prevAngle
                        if delta > 180  { delta -= 360 }
                        if delta < -180 { delta += 360 }

                        let sampledVelocity = delta / dt
                        // Blend with current velocity to smooth out noisy samples.
                        let blended = angularVelocity * 0.3 + sampledVelocity * 0.7
                        angularVelocity = max(-Self.maxSpeed, min(Self.maxSpeed, blended))
                    }
                }

                lastDragAngle = angle
                lastDragTime = now
                lastUpdate = now
            }
            .onEnded { _ in
                isDragging = false
                lastDragAngle = nil
                lastDragTime = nil
            }
    }
}

// MARK: - Right semicircle helper

/// The right-hand D-shaped half of a circle (used for the yang base layer).
private struct RightSemicircle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        // Arc from top (−90°) to bottom (+90°) going clockwise visually (right side).
        // In SwiftUI's flipped-Y system, clockwise: false produces visually clockwise motion.
        path.addArc(
            center: center, radius: radius,
            startAngle: .degrees(-90), endAngle: .degrees(90),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Previews

#Preview("Default – Light") {
    ZStack {
        Color(.systemBackground)
        YinYangView(size: 120)
    }
    .frame(width: 300, height: 300)
}

#Preview("Default – Dark") {
    ZStack {
        Color(.systemBackground)
        YinYangView(size: 120)
    }
    .frame(width: 300, height: 300)
    .preferredColorScheme(.dark)
}

#Preview("Large") {
    ZStack {
        Color(.systemBackground)
        YinYangView(size: 200)
    }
    .frame(width: 400, height: 400)
}

#Preview("Custom colours") {
    ZStack {
        Color.indigo.opacity(0.08)
        YinYangView(size: 120, darkColor: .indigo, lightColor: .mint)
    }
    .frame(width: 300, height: 300)
}
