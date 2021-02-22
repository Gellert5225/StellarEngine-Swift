//
//  Skybox.metal
//  ObsidianEngine
//
//  Created by Jiahe Li on 06/03/2019.
//  Copyright © 2019 Gellert. All rights reserved.
//

#include <metal_stdlib>
#include <simd/simd.h>
#import "../Graphics/Shaders/Types.h"

using namespace metal;

struct VertexIn {
    float4 position [[ attribute(0) ]];
};

struct VertexOut {
    float4 position [[ position ]];
    float4 uv;
    float clip_distance [[ clip_distance ]] [1];
};

struct FragmentIn {
    float4 position [[ position ]];
    float4 uv;
    float clip_distance;
};

vertex VertexOut vertexSkybox(const VertexIn vertex_in [[ stage_in ]],
                              constant STLRUniforms &uniforms [[ buffer(BufferIndexUniforms) ]],
                              constant STLRModelParams &modelParams [[buffer(BufferIndexModelParams)]]) {
    VertexOut vertex_out;
    float4x4 mvp = uniforms.projectionMatrix * uniforms.viewMatrix * modelParams.modelMatrix;
    vertex_out.position = (mvp * vertex_in.position).xyww;
    vertex_out.uv = vertex_in.position;
    vertex_out.clip_distance[0] = dot(modelParams.modelMatrix * vertex_in.position, uniforms.clipPlane);
    return vertex_out;
}

fragment half4 fragmentSkybox(FragmentIn vertex_in [[stage_in]],
                              texturecube<half> cubeTexture [[texture(20)]]) {
    constexpr sampler default_sampler;
    float3 uv = vertex_in.uv.xyz;
    half4 color = cubeTexture.sample(default_sampler, uv);
    return color;
}
