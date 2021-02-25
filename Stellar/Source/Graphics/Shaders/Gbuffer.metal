//
//  Gbuffer.metal
//  ObsidianEngine
//
//  Created by Jiahe Li on 18/03/2019.
//  Copyright © 2019 Gellert. All rights reserved.
//

#include "ShadersCommon.h"
using namespace metal;

constant bool hasColorTexture       [[ function_constant(0) ]];
constant bool hasNormalTexture      [[ function_constant(1) ]];
constant bool hasRoughnessTexture   [[ function_constant(2) ]];
constant bool hasMetallicTexture    [[ function_constant(3) ]];
constant bool hasAOTexture          [[ function_constant(4) ]];

struct GbufferOut {
    float4 albedo   [[ color(Albedo) ]];
    float4 normal   [[ color(Normal) ]];
    float4 position [[ color(Position) ]];
};

struct STLRGBufferTextures {
    texture2d<float> baseColorTexture   [[ texture(BaseColorTexture) ]];
    texture2d<float> normalTexture      [[ texture(NormalTexture) ]];
    texture2d<float> roughnessTexture   [[ texture(RoughnessTexture) ]];
    texture2d<float> metallicTexture    [[ texture(MetallicTexture) ]];
    texture2d<float> aoTexture          [[ texture(AOTexture) ]];
};

fragment GbufferOut gBufferFragment(VertexOut in [[stage_in]],
                                    sampler sampler2d [[ sampler(0) ]],
                                    constant STLRFragmentUniforms &fragmentUniforms [[ buffer(BufferIndexFragmentUniforms) ]],
                                    constant STLRLight *lightsBuffer                    [[ buffer(BufferIndexLight) ]],
                                    constant STLRMaterial &material                     [[ buffer(BufferIndexMaterials) ]],
                                    depth2d<float> shadow_texture                   [[ texture(Shadow) ]],
                                    constant STLRGBufferTextures &textures          [[ buffer(STLRGBufferTexturesIndex) ]]) {
    GbufferOut out;
    
    out.position = float4(in.worldPosition, 1.0);
    
    float4 baseColor;

    if (!is_null_texture(textures.baseColorTexture)) {
        float4 colorAlpha = textures.baseColorTexture.sample(sampler2d, in.textureCoordinates * 1);
        baseColor = float4(textures.baseColorTexture.sample(sampler2d, in.textureCoordinates * 1).rgb, 1);
        if (colorAlpha.a < 0.2) {
            discard_fragment();
        }
    } else {
        baseColor = float4(material.baseColor, 1.0);
    }

    float metallic = material.metallic;
    if (!is_null_texture(textures.metallicTexture)) {
        metallic = textures.metallicTexture.sample(sampler2d, in.textureCoordinates).r;
    } else {
        metallic = material.metallic;
    }

    // extract roughness
    float roughness;
    if (!is_null_texture(textures.roughnessTexture)) {
        roughness = textures.roughnessTexture.sample(sampler2d, in.textureCoordinates).r;
    } else {
        roughness = material.roughness;
    }

    // extract ambient occlusion
    float ambientOcclusion;
    if (!is_null_texture(textures.aoTexture)) {
        ambientOcclusion = textures.aoTexture.sample(sampler2d, in.textureCoordinates).r;
    } else {
        ambientOcclusion = 1.0;//in.occlusion;
    }

    float3 normal;
    if (!is_null_texture(textures.normalTexture)) {
        float3 normalValue = textures.normalTexture.sample(sampler2d, in.textureCoordinates * 1).rgb;
        normalValue = normalValue * 2 - 1;
        normal = in.normal * normalValue.z + in.worldTangent * normalValue.x + in.worldBitangent * normalValue.y;
    } else {
        normal = in.normal;
    }
    
    normal = normalize(normal);
    out.normal = float4(normal, 1.0);

    float3 viewDirection = normalize(fragmentUniforms.cameraPosition);
    float3 specularOutput = 0;
    float3 diffuseColor = baseColor.xyz;

    for (uint i = 0; i < fragmentUniforms.lightCount; i++) {
        STLRLight light = lightsBuffer[i];
        if (light.type == 1) {
            float3 lightDirection = normalize(light.position);

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
            lighting.intensity = light.intensity;

            specularOutput = calculateSpecularOutput(lighting);
        }
    }
    
    //diffuseColor = calculateLighting(out.normal.xyz, out.position.xyz, fragmentUniforms, lightsBuffer, baseColor.rgb);
    
    float2 xy = in.shadowPosition.xy;
    xy = xy * 0.5 + 0.5;
    xy.y = 1 - xy.y;
    
    float bias = 0.005;
    constexpr sampler s(coord::normalized, filter::linear, address::clamp_to_edge, compare_func:: less);
    const int neighborWidth = 7;
    const float neighbors = (neighborWidth * 3.0 + 1.0) * (neighborWidth * 3.0 + 1.0);

    float mapSize = 4096;
    float texelSize = 1.0 / mapSize;
    float total = 0.0;
    for (int x = -neighborWidth; x <= neighborWidth; x++) {
        for (int y = -neighborWidth; y <= neighborWidth; y++) {
            float shadow_sample = shadow_texture.sample(s, xy + float2(x, y) * texelSize);
            float current_sample = (in.shadowPosition.z - bias) / in.shadowPosition.w;
            if (current_sample > shadow_sample) {
                total += 1.0;
            }
        }
    }

    total /= neighbors;
    float lightFactor = 1.0 - (total * in.shadowPosition.w);
    
    //float visibility = 1.0;
    float current_sample = (in.shadowPosition.z - bias) / in.shadowPosition.w;
    
    for (int i = 0; i < 4; i++) {
        int index = int(16.0 * random(floor(in.worldPosition.xyz * 1000.0), i)) % 16;
        if (shadow_texture.sample(s, xy + poissonDisk[index] / 500.0 ) < current_sample) {
            lightFactor -= 0.08;
            //visibility -= 0.2 * (1.0 - shadow_texture.sample(s, xy + poissonDisk[index] / 700.0, current_sample));
        }
    }
    
    out.albedo.a = lightFactor;
    
    float4 specDiffuse = float4(specularOutput * lightFactor + diffuseColor * lightFactor, 1) * ambientOcclusion;

    out.albedo = specDiffuse;

    return out;
}

fragment GbufferOut gBufferFragment_IBL(VertexOut in [[stage_in]],
                                    sampler sampler2d [[ sampler(0) ]],
                                    constant STLRFragmentUniforms &fragmentUniforms [[ buffer(BufferIndexFragmentUniforms) ]],
                                    constant STLRLight *lightsBuffer                [[ buffer(BufferIndexLight) ]],
                                    constant STLRMaterial &material                 [[ buffer(BufferIndexMaterials) ]],
                                    constant STLRGBufferTextures &textures          [[ buffer(STLRGBufferTexturesIndex) ]],
                                    depth2d<float> shadow_texture                   [[ texture(Shadow) ]],
                                    texturecube<float> skybox                       [[ texture(BufferIndexSkybox) ]],
                                    texturecube<float> skyboxDiffuse                [[ texture(BufferIndexSkyboxDiffuse) ]],
                                    texture2d<float> brdfLut                        [[ texture(BufferIndexBRDFLut) ]]) {
    
    GbufferOut out;

    out.albedo.a = 1;
    out.normal = float4(normalize(in.normal), 1.0);
    out.position = float4(in.worldPosition, 1.0);

    float4 baseColor;

    if (!is_null_texture(textures.baseColorTexture)) {
        float4 colorAlpha = textures.baseColorTexture.sample(sampler2d, in.textureCoordinates * 1);
        baseColor = float4(textures.baseColorTexture.sample(sampler2d, in.textureCoordinates * 1).rgb, 1);

        if (colorAlpha.a < 0.2) {
            discard_fragment();
        }
    } else {
        baseColor = float4(material.baseColor, 1.0);
    }

    float metallic = material.metallic;
    if (!is_null_texture(textures.metallicTexture)) {
        metallic = textures.metallicTexture.sample(sampler2d, in.textureCoordinates).r;
    } else {
        metallic = material.metallic;
    }

    // extract roughness
    float roughness;
    if (!is_null_texture(textures.roughnessTexture)) {
        roughness = textures.roughnessTexture.sample(sampler2d, in.textureCoordinates).r;
    } else {
        roughness = material.roughness;
    }

    // extract ambient occlusion
    float ambientOcclusion;
    if (!is_null_texture(textures.aoTexture)) {
        ambientOcclusion = textures.aoTexture.sample(sampler2d, in.textureCoordinates).r;
    } else {
        ambientOcclusion = 1.0;
    }

    float3 normal;
    if (!is_null_texture(textures.normalTexture)) {
        float3 normalValue = textures.normalTexture.sample(sampler2d, in.textureCoordinates * 1).rgb;
        normalValue = normalValue * 2 - 1;
        normal = in.normal * normalValue.z + in.worldTangent * normalValue.x + in.worldBitangent * normalValue.y;
    } else {
        normal = in.normal;
    }

    normal = normalize(normal);

    float4 diffuse = skyboxDiffuse.sample(sampler2d, normal);
    diffuse = mix(pow(diffuse, 0.5), diffuse, metallic);

    float2 xy = in.shadowPosition.xy;
    xy = xy * 0.5 + 0.5;
    xy.y = 1 - xy.y;
    constexpr sampler shadow_s(coord::normalized, filter::linear, address::clamp_to_edge, compare_func:: less);
    float current_sample = in.shadowPosition.z / in.shadowPosition.w;
    
    for (int i = 0; i < 4; i++) {
      if ( shadow_texture.sample(shadow_s, xy + poissonDisk[i]/700.0 ) < current_sample ){
          out.albedo -= 0.2;
      }
    }
//    const int neighborWidth = 3;
//    const float neighbors = (neighborWidth * 3.0 + 1.0) * (neighborWidth * 3.0 + 1.0);
//
//    float mapSize = 4096;
//    float texelSize = 1.0 / mapSize;
//    float total = 0.0;
//    for (int x = -neighborWidth; x <= neighborWidth; x++) {
//        for (int y = -neighborWidth; y <= neighborWidth; y++) {
//            float shadow_sample = shadow_texture.sample(shadow_s, xy + float2(x, y) * texelSize);
//            float current_sample = in.shadowPosition.z / in.shadowPosition.w;
//            if (current_sample > shadow_sample) {
//                total += 1.0;
//            }
//        }
//    }
//
//    total /= neighbors;
//    float lightFactor = 1.0 - (total * in.shadowPosition.w);

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
    //color *= ambientOcclusion * lightFactor;

    out.albedo = color;

    return out;
}
