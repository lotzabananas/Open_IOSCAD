#include <metal_stdlib>
using namespace metal;

// ─── Shared Structures ────────────────────────────────────────────────────────

struct Vertex {
    float3 position;
    float3 normal;
};

struct Uniforms {
    float4x4 modelViewProjection;
    float4x4 modelView;
    float3x3 normalMatrix;
    float3   lightDirection;   // Expected to be normalized, in view space
    float4   modelColor;
    uint     isEdgePass;
};

// ─── Model Shaders ────────────────────────────────────────────────────────────

struct ModelVertexOut {
    float4 position [[position]];
    float3 viewNormal;
    float3 viewPosition;
};

vertex ModelVertexOut model_vertex(
    const device Vertex* vertices [[buffer(0)]],
    constant Uniforms&   uniforms [[buffer(1)]],
    uint                 vid      [[vertex_id]])
{
    ModelVertexOut out;
    float3 pos = vertices[vid].position;
    float3 nor = vertices[vid].normal;

    out.position     = uniforms.modelViewProjection * float4(pos, 1.0);
    out.viewNormal   = normalize(uniforms.normalMatrix * nor);
    out.viewPosition = (uniforms.modelView * float4(pos, 1.0)).xyz;
    return out;
}

fragment float4 model_fragment(
    ModelVertexOut       in       [[stage_in]],
    constant Uniforms&   uniforms [[buffer(1)]])
{
    // Edge pass: solid dark outline
    if (uniforms.isEdgePass == 1) {
        return float4(0.1, 0.1, 0.1, 0.85);
    }

    // Phong shading
    float3 N = normalize(in.viewNormal);
    float3 L = normalize(uniforms.lightDirection);
    float3 V = normalize(-in.viewPosition);
    float3 R = reflect(-L, N);

    float ambient  = 0.2;
    float diffuse  = max(dot(N, L), 0.0);
    float specular = pow(max(dot(R, V), 0.0), 32.0) * 0.3;

    float3 baseColor = uniforms.modelColor.rgb;
    float3 color = baseColor * (ambient + diffuse) + float3(specular);
    return float4(saturate(color), uniforms.modelColor.a);
}

// ─── Background Gradient Shaders ──────────────────────────────────────────────

struct BackgroundVertexOut {
    float4 position [[position]];
    float2 uv;
};

// Fullscreen triangle trick: 3 vertices that cover the entire screen.
vertex BackgroundVertexOut background_vertex(uint vid [[vertex_id]]) {
    BackgroundVertexOut out;

    // Generate a triangle that covers clip space [-1, 1] x [-1, 1].
    float2 positions[3] = {
        float2(-1.0, -1.0),
        float2( 3.0, -1.0),
        float2(-1.0,  3.0)
    };
    out.position = float4(positions[vid], 0.9999, 1.0);  // far depth
    out.uv = positions[vid] * 0.5 + 0.5; // [0,1]
    return out;
}

fragment float4 background_fragment(BackgroundVertexOut in [[stage_in]]) {
    // Vertical gradient: top = lighter, bottom = darker
    float t = in.uv.y;
    float3 topColor    = float3(0.85, 0.87, 0.90);
    float3 bottomColor = float3(0.60, 0.62, 0.65);
    float3 color = mix(bottomColor, topColor, t);
    return float4(color, 1.0);
}
