//
//  Shaders.metal
//  ObsidianEngine
//
//  Created by Gellert on 6/7/18.
//  Copyright © 2018 Gellert. All rights reserved.
//

#import "ShadersCommon.h"

using namespace metal;

constant bool hasColorTexture [[ function_constant(0) ]];
constant bool hasNormalTexture [[ function_constant(1) ]];
constant bool hasRoughnessTexture [[function_constant(2)]];
constant bool hasMetallicTexture [[function_constant(3)]];
constant bool hasAOTexture [[function_constant(4)]];

struct VertexIn{
    float4 position [[ attribute(0) ]];
    float3 normal [[ attribute(1) ]];
    float2 textureCoordinates [[ attribute(2) ]];
    float  ambientOcculusion [[ attribute(3) ]];
    float3 tangent [[ attribute(4) ]];
    float3 bitangent [[ attribute(5) ]];
};

// all vertex shaders begin with keyword 'vertex'
// packed_float3 is a vector of 3 floats(position of each vertex)
// [[ buffer(0) ]] means the first data in vertex buffer
vertex float4 basic_vertex(const device packed_float3* vertex_array [[ buffer(0) ]],
                           unsigned int vid [[ vertex_id ]]) {
    return float4(vertex_array[vid], 1.0); // return final position of vertex
}

vertex VertexOut vertex_main(const VertexIn vertexIn                    [[ stage_in ]],
                             constant STLRUniforms &uniforms            [[ buffer(BufferIndexUniforms) ]],
                             constant STLRModelParams *modelParamsArray [[ buffer(BufferIndexModelParams) ]],
                             uint baseInstance                          [[ base_instance ]]) {
    STLRModelParams modelParams = modelParamsArray[baseInstance];
    VertexOut out;
    matrix_float4x4 mvp = uniforms.projectionMatrix * uniforms.viewMatrix * modelParams.modelMatrix;
    out.position = mvp * vertexIn.position;
    out.worldPosition = (modelParams.modelMatrix * vertexIn.position).xyz;
    out.normal = uniforms.normalMatrix * vertexIn.normal;
    out.shadowPosition = uniforms.shadowMatrix * modelParams.modelMatrix * vertexIn.position;
    out.worldTangent = uniforms.normalMatrix * vertexIn.tangent;
    out.worldBitangent = uniforms.normalMatrix * vertexIn.bitangent;
    out.textureCoordinates = vertexIn.textureCoordinates;
    out.modelIndex = baseInstance;
    out.occlusion = vertexIn.ambientOcculusion;
    
    return out;
}

vertex VertexOut mp_vertex(const VertexIn in                        [[ stage_in ]],
                           constant STLRUniforms &uniforms          [[ buffer(BufferIndexUniforms) ]],
                           constant Instances *instances            [[ buffer(BufferIndexInstances) ]],
                           uint instanceID                          [[ instance_id ]],
                           constant STLRModelParams &modelParams    [[ buffer(BufferIndexModelParams) ]]) {
    VertexOut out;
    Instances instance = instances[instanceID];
    
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * modelParams.modelMatrix * instance.modelMatrix * in.position;
    out.worldPosition = (modelParams.modelMatrix * in.position * instance.modelMatrix).xyz;
    out.textureCoordinates = in.textureCoordinates;
    out.normal = uniforms.normalMatrix * instance.normalMatrix * in.normal;
    out.worldTangent = uniforms.normalMatrix * instance.normalMatrix * in.tangent;
    out.worldBitangent = uniforms.normalMatrix * instance.normalMatrix * in.bitangent;
    out.shadowPosition = uniforms.shadowMatrix * modelParams.modelMatrix * in.position;
    
    return out;
}

// fragment shader returns color of vertex
// half4 is a four component RGBA, it's more memory efficient than float4
fragment float4 basic_fragment(VertexOut v [[ stage_in ]]) {
    return v.color;
}

fragment float4 grayScale_fragment(VertexOut v [[ stage_in ]]) {
    float grayColor = (v.color.r + v.color.g + v.color.b) / 3;
    
    return float4(grayColor, grayColor, grayColor, 1.0);
}

// texture fragment
fragment half4 textured_fragment(VertexOut v [[ stage_in ]],
                                 sampler sampler2d [[ sampler(0) ]],
                                 texture2d<float> texture [[ texture(BaseColorTexture) ]]) {
    float4 color = texture.sample(sampler2d, v.textureCoordinates);
    color = color * v.materialColor;
    
    return half4(color.r, color.g, color.b, 1.0);
}

// material fragment
fragment half4 fragment_color(VertexOut v [[ stage_in ]],
                              constant Light *lights [[ buffer(3) ]],
                              constant STLRLightConstants &lightConstants [[ buffer(14) ]],
                              constant STLRFragmentUniforms &fragmentConstants [[ buffer(BufferIndexFragmentUniforms) ]]) {
    
    float4 color = v.materialColor;
    float3 baseColor = float3(1, 1, 1);
    float3 diffuseColor = 0;
    float3 ambientColor = 0;
    float3 specularColor = 0;
    float3 materialSpecularColor = float3(1, 1, 1);
    
    for (uint i = 0; i < lightConstants.lightCount; i++) {
        Light light = lights[i];
        
        float3 normal = normalize(v.normal);
        if (light.type == Sunlight){
            float3 lightDirection = normalize(light.position);
            
            float diffuseIntensity = saturate(dot(lightDirection, normal));
            diffuseColor += light.color * baseColor * diffuseIntensity;
            if (diffuseIntensity > 0) {
                float3 reflection = reflect(lightDirection, normal);

                float3 cameraPosition = normalize(v.worldPosition - v.eyePosition);
                float specularIntensity = pow(saturate(dot(reflection, cameraPosition)), v.shininess);
                specularColor += light.specularColor * materialSpecularColor * specularIntensity;
            }
        } else if (light.type == Ambientlight) {
            ambientColor += light.color * light.intensity;
        }
    }
    
    if (color.a == 0.0)
        discard_fragment();
    
    color = color * float4(ambientColor + diffuseColor + specularColor, 1);
    
    return half4(color.r, color.g, color.b, 1.0);
}

// lighting fragment
fragment float4 lit_textured_fragment(VertexOut v [[ stage_in ]],
                                      sampler sampler2d [[ sampler(0) ]],
                                      constant Light *lights [[ buffer(3) ]],
                                      texture2d<float> texture [[ texture(BaseColorTexture),  function_constant(hasColorTexture) ]],
                                      texture2d<float> normalTexture [[ texture(NormalTexture),  function_constant(hasNormalTexture) ]],
                                      depth2d<float> shadowTexture [[ texture(Shadow) ]],
                                      constant Material &material [[ buffer(13) ]],
                                      constant STLRLightConstants &lightConstants [[ buffer(14) ]],
                                      constant STLRFragmentUniforms &fragmentConstants [[ buffer(BufferIndexFragmentUniforms) ]]) {
    
    float4 color = float4(material.baseColor, 1.0);
//    float materialShininess = material.shininess;
//    float3 materialSpecularColor = material.specularColor;
    
//    float3 normal;
//    if (hasNormalTexture) {
//        normal = normalTexture.sample(sampler2d, v.textureCoordinates * fragmentConstants.tiling).rgb;
//        normal = normal * 2 - 1;
//    } else {
//        normal = v.normal;
//    }
//
//    normal = normalize(normal);
    
    float3 baseColor = material.baseColor;
    float3 diffuseColor = 0;
    float3 ambientColor = 0;
    float3 specularColor = 0;
    
//    float3 normalDirection = float3x3(v.worldTangent, v.worldBitangent, v.normal) * normal;
//    normalDirection = normalize(normalDirection);
    
    for (uint i = 0; i < fragmentConstants.lightCount; i++) {
        Light light = lights[i];
        if (light.type == Ambientlight) {
            ambientColor += light.color * light.intensity;
        }
    }
    diffuseColor = calculateLighting(v.normal, v.worldPosition, fragmentConstants, lights, baseColor);
    
    float2 xy = v.shadowPosition.xy;
    xy = xy * 0.5 + 0.5;
    xy.y = 1 - xy.y;
    constexpr sampler s(coord::normalized, filter::linear, address::clamp_to_edge, compare_func::less);
    
//    float shadow_sample = shadowTexture.sample(s, xy);
//    float current_sample = v.shadowPosition.z / v.shadowPosition.w;
//    if (current_sample > shadow_sample ) {
//        diffuseColor *= 0.5;
//    }
    
    const int neighborWidth = 3;
    const float neighbors = (neighborWidth * 3.0 + 1.0) * (neighborWidth * 3.0 + 1.0);
    
    float mapSize = 4096;
    float texelSize = 1.0 / mapSize;
    float total = 0.0;
    for (int x = -neighborWidth; x <= neighborWidth; x++) {
        for (int y = -neighborWidth; y <= neighborWidth; y++) {
            float shadow_sample = shadowTexture.sample(s, xy + float2(x, y) * texelSize);
            float current_sample = v.shadowPosition.z / v.shadowPosition.w;
            if (current_sample > shadow_sample) {
                total += 1.0;
            }
        }
    }
    
    total /= neighbors;
    float lightFactor = 1.0 - (total * v.shadowPosition.w);
    
    color = color * float4(ambientColor + diffuseColor * lightFactor + specularColor, 1);
    
    return float4(color.r, color.g, color.b, 1.0);
}

fragment float4 fragment_PBR(VertexOut v [[ stage_in ]],
                             sampler sampler2d [[ sampler(0) ]],
                             constant Light *lights [[ buffer(3) ]],
                             texture2d<float> texture [[ texture(BaseColorTexture), function_constant(hasColorTexture) ]],
                             texture2d<float> normalTexture [[ texture(NormalTexture), function_constant(hasNormalTexture) ]],
                             texture2d<float> roughnessTexture [[texture(RoughnessTexture), function_constant(hasRoughnessTexture) ]],
                             texture2d<float> metallicTexture [[ texture(MetallicTexture), function_constant(hasMetallicTexture) ]],
                             texture2d<float> aoTexture [[ texture(AOTexture), function_constant(hasAOTexture)]],
                             depth2d<float> shadowTexture [[ texture(Shadow) ]],
                             constant Material &material [[ buffer(13) ]],
                             constant STLRLightConstants &lightConstants [[ buffer(14) ]],
                             constant STLRFragmentUniforms &fragmentConstants [[ buffer(BufferIndexFragmentUniforms) ]],
                             constant STLRModelParams &modelParams [[buffer(BufferIndexModelParams)]]) {
    
    //    float4 color = float4(texture.sample(sampler2d, v.textureCoordinates * fragmentConstants.tiling).rgb, 1);
    //    color = color * v.materialColor;
    
    float4 color;// = float4(material.baseColor, 1.0);
    if (hasColorTexture) {
        float4 colorAlpha = texture.sample(sampler2d, v.textureCoordinates * modelParams.tiling);
        color = float4(texture.sample(sampler2d, v.textureCoordinates * modelParams.tiling).rgb, 1);
        
        if (colorAlpha.a < 0.2) {
            discard_fragment();
        }
    } else {
        color = float4(material.baseColor, 1.0);
    }
    
    float metallic = material.metallic;
    if (hasMetallicTexture) {
        metallic = metallicTexture.sample(sampler2d, v.textureCoordinates).r;
    } else {
        metallic = material.metallic;
    }
    // extract roughness
    float roughness;
    if (hasRoughnessTexture) {
        roughness = roughnessTexture.sample(sampler2d, v.textureCoordinates).r;
    } else {
        roughness = material.roughness;
    }
    // extract ambient occlusion
    float ambientOcclusion = 1.0;
    if (hasAOTexture) {
        ambientOcclusion = aoTexture.sample(sampler2d, v.textureCoordinates).r;
    } else {
        ambientOcclusion = 1.0;
    }
    
    float3 normal;
    if (hasNormalTexture) {
        float3 normalValue = normalTexture.sample(sampler2d, v.textureCoordinates * modelParams.tiling).rgb;
        normalValue = normalValue * 2 - 1;
        normal = v.normal * normalValue.z + v.worldTangent * normalValue.x + v.worldBitangent * normalValue.y;
    } else {
        normal = v.normal;
    }
    
    normal = normalize(normal);
    
    float3 viewDirection = normalize(fragmentConstants.cameraPosition - v.worldPosition);
    float3 specularOutput;
    float3 diffuseColor;
    float3 ambientColor = 0;
    
    for (uint i = 0; i < fragmentConstants.lightCount; i++) {
        Light light = lights[i];
        if (light.type == 1) {
            float3 lightDirection = normalize(light.position);
            lightDirection = light.position;
            
            // all the necessary components are in place
            Lighting lighting;
            lighting.lightDirection = lightDirection;
            lighting.viewDirection = viewDirection;
            lighting.baseColor = color.xyz;
            lighting.normal = normal;
            lighting.metallic = metallic;
            lighting.roughness = roughness;
            lighting.ambientOcclusion = ambientOcclusion;
            lighting.lightColor = light.color;
            lighting.intensity = light.intensity;
            
            specularOutput = calculateSpecularOutput(lighting);
            
            //compute Lambertian diffuse
//            float nDotl = saturate(dot(lighting.normal, lighting.lightDirection));
//            diffuseColor = light.color * color.rgb * nDotl * ambientOcclusion;
//            diffuseColor *= 1.0 - metallic;
        } else {
            ambientColor += light.color * light.intensity;
        }
    }
    
    diffuseColor = calculateLighting(v.normal, v.worldPosition, fragmentConstants, lights, color.xyz);
    
    // shadow with pcf
    float2 xy = v.shadowPosition.xy;
    xy = xy * 0.5 + 0.5;
    xy.y = 1 - xy.y;
    constexpr sampler s(coord::normalized, filter::linear, address::clamp_to_edge, compare_func::less);
    
    const int neighborWidth = 3;
    const float neighbors = (neighborWidth * 2.0 + 1.0) * (neighborWidth * 2.0 + 1.0);
    
    float mapSize = 4096;
    float texelSize = 1.0 / mapSize;
    float total = 0.0;
    for (int x = -neighborWidth; x <= neighborWidth; x++) {
        for (int y = -neighborWidth; y <= neighborWidth; y++) {
            float shadow_sample = shadowTexture.sample(s, xy + float2(x, y) * texelSize);
            float current_sample = v.shadowPosition.z / v.shadowPosition.w;
            if (current_sample > shadow_sample) {
                total += 1.0;
            }
        }
    }
    
    total /= neighbors;
    float lightFactor = 1.0 - (total * v.shadowPosition.w);
    
    return color * float4(specularOutput + diffuseColor * lightFactor + ambientColor, 1.0) * ambientOcclusion;
}

fragment float4 skyboxTest(VertexOut in [[ stage_in ]],
                           constant STLRFragmentUniforms &fragmentConstants [[ buffer(BufferIndexFragmentUniforms) ]],
                           texturecube<float> skybox [[ texture(20) ]]) {
    float3 viewDirection = in.worldPosition.xyz - fragmentConstants.cameraPosition;
    float3 textureCoordinates = reflect(viewDirection, in.normal);
    constexpr sampler defaultSampler(filter::linear);
    float4 color = skybox.sample(defaultSampler, textureCoordinates);
    float4 copper = float4(211/255.0, 211/255.0, 211/255.0, 1);
    color = color * copper;
    return color;
}
