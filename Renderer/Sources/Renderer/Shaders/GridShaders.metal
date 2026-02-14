#include <metal_stdlib>
using namespace metal;

// ─── Grid Plane Shaders ─────────────────────────────────────────────────────
// Renders an infinite-feel ground plane grid at Y=0.
// Major grid lines every 10 units, minor every 1 unit.
// Grid fades out with distance from camera.

struct GridUniforms {
    float4x4 viewProjection;
    float4   cameraPositionPad;  // xyz = position, w = unused
};

struct GridVertexOut {
    float4 position [[position]];
    float3 worldPosition;
};

vertex GridVertexOut grid_vertex(
    uint                   vid      [[vertex_id]],
    constant GridUniforms& uniforms [[buffer(0)]])
{
    // Generate a large quad at Y=0 (two triangles, 6 vertices)
    float size = 500.0;
    float2 positions[6] = {
        float2(-size, -size),
        float2( size, -size),
        float2(-size,  size),
        float2(-size,  size),
        float2( size, -size),
        float2( size,  size)
    };

    GridVertexOut out;
    float3 worldPos = float3(positions[vid].x, 0.0, positions[vid].y);
    out.position = uniforms.viewProjection * float4(worldPos, 1.0);
    out.worldPosition = worldPos;
    return out;
}

fragment float4 grid_fragment(
    GridVertexOut          in       [[stage_in]],
    constant GridUniforms& uniforms [[buffer(0)]])
{
    float2 coord = in.worldPosition.xz;

    // Distance-based fade
    float dist = length(in.worldPosition - uniforms.cameraPositionPad.xyz);
    float fadeFactor = 1.0 - saturate(dist / 200.0);
    fadeFactor = fadeFactor * fadeFactor;

    if (fadeFactor < 0.01) discard_fragment();

    // Anti-aliased grid lines using screen-space derivatives
    // Minor grid: every 1 unit
    float2 ddCoord = fwidth(coord);
    float2 grid1 = abs(fract(coord - 0.5) - 0.5) / ddCoord;
    float minorLine = min(grid1.x, grid1.y);
    float minorAlpha = 1.0 - saturate(minorLine);

    // Major grid: every 10 units
    float2 coord10 = coord * 0.1;
    float2 ddCoord10 = fwidth(coord10);
    float2 grid10 = abs(fract(coord10 - 0.5) - 0.5) / ddCoord10;
    float majorLine = min(grid10.x, grid10.y);
    float majorAlpha = 1.0 - saturate(majorLine);

    // Axis highlight: X axis (red tint), Z axis (blue tint)
    float xAxis = 1.0 - saturate(abs(coord.y) / ddCoord.y);
    float zAxis = 1.0 - saturate(abs(coord.x) / ddCoord.x);

    // Colors
    float3 minorColor = float3(0.227, 0.227, 0.227); // #3A3A3A
    float3 majorColor = float3(0.333, 0.333, 0.333); // #555555
    float3 xAxisColor = float3(0.8, 0.2, 0.2);       // Red for X
    float3 zAxisColor = float3(0.2, 0.4, 0.8);        // Blue for Z

    float3 color = mix(minorColor, majorColor, majorAlpha);
    float alpha = max(minorAlpha * 0.3, majorAlpha * 0.5) * fadeFactor;

    // Overlay axis colors
    if (xAxis > 0.1) {
        color = mix(color, xAxisColor, xAxis * 0.8);
        alpha = max(alpha, xAxis * 0.7 * fadeFactor);
    }
    if (zAxis > 0.1) {
        color = mix(color, zAxisColor, zAxis * 0.8);
        alpha = max(alpha, zAxis * 0.7 * fadeFactor);
    }

    if (alpha < 0.01) discard_fragment();

    return float4(color, alpha);
}
