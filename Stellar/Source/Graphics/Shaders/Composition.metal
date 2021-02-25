//
//  Composition.metal
//  ObsidianEngine
//
//  Created by Jiahe Li on 19/03/2019.
//  Copyright © 2019 Gellert. All rights reserved.
//

#include "ShadersCommon.h"
using namespace metal;

vertex VertexOut composition_vert(constant float2 *quadVertices     [[ buffer(0) ]],
                                  constant float2 *quadTexCoords    [[ buffer(1) ]],
                                  uint id [[ vertex_id ]]) {
    VertexOut out;
    out.position = float4(quadVertices[id], 0.0, 1.0);
    out.textureCoordinates = quadTexCoords[id];
    return out;
}

fragment float4 composition_frag(VertexOut in [[ stage_in ]],
                                 constant STLRFragmentUniforms &fragmentUniforms [[ buffer(BufferIndexFragmentUniforms) ]],
                                 constant STLRLight *lightsBuffer               [[ buffer(BufferIndexLight) ]],
                                 depth2d<float> shadowTexture                   [[ texture(Shadow) ]],
                                 texture2d<float> albedoTexture                 [[ texture(Albedo) ]],
                                 texture2d<float> normalTexture                 [[ texture(Normal) ]],
                                 texture2d<float> positionTexture               [[ texture(Position) ]],
                                 texture2d<float> specularTexture               [[ texture(Specular) ]]) {
    float4 albedo = albedoTexture.read(uint2(in.position.xy));
    float3 normal = normalTexture.read(uint2(in.position.xy)).xyz;
    float3 position = positionTexture.read(uint2(in.position.xy)).xyz;
    float3 baseColor = albedo.rgb;
    float3 diffuseColor = calculateLighting(normal, position, fragmentUniforms, lightsBuffer, baseColor);

    return float4(diffuseColor, 0);
}


/*
 #define SAMPLES_COUNT 32
 #define INV_SAMPLES_COUNT (1.0f / SAMPLES_COUNT)
 
 uniform sampler2D decal;  // decal texture
 uniform sampler2D spot;   // projected spotlight image
 uniform sampler2DShadow shadowMap;  // shadow map
 uniform float fwidth;
 uniform vec2 offsets[SAMPLES_COUNT];
 
 // these are passed down from vertex shader
 varying vec4 shadowMapPos;
 varying vec3 normal;
 varying vec2 texCoord;
 varying vec3 lightVec;
 varying vec3 view;
 
 void main(void)  {
    float shadow = 0;
    float fsize = shadowMapPos.w * fwidth;
    vec4 smCoord = shadowMapPos;
 
    for (int i = 0; i < SAMPLES_COUNT; i++) {
        smCoord.xy = offsets[i] * fsize + shadowMapPos;
        shadow += texture2DProj(shadowMap, smCoord) * INV_SAMPLES_COUNT;
    }
 
    vec3 N = normalize(normal);
    vec3 L = normalize(lightVec);
    vec3 V = normalize(view);
    vec3 R = reflect(-V, N);
 
    // calculate diffuse dot product
    float NdotL = max(dot(N, L), 0);
 
    // modulate lighting with the computed shadow value
    vec3 color = texture2D(decal, texCoord).xyz;
 
    gl_FragColor.xyz = (color * NdotL + pow(max(dot(R, L), 0), 64)) * shadow * texture2DProj(spot, shadowMapPos) + color * 0.1;
 }
 */

/*
 #define SAMPLES_COUNT 64
 #define SAMPLES_COUNT_DIV_2 32
 #define INV_SAMPLES_COUNT (1.0f / SAMPLES_COUNT)
 
 uniform sampler2D decal;   // decal texture
 uniform sampler3D jitter;  // jitter map
 uniform sampler2D spot;    // projected spotlight image
 uniform sampler2DShadow shadowMap;  // shadow map
 uniform float fwidth;
 uniform vec2 jxyscale;      // these are passed down from vertex shader
 
 varying vec4 shadowMapPos;
 varying vec3 normal;
 varying vec2 texCoord;
 varying vec3 lightVec;
 varying vec3 view;
 
 void main(void)  {
    float shadow = 0;
    float fsize = shadowMapPos.w * fwidth;
    vec3 jcoord = vec3(gl_FragCoord.xy * jxyscale, 0);
    vec4 smCoord = shadowMapPos;
 
    // take cheap "test" samples first
    for (int i = 0; i < 4; i++) {
        vec4 offset = texture3D(jitter, jcoord);
        jcoord.z += 1.0f / SAMPLES_COUNT_DIV_2;
        smCoord.xy = offset.xy * fsize + shadowMapPos;
        shadow += texture2DProj(shadowMap, smCoord) / 8;
        smCoord.xy = offset.zw * fsize + shadowMapPos;
        shadow += texture2DProj(shadowMap, smCoord) / 8;
    }
    vec3 N = normalize(normal);
    vec3 L = normalize(lightVec);
    vec3 V = normalize(view);
    vec3 R = reflect(-V, N);
    
    // calculate diffuse dot product
    float NdotL = max(dot(N, L), 0);
 
    // if all the test samples are either zeroes or ones, or diffuse dot product is zero, we skip expensive shadow-map filtering
    if ((shadow - 1) * shadow * NdotL != 0) { // most likely, we are in the penumbra
        shadow *= 1.0f / 8; // adjust running total
 
        // refine our shadow estimate
        for (int i = 0; i < SAMPLES_COUNT_DIV_2 - 4; i++) {
            vec4 offset = texture3D(jitter, jcoord);
            jcoord.z += 1.0f / SAMPLES_COUNT_DIV_2;
            smCoord.xy = offset.xy * fsize + shadowMapPos;
            shadow += texture2DProj(shadowMap, smCoord)* INV_SAMPLES_COUNT;
            smCoord.xy = offset.zw * fsize + shadowMapPos;
            shadow += texture2DProj(shadowMap, smCoord)* INV_SAMPLES_COUNT;
        }
    }
 
    // all done Ð modulate lighting with the computed shadow value
    vec3 color = texture2D(decal, texCoord).xyz;
    gl_FragColor.xyz = (color * NdotL + pow(max(dot(R, L), 0), 64)) * shadow * texture2DProj(spot, shadowMapPos) + color * 0.1;
 }
 */
