/**
 * Copyright (c) 2018 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
 * distribute, sublicense, create a derivative work, and/or sell copies of the
 * Software in any work that is designed, intended, or marketed for pedagogical or
 * instructional purposes related to programming, coding, application development,
 * or information technology.  Permission for such use, copying, modification,
 * merger, publication, distribution, sublicensing, creation of derivative works,
 * or sale is expressly withheld.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#include "ShadersCommon.h"
using namespace metal;

constant bool hasColorTexture [[ function_constant(0) ]];
constant bool hasNormalTexture [[ function_constant(1) ]];
constant bool hasRoughnessTexture [[ function_constant(2) ]];
constant bool hasMetallicTexture [[ function_constant(3) ]];
constant bool hasAOTexture [[ function_constant(4) ]];

struct STLRGBufferTextures {
    texture2d<float> baseColorTexture   [[ texture(BaseColorTexture) ]];
    texture2d<float> normalTexture      [[ texture(NormalTexture) ]];
    texture2d<float> roughnessTexture   [[ texture(RoughnessTexture) ]];
    texture2d<float> metallicTexture    [[ texture(MetallicTexture) ]];
    texture2d<float> aoTexture          [[ texture(AOTexture) ]];
};


fragment float4 fragment_IBL(VertexOut in                                       [[ stage_in ]],
                             sampler textureSampler                             [[ sampler(0) ]],
                             constant STLRMaterial &material                    [[ buffer(BufferIndexMaterials) ]],
                             constant STLRFragmentUniforms &fragmentUniforms    [[ buffer(BufferIndexFragmentUniforms) ]],
                             constant STLRGBufferTextures &textures             [[ buffer(STLRGBufferTexturesIndex) ]],
                             depth2d<float> shadowTexture                       [[ texture(Shadow) ]],
                             texturecube<float> skybox                          [[ texture(BufferIndexSkybox) ]],
                             texturecube<float> skyboxDiffuse                   [[ texture(BufferIndexSkyboxDiffuse) ]],
                             texture2d<float> brdfLut                           [[ texture(BufferIndexBRDFLut) ]]){
    float4 baseColor;

    if (!is_null_texture(textures.baseColorTexture)) {
        float4 colorAlpha = textures.baseColorTexture.sample(textureSampler, in.textureCoordinates * 1);
        baseColor = float4(textures.baseColorTexture.sample(textureSampler, in.textureCoordinates * 1).rgb, 1);

        if (colorAlpha.a < 0.2) {
            discard_fragment();
        }
    } else {
        baseColor = float4(material.baseColor, 1.0);
    }

    float metallic = material.metallic;
    if (!is_null_texture(textures.metallicTexture)) {
        metallic = textures.metallicTexture.sample(textureSampler, in.textureCoordinates).r;
    } else {
        metallic = material.metallic;
    }

    // extract roughness
    float roughness;
    if (!is_null_texture(textures.roughnessTexture)) {
        roughness = textures.roughnessTexture.sample(textureSampler, in.textureCoordinates).r;
    } else {
        roughness = material.roughness;
    }

    // extract ambient occlusion
    float ambientOcclusion;
    if (!is_null_texture(textures.aoTexture)) {
        ambientOcclusion = textures.aoTexture.sample(textureSampler, in.textureCoordinates).r;
    } else {
        ambientOcclusion = 1.0;
    }

    float3 normal;
    if (!is_null_texture(textures.normalTexture)) {
        float3 normalValue = textures.normalTexture.sample(textureSampler, in.textureCoordinates * 1).rgb;
        normalValue = normalValue * 2 - 1;
        normal = in.normal * normalValue.z + in.worldTangent * normalValue.x + in.worldBitangent * normalValue.y;
    } else {
        normal = in.normal;
    }

    normal = normalize(normal);

    float4 diffuse = skyboxDiffuse.sample(textureSampler, normal);
    diffuse = mix(pow(diffuse, 0.5), diffuse, metallic);

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
    color *= ambientOcclusion;

    return color;
}
