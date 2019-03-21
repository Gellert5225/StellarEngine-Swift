//
//  Gbuffer.metal
//  ObsidianEngine
//
//  Created by Jiahe Li on 18/03/2019.
//  Copyright © 2019 Gellert. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;
#import "Types.h"

struct VertexOut {
    float4 position [[ position ]];
    float3 worldPosition;
    float3 normal;
    float4 shadowPosition;
};

struct GbufferOut {
    float4 albedo [[ color(1) ]];
    float4 normal [[ color(2) ]];
    float4 position [[ color(3) ]];
};

fragment GbufferOut gBufferFragment(VertexOut in [[stage_in]],
                                    depth2d<float> shadow_texture [[texture(5)]],
                                    constant Material &material [[buffer(13)]]) {
    GbufferOut out;
    out.albedo = float4(material.baseColor, 1.0);
    out.albedo.a = 0;
    out.normal = float4(normalize(in.normal), 1.0);
    out.position = float4(in.worldPosition, 1.0);
    float2 xy = in.shadowPosition.xy;
    xy = xy * 0.5 + 0.5;
    xy.y = 1 - xy.y;
    constexpr sampler s(coord::normalized, filter::linear, address::clamp_to_edge, compare_func:: less);
    float shadow_sample = shadow_texture.sample(s, xy);
    float current_sample = in.shadowPosition.z / in.shadowPosition.w;
    if (current_sample > shadow_sample ) {
        out.albedo.a = 1;
    }
    return out;
}
