#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    uint viewID [[render_target_array_index]];
    half4 color;
};

[[vertex]] VertexOut vertex1(uint vertexID [[vertex_id]],
                             uint instanceID [[instance_id]],
                             constant float4x4 *projection [[buffer(1)]],
                             constant float4x4 *viewFromWorld [[buffer(2)]],
                             constant float4x4 &worldFromModel [[buffer(3)]]) {
    float3 triangle[] = {
        float3(-0.2, -0.2, 0),
        float3(0.2, -0.2, 0),
        float3(0, 0.2, 0),
    };

    half4 colors[] = {
        half4(1, 0, 0, 1),
        half4(0, 1, 0, 1),
        half4(0, 0, 1, 1),
    };

    auto viewID = instanceID;
    auto clip = projection[viewID] * viewFromWorld[viewID] * worldFromModel * float4(triangle[vertexID], 1);

    return VertexOut {
        .position = clip,
        .viewID = viewID,
        .color = colors[vertexID],
    };
}

[[fragment]] half4 fragment1(VertexOut in [[stage_in]]) {
    return in.color;
}
