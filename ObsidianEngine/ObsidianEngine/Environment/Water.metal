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
    float3 worldPosition;
};

vertex VertexOut vertex_water(const VertexIn vertex_in [[ stage_in ]],
                              constant OBSDUniforms &uniforms [[ buffer(BufferIndexUniforms) ]]) {
    VertexOut out;
    
    float4x4 mvp = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix;
    out.position = mvp * vertex_in.position;
    out.uv = vertex_in.uv;
    out.worldPosition = (uniforms.modelMatrix * vertex_in.position).xyz;
    
    return out;
}

fragment float4 fragment_water(VertexOut vertex_in [[ stage_in ]],
                               texture2d<float> reflectionTexture [[ texture(0) ]],
                               texture2d<float> normalTexture [[ texture(2) ]],
                               constant float& timer [[ buffer(3) ]],
                               constant OBSDFragmentUniforms &fragmentUniforms [[ buffer(BufferIndexFragmentConstants) ]]) {
    constexpr sampler s(filter::linear, address::repeat);
    
    float width = float(reflectionTexture.get_width() * 2.0);
    float height = float(reflectionTexture.get_height() * 2.0);
    float x = vertex_in.position.x / width;
    float y = vertex_in.position.y / height;
    float2 reflectionCoords = float2(x, 1 - y);
    
    float2 uv = vertex_in.uv * 10; // 2 = huge ripple, 16 = small ripple
    
    float waveStrength = 0.1;
    float2 rippleX = float2(uv.x + timer, uv.y);
    float2 rippleY = float2(-uv.x, uv.y) + timer;
    float2 ripple = ((normalTexture.sample(s, rippleX).rg * 2.0 - 1.0) +
                     (normalTexture.sample(s, rippleY).rg * 2.0 - 1.0)) * waveStrength;
    
    reflectionCoords += ripple;
    reflectionCoords = clamp(reflectionCoords, 0.001, 0.999);
    
    float3 viewVector = normalize(fragmentUniforms.cameraPosition - vertex_in.worldPosition);
    //float mixRatio = dot(viewVector, float3(0.0, 1.0, 0.0));
    
    float4 color = reflectionTexture.sample(s, reflectionCoords);
    
    float4 normalColor = normalTexture.sample(s, ripple);
    float3 normal = float3(normalColor.r * 2.0 - 1.0, normalColor.b, normalColor.g * 2.0 - 1.0);
    normal = normalize(normal);
    float3 lightDirection = normalize(sunLight);
    float3 reflectedLight = reflect(lightDirection, normal);
    float specular = max(dot(reflectedLight, viewVector), 0.0);
    specular = pow(specular, 20.0);
    //color += float4(float3(specular * 2.0), 0.0);
    
    color = mix(color, float4(0.0, 0.3, 0.5, 1.0), 0.3);
    
    return color;
}
