//
//  ForestBackground.metal
//  InnerWhisper
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Types
// All names carry an `f` prefix to avoid linker conflicts with SpaceBackground.metal.

struct ForestUniforms {
    float time;
    float resWidth;
    float resHeight;
};

struct FVertexOut {
    float4 position [[position]];
    float2 uv;
};

// MARK: - Utilities

float2 fhash2(float2 p) {
    p = float2(dot(p, float2(127.1, 311.7)), dot(p, float2(269.5, 183.3)));
    return fract(sin(p) * 43758.5453123);
}
float fhash1(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453123);
}
float fhash1f(float v) {
    return fract(sin(v * 127.1) * 43758.5453123);
}
float fvnoise(float x, float seed) {
    float i = floor(x); float f = fract(x);
    float t = f * f * (3.0 - 2.0 * f);
    return mix(fhash1(float2(i, seed)), fhash1(float2(i + 1.0, seed)), t);
}

// MARK: - Single Tree Shape

/// Returns opacity (0 = air, 1 = solid) for one conifer tree.
/// Composed of a narrow trunk (lower 22% of height) and a triangular canopy
/// that tapers from full width at the trunk to a point at the tip.
/// The `sway` argument shifts the whole tree horizontally.
float singleConifer(float2 uv, float treeX, float treeBase,
                    float treeH, float halfW, float trunkHW, float sway) {
    float sx = uv.x - (treeX + sway);
    float dy = treeBase - uv.y;     // positive = above base

    if (dy < 0.0 || dy > treeH) return 0.0;

    // Trunk: bottom 22 % of the tree
    float trunkTop = treeH * 0.22;
    if (dy < trunkTop) return abs(sx) < trunkHW ? 0.92 : 0.0;

    // Canopy: linearly tapering triangle → pointy tip, clear silhouette
    float rel = (dy - trunkTop) / (treeH - trunkTop);  // 0 at trunk-top, 1 at tip
    float w   = halfW * (1.0 - rel);
    return abs(sx) < w ? 1.0 : 0.0;
}

// MARK: - Tree Layer

/// Renders one parallax layer of conifers. Returns the opacity at `uv`
/// (0 = gap between trees / sky visible, 1 = inside a tree).
/// Uses an explicit if/else for layer parameters to avoid dynamic array indexing.
float treeLayerOpacity(float2 uv, float time, int layer) {

    // Per-layer parameters (avoid dynamic array index for MSL safety)
    float cw, baseY, minH, maxH, canScale, trunkScale, sAmp, sFreq, gapFrac, seed;
    if (layer == 0) {
        // Background: small dense trees
        cw=0.11; baseY=0.71; minH=0.16; maxH=0.27; canScale=0.21;
        trunkScale=0.022; sAmp=0.003; sFreq=0.38; gapFrac=0.18; seed=0.0;
    } else if (layer == 1) {
        // Mid-ground
        cw=0.15; baseY=0.80; minH=0.27; maxH=0.43; canScale=0.27;
        trunkScale=0.030; sAmp=0.005; sFreq=0.31; gapFrac=0.22; seed=17.3;
    } else {
        // Foreground: tall trees, widest spacing so sky shows between trunks
        cw=0.21; baseY=0.92; minH=0.42; maxH=0.65; canScale=0.31;
        trunkScale=0.038; sAmp=0.008; sFreq=0.24; gapFrac=0.28; seed=34.6;
    }

    float gridX = uv.x / cw;
    int   cell  = int(floor(gridX));
    float result = 0.0;

    for (int c = cell - 1; c <= cell + 2; c++) {
        float2 id = float2(float(c), seed);
        float2 h  = fhash2(id);

        // Leave some cells empty so the layer behind shows through
        if (h.x < gapFrac) continue;

        float treeX   = (float(c) + 0.1 + h.x * 0.8) * cw;
        float treeH   = minH + h.y * (maxH - minH);
        float halfW   = cw * canScale * (0.65 + h.x * 0.70);
        float trunkHW = cw * trunkScale;

        // Primary wind sway + slower secondary gust
        float sway = sin(time * sFreq       + treeX * 4.5) * sAmp
                   + sin(time * 0.17        + treeX * 2.1) * sAmp * 0.40;

        result = max(result, singleConifer(uv, treeX, baseY, treeH, halfW, trunkHW, sway));
    }
    return result;
}

// MARK: - Sky

/// Dawn/dusk gradient: deep indigo zenith → warm amber glow at the treeline.
float3 forestSky(float2 uv, float time) {
    float3 zenith  = float3(0.012, 0.016, 0.085);
    float3 midSky  = float3(0.030, 0.022, 0.110);

    float t1  = smoothstep(0.0, 0.60, uv.y);
    float3 sky = mix(zenith, midSky, t1);

    // Warm amber horizon band (sits just above/at the treeline ~y=0.67)
    float warm = exp(-pow((uv.y - 0.67) / 0.095, 2.0));
    sky = mix(sky, float3(0.30, 0.10, 0.04), warm * 0.55);

    // Cool purple just above the warm band
    float cool = exp(-pow((uv.y - 0.53) / 0.075, 2.0));
    sky = mix(sky, float3(0.055, 0.022, 0.075), cool * 0.25);

    sky *= 0.88 + 0.12 * sin(time * 0.18);   // gentle atmosphere breathing
    return sky;
}

// MARK: - Stars

float3 forestStars(float2 uv, float time) {
    const float cellSize = 0.038;
    const float density  = 0.10;

    float2 grid = uv / cellSize;
    float2 cid  = floor(grid);
    float2 frac = fract(grid);
    float3 out  = float3(0.0);

    for (int iy = -1; iy <= 1; iy++) {
        for (int ix = -1; ix <= 1; ix++) {
            float2 nb = float2(ix, iy);
            float2 id = cid + nb;
            float2 h  = fhash2(id);
            if (h.x > density) continue;
            float dist = length(frac - (nb + h));
            float bri  = 0.30 + 0.50 * sin(time * (0.5 + h.x * 1.5) + h.y * 6.28);
            float sz   = 0.003 + h.y * 0.007;
            out += float3(0.85, 0.90, 1.0) * exp(-dist*dist/(sz*sz*0.4)) * bri;
        }
    }
    // Only visible high in the sky, fade out before the treeline
    return out * smoothstep(0.46, 0.26, uv.y);
}

// MARK: - Dawn Light Shafts

/// Fan of warm shafts from the left-horizon, partially blocked by the tree layers
/// rendered after this pass.
float3 dawnShafts(float2 uv, float time) {
    float3 col  = float3(0.0);
    float2 src  = float2(-0.04, 0.67);

    for (int i = 0; i < 5; i++) {
        float fi  = float(i);
        float ang = -0.28 + fi * 0.11;
        float2 dir = normalize(float2(cos(ang), -sin(ang)));
        float2 dv  = uv - src;
        float along = dot(dv, dir);
        float perp  = dot(dv, float2(-dir.y, dir.x));

        if (along < 0.0) continue;

        float w     = (0.016 + fhash1f(fi * 2.9) * 0.012) * (1.0 + along * 0.35);
        float beam  = exp(-perp * perp / (w * w));
        float fade  = exp(-along * 1.5);
        float pulse = 0.82 + 0.18 * sin(time * 0.20 + fi * 1.2);

        col += float3(0.40, 0.18, 0.05) * beam * fade * pulse * 0.30;
    }
    return col;
}

// MARK: - Mist

float3 forestMist(float2 uv, float time) {
    float n0 = fvnoise(uv.x * 3.5 + time * 0.012, 4.2);
    float n1 = fvnoise(uv.x * 7.0 - time * 0.009, 9.8);
    float density = n0 * n1;

    // Two bands: one near the ground, one mid-forest
    float b0 = exp(-pow((uv.y - 0.80) / 0.050, 2.0));
    float b1 = exp(-pow((uv.y - 0.65) / 0.038, 2.0));

    float3 warmMist = float3(0.38, 0.22, 0.10);   // warm near ground (dawn)
    float3 coolMist = float3(0.24, 0.30, 0.36);   // cool higher up

    return (warmMist * b0 * 0.20 + coolMist * b1 * 0.10) * density;
}

// MARK: - Fireflies

float3 forestFireflies(float2 uv, float time) {
    float3 col = float3(0.0);
    for (int i = 0; i < 14; i++) {
        float fi  = float(i);
        float bx  = fhash1f(fi * 2.39 + 0.1);
        float by  = 0.40 + fhash1f(fi * 2.39 + 0.2) * 0.42;
        float sx  = fhash1f(fi * 2.39 + 0.3) * 0.10 + 0.04;
        float sy  = fhash1f(fi * 2.39 + 0.4) * 0.06 + 0.02;
        float ax  = fhash1f(fi * 2.39 + 0.5) * 0.06 + 0.02;
        float ay  = fhash1f(fi * 2.39 + 0.6) * 0.03 + 0.01;
        float phx = fhash1f(fi * 2.39 + 0.7) * 6.28;
        float phy = fhash1f(fi * 2.39 + 0.8) * 6.28;
        float br  = fhash1f(fi * 2.39 + 0.9) * 2.5 + 1.2;
        float bph = fhash1f(fi * 2.39 + 1.0) * 6.28;

        float2 pos  = float2(bx + sin(time * sx + phx) * ax,
                             by + sin(time * sy + phy) * ay);
        float blink = pow(max(0.0, sin(br * time + bph)), 3.0);
        float2 d    = uv - pos;
        float  r    = dot(d, d);

        col += float3(0.35, 0.80, 0.20) * exp(-r * 500.0)  * blink;
        col += float3(0.90, 1.00, 0.60) * exp(-r * 6000.0) * blink;
    }
    return col;
}

// MARK: - Vertex

vertex FVertexOut forestVertex(uint vertexID [[vertex_id]]) {
    const float2 pos[6] = {
        float2(-1,-1), float2(1,-1), float2(-1,1),
        float2(-1, 1), float2(1,-1), float2(1, 1)
    };
    const float2 uvs[6] = {
        float2(0,1), float2(1,1), float2(0,0),
        float2(0,0), float2(1,1), float2(1,0)
    };
    FVertexOut out;
    out.position = float4(pos[vertexID], 0.0, 1.0);
    out.uv       = uvs[vertexID];
    return out;
}

// MARK: - Fragment

/// Composites the night-forest scene back-to-front:
///  1. Dawn/dusk sky gradient
///  2. Stars (upper sky)
///  3. Warm dawn light shafts
///  4. Three tree layers — each with individual conifer shapes (trunk + triangle canopy)
///     and visible gaps so the sky and deeper layers show through
///  5. Ground
///  6. Drifting mist bands
///  7. Fireflies
///  8. Vignette + Reinhard tone map
fragment float4 forestFragment(FVertexOut in [[stage_in]],
                                constant ForestUniforms& u [[buffer(0)]]) {
    float2 uv = in.uv;

    // 1. Sky
    float3 color = forestSky(uv, u.time);

    // 2. Stars
    color += forestStars(uv, u.time);

    // 3. Dawn shafts (behind the trees — they'll be partly occluded naturally)
    color += dawnShafts(uv, u.time);

    // 4. Tree layers — back to front, each using explicit if/else for treeColor
    for (int layer = 0; layer < 3; layer++) {
        float opacity = treeLayerOpacity(uv, u.time, layer);
        float3 treeCol;
        if      (layer == 0) treeCol = float3(0.055, 0.095, 0.038);  // back: dark teal-green
        else if (layer == 1) treeCol = float3(0.022, 0.050, 0.016);  // mid: darker
        else                 treeCol = float3(0.007, 0.014, 0.004);  // front: near-black
        color = mix(color, treeCol, opacity);
    }

    // 5. Ground
    color = mix(color, float3(0.014, 0.020, 0.007), smoothstep(0.885, 0.910, uv.y));

    // 6. Mist
    color += forestMist(uv, u.time);

    // 7. Fireflies
    color += forestFireflies(uv, u.time);

    // 8. Vignette
    float2 c = uv - 0.5;
    color *= saturate(1.0 - dot(c, c) * 1.20);

    // Reinhard
    color = color / (color + 0.22);

    return float4(color, 1.0);
}
