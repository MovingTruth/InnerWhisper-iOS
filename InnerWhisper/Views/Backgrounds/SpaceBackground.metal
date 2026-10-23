//
//  SpaceBackground.metal
//  InnerWhisper
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Shared Types

struct SpaceUniforms {
    float time;
    float resWidth;
    float resHeight;
};

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

// MARK: - Utility: Pseudo-Random Hash

/// Hash a 2D coordinate to a pseudo-random float2 in [0,1)
float2 hash2(float2 p) {
    p = float2(dot(p, float2(127.1, 311.7)),
               dot(p, float2(269.5, 183.3)));
    return fract(sin(p) * 43758.5453123);
}

/// Hash a 2D coordinate to a single pseudo-random float in [0,1)
float hash1(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453123);
}

// MARK: - Vertex Shader

/// Full-screen quad (two triangles)
vertex VertexOut spaceVertex(uint vertexID [[vertex_id]]) {
    const float2 positions[6] = {
        float2(-1, -1), float2( 1, -1), float2(-1,  1),
        float2(-1,  1), float2( 1, -1), float2( 1,  1)
    };
    // UV: (0,0) = bottom-left in Metal, but we want (0,0) = top-left
    const float2 uvs[6] = {
        float2(0, 1), float2(1, 1), float2(0, 0),
        float2(0, 0), float2(1, 1), float2(1, 0)
    };
    VertexOut out;
    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.uv = uvs[vertexID];
    return out;
}

// MARK: - Star Layer

/// Renders one layer of procedural stars using a regular cell grid.
/// Each cell may contain at most one star, placed at a hash-derived position.
/// Stars twinkle via per-star sine oscillators keyed to `time`.
/// The layer drifts slowly in `drift` UV-units-per-second, creating parallax depth.
///
/// - Parameters:
///   - uv:       Normalised screen coordinate [0,1]²
///   - time:     Elapsed seconds (drives twinkle and drift)
///   - cellSize: Grid cell size in UV space — smaller = denser stars
///   - density:  Fraction of cells that contain a star [0,1]
///   - drift:    UV-units-per-second velocity vector for this depth plane
float3 starLayer(float2 uv, float time, float cellSize, float density, float2 drift) {
    // Offset UV by accumulated drift; floor()/fract() below wrap seamlessly
    float2 driftedUV = uv + drift * time;
    float2 grid  = driftedUV / cellSize;
    float2 cellID = floor(grid);
    float2 frac  = fract(grid);

    float3 result = float3(0.0);

    // Sample the 3×3 neighbourhood so stars near cell edges remain visible
    for (int iy = -1; iy <= 1; iy++) {
        for (int ix = -1; ix <= 1; ix++) {
            float2 nb = float2(ix, iy);
            float2 id = cellID + nb;
            float2 h  = hash2(id);

            // Skip this cell if no star should appear here
            if (h.x > density) continue;

            // Place the star at a jittered position inside the cell
            float2 starPos = nb + h;
            float  dist    = length(frac - starPos);

            // Per-star twinkle: unique angular speed and phase offset
            float speed  = hash1(id + float2(7.3, 2.1)) * 2.5 + 0.5;
            float phase  = hash1(id + float2(3.7, 9.2)) * 6.2832;
            float bri    = 0.35 + 0.65 * (0.5 + 0.5 * sin(time * speed + phase));

            // Size variation: larger for "closer" stars
            float sz     = hash1(id + float2(1.3, 5.7)) * 0.014 + 0.003;

            // Wide soft glow + tight bright core
            float glow   = exp(-dist * dist / (sz * sz * 10.0));
            float core   = exp(-dist * dist / (sz * sz * 0.4));
            float star   = (glow * 0.35 + core) * bri;

            // Subtle colour tint: cooler blue-white vs warmer yellow-white
            float tint   = hash1(id + float2(5.1, 8.3));
            float3 col   = mix(float3(0.85, 0.92, 1.0), float3(1.0, 0.97, 0.85), tint);

            result += col * star;
        }
    }

    return result;
}

// MARK: - Nebula Clouds

/// Soft, slowly-breathing nebula glow to break up the uniform darkness.
float3 nebula(float2 uv, float time) {
    float3 col = float3(0.0);

    // Purple-blue cloud on the upper-left
    float2 c1 = float2(0.25, 0.32);
    float  d1 = length(uv - c1);
    float  n1 = smoothstep(0.55, 0.0, d1);
    float  b1 = 0.85 + 0.15 * sin(time * 0.25 + 1.3);
    col += float3(0.055, 0.01, 0.11) * n1 * n1 * b1;

    // Deep-blue wisp on the right
    float2 c2 = float2(0.72, 0.58);
    float  d2 = length(uv - c2);
    float  n2 = smoothstep(0.42, 0.0, d2);
    float  b2 = 0.85 + 0.15 * sin(time * 0.2 + 3.7);
    col += float3(0.01, 0.025, 0.09) * n2 * n2 * b2;

    // Faint teal arc across the lower third
    float2 c3 = float2(0.5, 0.75);
    float  d3 = length(uv - c3);
    float  n3 = smoothstep(0.35, 0.0, d3);
    float  b3 = 0.85 + 0.15 * sin(time * 0.18 + 0.9);
    col += float3(0.005, 0.04, 0.07) * n3 * n3 * b3;

    return col;
}

// MARK: - Fragment Shader

/// Composites background gradient + nebulae + three star layers + shooting star + vignette.
fragment float4 spaceFragment(VertexOut in [[stage_in]],
                               constant SpaceUniforms& u [[buffer(0)]]) {
    float2 uv = in.uv;

    // Deep-space gradient: dark indigo at top → near-black at bottom
    float3 topCol    = float3(0.025, 0.042, 0.15);
    float3 bottomCol = float3(0.006, 0.006, 0.025);
    float3 color     = mix(topCol, bottomCol, uv.y);

    // Nebula clouds
    color += nebula(uv, u.time);

    // Three star layers with parallax drift — "closer" planes move faster and in distinct directions.
    // Layer 1: large, sparse — foreground plane, drifts right and very slightly upward
    color += starLayer(uv, u.time, 0.065, 0.22, float2( 0.0032,  0.0007));
    // Layer 2: medium — mid plane, drifts left and slightly downward
    color += starLayer(uv, u.time, 0.032, 0.18, float2(-0.0014,  0.0010));
    // Layer 3: small, dense — far background, barely moves, slight diagonal
    color += starLayer(uv, u.time, 0.016, 0.14, float2( 0.0005, -0.0003));

    // Radial vignette to darken corners
    float2 centered = uv - 0.5;
    float  vignette  = 1.0 - dot(centered, centered) * 1.5;
    color *= saturate(vignette);

    // Reinhard tone-map to prevent bloom clipping
    color = color / (color + 0.28);

    return float4(color, 1.0);
}
