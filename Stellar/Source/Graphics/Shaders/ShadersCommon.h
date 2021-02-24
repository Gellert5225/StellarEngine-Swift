//
//  ShadersCommon.h
//  Stellar
//
//  Created by Gellert Li on 2/22/21.
//  Copyright © 2021 Gellert. All rights reserved.
//

#ifndef ShadersCommon_h
#define ShadersCommon_h

#import <metal_stdlib>
#import <simd/simd.h>
#import "Types.h"

using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float4 color;
    float2 textureCoordinates;
    float4 materialColor;
    float3 normal;
    float specularIntensity;
    float shininess;
    float3 eyePosition;
    float3 worldPosition;
    float occlusion;
    float3 worldTangent;
    float3 worldBitangent;
    float4 shadowPosition;
    uint modelIndex [[flat]];
};

constant float2 poissonDisk[16] = {
   float2( -0.94201624, -0.39906216 ),
   float2( 0.94558609, -0.76890725 ),
   float2( -0.094184101, -0.92938870 ),
   float2( 0.34495938, 0.29387760 ),
   float2( -0.91588581, 0.45771432 ),
   float2( -0.81544232, -0.87912464 ),
   float2( -0.38277543, 0.27676845 ),
   float2( 0.97484398, 0.75648379 ),
   float2( 0.44323325, -0.97511554 ),
   float2( 0.53742981, -0.47373420 ),
   float2( -0.26496911, -0.41893023 ),
   float2( 0.79197514, 0.19090188 ),
   float2( -0.24188840, 0.99706507 ),
   float2( -0.81409955, 0.91437590 ),
   float2( 0.19984126, 0.78641367 ),
   float2( 0.14383161, -0.14100790 )
};

// Returns a random number based on a vec3 and an int.
inline float random(float3 seed, int i){
    float4 seed4 = float4(seed,i);
    float dot_product = dot(seed4, float4(12.9898,78.233,45.164,94.673));
    return fract(sin(dot_product) * 43758.5453);
}

// specular output
inline float3 calculateSpecularOutput(Lighting lighting) {
    // Rendering equation courtesy of Apple et al.
    float NoL = saturate(dot(lighting.normal, lighting.lightDirection));
    float3 H = normalize(lighting.lightDirection + lighting.viewDirection); // half vector
    float NoH = saturate(dot(lighting.normal, H));
    float NoV = saturate(dot(lighting.normal, lighting.viewDirection));
    float HoL = saturate(dot(lighting.lightDirection, H));
    
    // specular roughness
    float specularRoughness = lighting.roughness * (1.0 - lighting.metallic) + lighting.metallic;
    
    // Distribution
    float Ds;
    if (specularRoughness >= 1.0) {
        Ds = 1.0 / pi;
    } else {
        float roughnessSqr = specularRoughness * specularRoughness;
        float d = (NoH * roughnessSqr - NoH) * NoH + 1;
        Ds = roughnessSqr / (pi * d * d);
    }
    
    // Fresnel
    float3 Cspec0 = float3(1.0);
    float fresnel = pow(clamp(1.0 - HoL, 0.0, 1.0), 5.0);
    float3 Fs = float3(mix(float3(Cspec0), float3(1), fresnel));
    
    // Geometry
    float alphaG = (specularRoughness * 0.5 + 0.5) * (specularRoughness * 0.5 + 0.5);
    float a = alphaG * alphaG;
    float b1 = NoL * NoL;
    float b2 = NoV * NoV;
    float G1 = (float)(1.0 / (b1 + sqrt(a + b1 - a * b1)));
    float G2 = (float)(1.0 / (b2 + sqrt(a + b2 - a * b2)));
    float Gs = G1 * G2;
    
    float3 specularColor = mix(lighting.lightColor, lighting.baseColor.rgb, lighting.metallic);
    float3 specularOutput = (Ds * Gs * Fs * specularColor) * lighting.ambientOcclusion * lighting.intensity;
    return specularOutput;
}

// render with lighting
inline float3 calculateLighting(float3 normal,
                       float3 position,
                       constant STLRFragmentUniforms &fragmentUniforms,
                       constant STLRLight *lights,
                       float3 baseColor) {
    float3 diffuseColor = 0;
    float3 ambientColor = 0;
    float3 normalDirection = normalize(normal);
    
    for (uint i = 0; i < fragmentUniforms.lightCount; i++) {
        STLRLight light = lights[i];
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
            ambientColor *= baseColor;
            diffuseColor += ambientColor;
        }
    }
    return diffuseColor;
}


#endif /* ShadersCommon_h */
