//
//  Water.metal
//  ObsidianEngine
//
//  Created by Jiahe Li on 23/03/2019.
//  Copyright © 2019 Gellert. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;
#import "../Graphics/Shaders/Types.h"

struct VertexIn {
    float4 position [[ attribute(0) ]];
    float2 uv [[ attribute(2) ]];
};

struct VertexOut {
    float4 position [[ position ]];
    float2 uv;
};

vertex VertexOut vertex_water(const VertexIn vertex_in [[ stage_in ]],
                              constant OBSDUniforms &uniforms [[ buffer(BufferIndexUniforms) ]]) {
    VertexOut out;
    
    float4x4 mvp = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix;
    out.position = mvp * vertex_in.position;
    out.uv = vertex_in.uv;
    
    return out;
}

fragment float4 fragment_water(VertexOut vertex_in [[ stage_in ]],
                               texture2d<float> reflectionTexture [[ texture(0) ]],
                               texture2d<float> normalTexture [[ texture(2) ]]) {
    constexpr sampler s(filter::linear, address::repeat);
    
    float width = float(reflectionTexture.get_width() * 2.0);
    float height = float(reflectionTexture.get_height() * 2.0);
    float x = vertex_in.position.x / width;
    float y = vertex_in.position.y / height;
    float2 reflectionCoords = float2(x, 1 - y);
    
    float4 color = reflectionTexture.sample(s, reflectionCoords);
    color = mix(color, float4(0.0, 0.3, 0.5, 1.0), 0.3);
    
    return color;
}
