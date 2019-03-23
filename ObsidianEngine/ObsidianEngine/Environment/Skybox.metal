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
    float3 textureCoordinates;
};

vertex VertexOut vertexSkybox(const VertexIn in [[ stage_in ]],
                              constant float4x4 &vp [[ buffer(1) ]]) {
    VertexOut out;
    out.position = (vp * in.position).xyww;
    out.textureCoordinates = in.position.xyz;
    return out;
}

fragment half4 fragmentSkybox(VertexOut in [[stage_in]],
                              texturecube<half> cubeTexture [[texture(20)]]) {
    constexpr sampler default_sampler(filter::linear, mag_filter::linear, min_filter::linear);
    half4 color = cubeTexture.sample(default_sampler, in.textureCoordinates);
    return half4(color);
}
