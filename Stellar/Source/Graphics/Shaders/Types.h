//
//  Types.h
//  ObsidianEngine
//
//  Created by Jiahe Li on 22/06/2018.
//  Copyright © 2018 Gellert. All rights reserved.
//

#ifndef Types_h
#define Types_h

#import <simd/simd.h>

#define sunLight vector_float3(0, -1000, -1000)
#define near 0.1
#define far 100.0
#define pi 3.1415926535897932384626433832795

typedef matrix_float4x4 float4x4;
typedef matrix_float3x3 float3x3;
typedef vector_float2 float2;
typedef vector_float3 float3;
typedef vector_float4 float4;

typedef struct {
    vector_float2 size;
    float height;
    uint maxTessellation;
} STLRTerrainUniforms;

typedef struct {
    matrix_float4x4 modelMatrix;
    matrix_float4x4 viewMatrix;
    matrix_float4x4 projectionMatrix;
    matrix_float3x3 normalMatrix;
    matrix_float4x4 shadowMatrix;
    vector_float4 clipPlane;
    vector_float3 cameraPosition;
} STLRUniforms;

typedef struct {
    float3 baseColor;
    float3 specularColor;
    float roughness;
    float metallic;
    float3 ambientOcclusion;
    float shininess;
} STLRMaterial;

typedef struct {
    float4x4 projectionMatrix;
    float3 cameraPosition;
    float4x4 viewMatrix;
} STLRSceneConstants;

typedef struct {
    uint tiling;
    float3 cameraPosition;
    uint lightCount;
} STLRFragmentUniforms;

typedef struct {
    uint lightCount;
} STLRLightConstants;

typedef enum {
    unused = 0,
    Sunlight = 1,
    Spotlight = 2,
    Pointlight = 3,
    Ambientlight = 4
} LightType;

typedef struct {
    float3 position;  // for a sunlight, this is direction
    float3 color;
    float3 specularColor;
    float intensity;
    float3 attenuation;
    LightType type;
    float coneAngle;
    float3 coneDirection;
    float coneAttenuation;
} STLRLight;

typedef enum {
    BaseColorTexture = 4,
    NormalTexture = 5,
    RoughnessTexture = 6,
    MetallicTexture = 7,
    AOTexture = 8,
    STLRGBufferTexturesIndex = 9
} Textures;

typedef enum {
    Albedo = 0,
    Normal = 1,
    Position = 2,
    Shadow = 3,
    Specular = 4
} GBufferTextures;

typedef enum {
    BufferIndexVertices = 0,
    BufferIndexLight = 2,
    BufferIndexUniforms = 11,
    BufferIndexSceneConstants = 12,
    BufferIndexMaterials = 13,
    BufferIndexLightConstants = 14,
    BufferIndexFragmentUniforms = 15,
    BufferIndexInstances = 16,
    BufferIndexSkybox = 20,
    BufferIndexSkyboxDiffuse = 21,
    BufferIndexBRDFLut = 22
} STLRBufferIndices;

struct MorphInstance {
    uint textureID;
    uint morphTargetID;
    matrix_float4x4 modelMatrix;
    matrix_float3x3 normalMatrix;
};

struct Instances {
    matrix_float4x4 modelMatrix;
    matrix_float3x3 normalMatrix;
};

typedef struct Lighting {
    float3 lightDirection;
    float3 viewDirection;
    float3 baseColor;
    float3 normal;
    float metallic;
    float roughness;
    float ambientOcclusion;
    float3 lightColor;
    float intensity;
} Lighting;

#endif /* Types_h */
