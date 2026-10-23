//
//  AnimatedSpaceBackground.swift
//  InnerWhisper
//

import SwiftUI
import Metal
import MetalKit

// MARK: - Metal Renderer

/// Owns the Metal device, command queue, and render pipeline.
/// Conforms to `MTKViewDelegate` so `MTKView` calls `draw(in:)` each frame.
private final class SpaceBackgroundRenderer: NSObject, MTKViewDelegate {

    // MARK: Metal objects
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState

    /// Wall-clock time at which the renderer was created, used to compute elapsed seconds.
    private let startTime: CFTimeInterval = CACurrentMediaTime()

    // MARK: Uniforms layout — must match `SpaceUniforms` in SpaceBackground.metal
    private struct SpaceUniforms {
        var time: Float
        var resWidth: Float
        var resHeight: Float
    }

    // MARK: Init

    init?(mtkView: MTKView) {
        guard
            let device = mtkView.device,
            let queue  = device.makeCommandQueue()
        else { return nil }

        self.device       = device
        self.commandQueue = queue

        // Load the compiled Metal library (contains spaceVertex + spaceFragment)
        guard
            let library    = device.makeDefaultLibrary(),
            let vertexFn   = library.makeFunction(name: "spaceVertex"),
            let fragmentFn = library.makeFunction(name: "spaceFragment")
        else { return nil }

        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction   = vertexFn
        desc.fragmentFunction = fragmentFn
        desc.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat

        guard let pipeline = try? device.makeRenderPipelineState(descriptor: desc) else {
            return nil
        }
        self.pipelineState = pipeline

        super.init()
    }

    // MARK: MTKViewDelegate

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard
            let passDesc      = view.currentRenderPassDescriptor,
            let drawable      = view.currentDrawable,
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder       = commandBuffer.makeRenderCommandEncoder(descriptor: passDesc)
        else { return }

        let size = view.drawableSize
        var uniforms = SpaceUniforms(
            time:      Float(CACurrentMediaTime() - startTime),
            resWidth:  Float(size.width),
            resHeight: Float(size.height)
        )

        encoder.setRenderPipelineState(pipelineState)
        encoder.setFragmentBytes(
            &uniforms,
            length: MemoryLayout<SpaceUniforms>.size,
            index: 0
        )
        // Draw 6 vertices (two triangles covering the full screen)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

// MARK: - UIViewRepresentable

/// Bridges `MTKView` into the SwiftUI hierarchy.
private struct MetalSpaceView: UIViewRepresentable {

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        view.device                    = MTLCreateSystemDefaultDevice()
        view.colorPixelFormat          = .bgra8Unorm
        view.preferredFramesPerSecond  = 60
        view.isPaused                  = false
        view.enableSetNeedsDisplay     = false
        view.framebufferOnly           = true
        view.backgroundColor           = .black
        context.coordinator.setup(mtkView: view)
        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {}

    // MARK: Coordinator

    /// Holds the renderer so its lifetime is tied to the view, not the struct.
    final class Coordinator {
        private var renderer: SpaceBackgroundRenderer?

        func setup(mtkView: MTKView) {
            renderer        = SpaceBackgroundRenderer(mtkView: mtkView)
            mtkView.delegate = renderer
        }
    }
}

// MARK: - Public SwiftUI View

/// An animated, Metal-powered deep-space background.
///
/// Features:
/// - Procedurally generated stars across three density layers
/// - Per-star twinkle driven by independent sine oscillators
/// - Soft nebula clouds that slowly breathe
/// - Rare shooting-star streak every ~12 seconds
/// - Radial vignette and Reinhard tone-mapping
///
/// Usage:
/// ```swift
/// ZStack {
///     AnimatedSpaceBackground()
///     Text("Hello, Universe")
///         .foregroundStyle(.white)
/// }
/// ```
struct AnimatedSpaceBackground: View {
    var body: some View {
        MetalSpaceView()
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        AnimatedSpaceBackground()
        VStack {
            Text("Inner Whisper")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
            Text("Look to the stars")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}
