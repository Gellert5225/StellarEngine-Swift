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
    float4 albedo   [[ color(Albedo) ]];
    float4 normal   [[ color(Normal) ]];
    float4 position [[ color(Position) ]];
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

float3 gbufferLighting(float3 normal,
                       float3 position,
                       constant STLRFragmentUniforms &fragmentUniforms,
                       constant Light *lights,
                       float3 baseColor);

// Returns a random number based on a vec3 and an int.
float random(float3 seed, int i){
    float4 seed4 = float4(seed,i);
    float dot_product = dot(seed4, float4(12.9898,78.233,45.164,94.673));
    return fract(sin(dot_product) * 43758.5453);
}

float3 renderGbuffer(Lighting lighting);

fragment GbufferOut gBufferFragment(VertexOut in [[stage_in]],
                                    sampler sampler2d [[ sampler(0) ]],
                                    constant STLRFragmentUniforms &fragmentUniforms [[ buffer(15) ]],
                                    constant Light *lightsBuffer                    [[ buffer(2) ]],
                                    constant Material &material         [[ buffer(13) ]],
                                    texture2d<float> texture            [[ texture(BaseColorTexture) ]],
                                    texture2d<float> normalTexture      [[ texture(NormalTexture) ]],
                                    texture2d<float> roughnessTexture   [[ texture(RoughnessTexture) ]],
                                    texture2d<float> metallicTexture    [[ texture(MetallicTexture) ]],
                                    texture2d<float> aoTexture          [[ texture(AOTexture) ]],
                                    depth2d<float> shadow_texture       [[ texture(Shadow) ]]) {
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

    float3 viewDirection = normalize(fragmentUniforms.cameraPosition - in.worldPosition);
    float3 specularOutput = 0;
    float3 diffuseColor = 0;
    float3 ambientColor = 0;

    for (uint i = 0; i < fragmentUniforms.lightCount; i++) {
        Light light = lightsBuffer[i];
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

            specularOutput = renderGbuffer(lighting);
        }
    }

    diffuseColor = gbufferLighting(out.normal.xyz, out.position.xyz, fragmentUniforms, lightsBuffer, baseColor.rgb);
    
    float2 xy = in.shadowPosition.xy;
    xy = xy * 0.5 + 0.5;
    xy.y = 1 - xy.y;
    
    float bias = 0.005;
    constexpr sampler s(coord::normalized, filter::linear, address::clamp_to_edge, compare_func:: less);
    const int neighborWidth = 3;
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
        if ( shadow_texture.sample(s, xy + poissonDisk[index] / 700.0 ) < current_sample ) {
            lightFactor -= 0.08;
            //visibility -= 0.2 * (1.0 - shadow_texture.sample(s, xy + poissonDisk[index] / 700.0, current_sample));
        }
    }
    
    float4 specDiffuse = float4(specularOutput * lightFactor + diffuseColor.xyz * lightFactor + ambientColor, out.albedo.a) * ambientOcclusion;

    out.albedo = specDiffuse;

    return out;
}

fragment GbufferOut gBufferFragment_IBL(VertexOut in [[stage_in]],
                                    sampler sampler2d [[ sampler(0) ]],
                                    constant STLRFragmentUniforms &fragmentUniforms [[ buffer(15) ]],
                                    constant Light *lightsBuffer                    [[ buffer(2) ]],
                                    constant Material &material         [[ buffer(13) ]],
                                    texture2d<float> texture            [[ texture(BaseColorTexture) ]],
                                    texture2d<float> normalTexture      [[ texture(NormalTexture) ]],
                                    texture2d<float> roughnessTexture   [[ texture(RoughnessTexture) ]],
                                    texture2d<float> metallicTexture    [[ texture(MetallicTexture) ]],
                                    texture2d<float> aoTexture          [[ texture(AOTexture) ]],
                                    depth2d<float> shadow_texture       [[ texture(Shadow) ]],
                                    texturecube<float> skybox           [[ texture(BufferIndexSkybox) ]],
                                    texturecube<float> skyboxDiffuse    [[ texture(BufferIndexSkyboxDiffuse) ]],
                                    texture2d<float> brdfLut            [[ texture(BufferIndexBRDFLut) ]]) {
    
    GbufferOut out;

    out.albedo.a = 1;
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

// calculate specularOutput
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

float3 gbufferLighting(float3 normal,
                       float3 position,
                       constant STLRFragmentUniforms &fragmentUniforms,
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
            ambientColor *= baseColor;
            diffuseColor += ambientColor;
        }
    }
    return diffuseColor;
}
