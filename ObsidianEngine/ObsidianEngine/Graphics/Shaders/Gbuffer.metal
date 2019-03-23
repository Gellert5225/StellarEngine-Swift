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
    float4 albedo [[ color(0) ]];
    float4 normal [[ color(1) ]];
    float4 position [[ color(2) ]];
};

float3 gbufferLighting(float3 normal,
                           float3 position,
                           constant OBSDFragmentUniforms &fragmentUniforms,
                           constant Light *lights,
                           float3 baseColor) {
    float3 diffuseColor = 0;
    float3 ambientColor = 0;
    float3 normalDirection = normalize(normal);
    
    for (uint i = 0; i < fragmentUniforms.lightCount; i++) {
        Light light = lights[i];
        if (light.type == Sunlight) {
            float3 lightDirection = normalize(light.position);
            float diffuseIntensity = saturate(dot(lightDirection, normalDirection));
            diffuseColor += light.color * light.intensity * baseColor * diffuseIntensity;
        } else if (light.type == Pointlight) {
            float d = distance(light.position, position);
            float3 lightDirection = normalize(light.position - position);
            float attenuation = 1.0 / (light.attenuation.x + light.attenuation.y * d + light.attenuation.z * d * d);
            float diffuseIntensity = saturate(dot(lightDirection, normalDirection));
            float3 color = light.color * baseColor * diffuseIntensity;
            color *= attenuation;
            diffuseColor += color;
        } else if (light.type == Spotlight) {
            float d = distance(light.position, position);
            float3 lightDirection = normalize(light.position - position);
            float3 coneDirection = normalize(-light.coneDirection);
            float spotResult = (dot(lightDirection, coneDirection));
            if (spotResult > cos(light.coneAngle)) {
                float attenuation = 1.0 / (light.attenuation.x + light.attenuation.y * d + light.attenuation.z * d * d);
                attenuation *= pow(spotResult, light.coneAttenuation);
                float diffuseIntensity = saturate(dot(lightDirection, normalDirection));
                float3 color = light.color * baseColor * diffuseIntensity;
                color *= attenuation;
                diffuseColor += color;
            }
        } else if (light.type == Ambientlight) {
            ambientColor += light.color * light.intensity;
        }
    }
    return diffuseColor;
}

fragment GbufferOut gBufferFragment(VertexOut in [[stage_in]],
                                    depth2d<float> shadow_texture [[texture(5)]],
                                    constant Material &material [[buffer(13)]],
                                    constant OBSDFragmentUniforms &fragmentUniforms [[ buffer(15) ]],
                                    constant Light *lightsBuffer [[ buffer(2) ]]) {
    GbufferOut out;
    out.albedo = float4(material.baseColor, 1.0);
    out.albedo.a = 0;
    out.normal = float4(normalize(in.normal), 1.0);
    out.position = float4(in.worldPosition, 1.0);
    
    float3 diffuseColor = gbufferLighting(out.normal.xyz, out.position.xyz, fragmentUniforms, lightsBuffer, material.baseColor);
    
    out.albedo = float4(diffuseColor, out.albedo.a);
    
    float2 xy = in.shadowPosition.xy;
    xy = xy * 0.5 + 0.5;
    xy.y = 1 - xy.y;
    constexpr sampler s(coord::normalized, filter::linear, address::clamp_to_edge, compare_func:: less);
    float shadow_sample = shadow_texture.sample(s, xy);
    float current_sample = in.shadowPosition.z / in.shadowPosition.w;
    if (current_sample > shadow_sample ) {
        out.albedo.a = 1;
    }
    
    float shadow = out.albedo.a;
    if (shadow > 0) {
        diffuseColor *= 0.5;
    }
    
    out.albedo = float4(diffuseColor, out.albedo.a);
    
    return out;
}
