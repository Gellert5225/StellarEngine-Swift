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

constant float pi = 3.1415926535897932384626433832795;

constant bool hasColorTexture       [[ function_constant(0) ]];
constant bool hasNormalTexture      [[ function_constant(1) ]];
constant bool hasRoughnessTexture   [[ function_constant(2) ]];
constant bool hasMetallicTexture    [[ function_constant(3) ]];
constant bool hasAOTexture          [[ function_constant(4) ]];

struct VertexOut {
    float4 position [[ position ]];
    float3 worldPosition;
    float3 normal;
    float4 shadowPosition;
    float2 textureCoordinates;
    float3 worldTangent;
    float3 worldBitangent;
};

struct GbufferOut {
    float4 albedo   [[ color(0) ]];
    float4 normal   [[ color(1) ]];
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

float3 renderGbuffer(Lighting lighting);

fragment GbufferOut gBufferFragment(VertexOut in [[stage_in]],
                                    sampler sampler2d [[ sampler(0) ]],
                                    constant OBSDFragmentUniforms &fragmentUniforms [[ buffer(15) ]],
                                    constant Light *lightsBuffer                    [[ buffer(2) ]],
                                    constant Material &material         [[ buffer(13) ]],
                                    texture2d<float> texture            [[ texture(0) ]],
                                    texture2d<float> normalTexture      [[ texture(1) ]],
                                    texture2d<float> roughnessTexture   [[ texture(2) ]],
                                    texture2d<float> metallicTexture    [[ texture(3) ]],
                                    texture2d<float> aoTexture          [[ texture(4) ]],
                                    depth2d<float> shadow_texture       [[ texture(5) ]]) {
    GbufferOut out;

    out.albedo.a = 0;
    out.normal = float4(normalize(in.normal), 1.0);
    out.position = float4(in.worldPosition, 1.0);
    
    float4 baseColor;

    if (!is_null_texture(texture)) {
        float4 colorAlpha = texture.sample(sampler2d, in.textureCoordinates * 1);
        baseColor = float4(texture.sample(sampler2d, in.textureCoordinates * 1).rgb, 1);

        if (colorAlpha.a < 0.2) {
            discard_fragment();
        }
    } else {
        baseColor = float4(material.baseColor, 1.0);
    }

    float metallic = material.metallic;
    if (!is_null_texture(metallicTexture)) {
        metallic = metallicTexture.sample(sampler2d, in.textureCoordinates).r;
    } else {
        metallic = material.metallic;
    }

    // extract roughness
    float roughness;
    if (!is_null_texture(roughnessTexture)) {
        roughness = roughnessTexture.sample(sampler2d, in.textureCoordinates).r;
    } else {
        roughness = material.roughness;
    }

    // extract ambient occlusion
    float ambientOcclusion;
    if (!is_null_texture(aoTexture)) {
        ambientOcclusion = aoTexture.sample(sampler2d, in.textureCoordinates).r;
    } else {
        ambientOcclusion = 1.0;
    }

    float3 normal;
    if (!is_null_texture(normalTexture)) {
        float3 normalValue = normalTexture.sample(sampler2d, in.textureCoordinates * 1).rgb;
        normalValue = normalValue * 2 - 1;
        normal = in.normal * normalValue.z + in.worldTangent * normalValue.x + in.worldBitangent * normalValue.y;
    } else {
        normal = in.normal;
    }

    normal = normalize(normal);

    float3 viewDirection = normalize(fragmentUniforms.cameraPosition + in.worldPosition);
    float3 specularOutput = 0;
    float3 diffuseColor = 0;
    float3 ambientColor = 0;

    for (uint i = 0; i < fragmentUniforms.lightCount; i++) {
        Light light = lightsBuffer[i];
        if (light.type == 1) {
            float3 lightDirection = normalize(light.position);
            lightDirection = light.position;

            // all the necessary components are in place
            Lighting lighting;
            lighting.lightDirection = lightDirection;
            lighting.viewDirection = viewDirection;
            lighting.baseColor = baseColor.xyz;
            lighting.normal = normal;
            lighting.metallic = metallic;
            lighting.roughness = roughness;
            lighting.ambientOcclusion = ambientOcclusion;
            lighting.lightColor = light.color;

            specularOutput = renderGbuffer(lighting);

            //compute Lambertian diffuse
            //            float nDotl = saturate(dot(lighting.normal, lighting.lightDirection));
            //            diffuseColor = light.color * color.rgb * nDotl * ambientOcclusion;
            //            diffuseColor *= 1.0 - metallic;
        } else if (light.type == Pointlight){

        } else {
            ambientColor += light.color * light.intensity;
        }
    }

    diffuseColor = gbufferLighting(out.normal.xyz, out.position.xyz, fragmentUniforms, lightsBuffer, baseColor.rgb);
    
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

    out.albedo = float4(specularOutput + diffuseColor, out.albedo.a) * ambientOcclusion;

    return out;
}

fragment GbufferOut gBufferFragment_IBL(VertexOut in [[stage_in]],
                                    sampler sampler2d [[ sampler(0) ]],
                                    constant OBSDFragmentUniforms &fragmentUniforms [[ buffer(15) ]],
                                    constant Light *lightsBuffer                    [[ buffer(2) ]],
                                    constant Material &material         [[ buffer(13) ]],
                                    texture2d<float> texture            [[ texture(0) ]],
                                    texture2d<float> normalTexture      [[ texture(1) ]],
                                    texture2d<float> roughnessTexture   [[ texture(2) ]],
                                    texture2d<float> metallicTexture    [[ texture(3) ]],
                                    texture2d<float> aoTexture          [[ texture(4) ]],
                                    depth2d<float> shadow_texture       [[ texture(5) ]],
                                    texturecube<float> skybox           [[ texture(BufferIndexSkybox) ]],
                                    texturecube<float> skyboxDiffuse    [[ texture(BufferIndexSkyboxDiffuse) ]],
                                    texture2d<float> brdfLut            [[ texture(BufferIndexBRDFLut) ]]) {
    
    GbufferOut out;
    
    out.albedo.a = 0;
    out.normal = float4(normalize(in.normal), 1.0);
    out.position = float4(in.worldPosition, 1.0);
    
    float4 baseColor;
    
    if (!is_null_texture(texture)) {
        float4 colorAlpha = texture.sample(sampler2d, in.textureCoordinates * 1);
        baseColor = float4(texture.sample(sampler2d, in.textureCoordinates * 1).rgb, 1);
        
        if (colorAlpha.a < 0.2) {
            discard_fragment();
        }
    } else {
        baseColor = float4(material.baseColor, 1.0);
    }
    
    float metallic = material.metallic;
    if (!is_null_texture(metallicTexture)) {
        metallic = metallicTexture.sample(sampler2d, in.textureCoordinates).r;
    } else {
        metallic = material.metallic;
    }
    
    // extract roughness
    float roughness;
    if (!is_null_texture(roughnessTexture)) {
        roughness = roughnessTexture.sample(sampler2d, in.textureCoordinates).r;
    } else {
        roughness = material.roughness;
    }
    
    // extract ambient occlusion
    float ambientOcclusion;
    if (!is_null_texture(aoTexture)) {
        ambientOcclusion = aoTexture.sample(sampler2d, in.textureCoordinates).r;
    } else {
        ambientOcclusion = 1.0;
    }
    
    float3 normal;
    if (!is_null_texture(normalTexture)) {
        float3 normalValue = normalTexture.sample(sampler2d, in.textureCoordinates * 1).rgb;
        normalValue = normalValue * 2 - 1;
        normal = in.normal * normalValue.z + in.worldTangent * normalValue.x + in.worldBitangent * normalValue.y;
    } else {
        normal = in.normal;
    }
    
    normal = normalize(normal);
    
    float4 diffuse = skyboxDiffuse.sample(sampler2d, normal);
    diffuse = mix(pow(diffuse, 0.5), diffuse, metallic);
    
    //shadow
    float2 xy = in.shadowPosition.xy;
    xy = xy * 0.5 + 0.5;
    xy.y = 1 - xy.y;
    constexpr sampler sShadow(coord::normalized, filter::linear, address::clamp_to_edge, compare_func::less);
    float shadow_sample = shadow_texture.sample(sShadow, xy);
    float current_sample = in.shadowPosition.z / in.shadowPosition.w;
    if (current_sample > shadow_sample) {
        diffuse *= 0.5;
    }
    
    float3 viewDirection = normalize(fragmentUniforms.cameraPosition - in.worldPosition.xyz);
    float3 textureCoordinates = -normalize(reflect(viewDirection, normal));
    constexpr sampler s(filter::linear, mip_filter::linear);
    float3 prefilteredColor = skybox.sample(s, textureCoordinates, level(roughness * 10)).rgb;
    float nDotV = saturate(dot(normal, normalize(-viewDirection)));
    float2 envBRDF = brdfLut.sample(s, float2(roughness, nDotV)).rg;
    float3 f0 = mix(0.04, baseColor.rgb, metallic);
    float3 specularIBL = f0 * envBRDF.r + envBRDF.g;
    float3 specular = prefilteredColor * specularIBL;
    float4 color = diffuse * baseColor + float4(specular, 1);
    color *= ambientOcclusion;
    
    out.albedo = color;
    
    return out;
}

float3 renderGbuffer(Lighting lighting) {
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
    }
    else {
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
    float3 specularOutput = (Ds * Gs * Fs * specularColor) * lighting.ambientOcclusion;
    return specularOutput;
}
