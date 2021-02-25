//
//  Terrain.metal
//  ObsidianEngine
//
//  Created by Jiahe Li on 16/03/2019.
//  Copyright © 2019 Gellert. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;
#import "Types.h"

struct VertexOut {
    float4 position [[ position ]];
    float4 color;
    float height;
    float2 uv;
    float slope;
};

struct ControlPoint {
    float4 position [[ attribute(0) ]];
};

float calc_distance(float3 pointA, float3 pointB,
                    float3 camera_position, float4x4 modelMatrix) {
    float3 positionA = (modelMatrix * float4(pointA, 1)).xyz;
    float3 positionB = (modelMatrix * float4(pointB, 1)).xyz;
    float3 midpoint = (positionA + positionB) * 0.5;
    
    float camera_distance = distance(camera_position, midpoint);
    return camera_distance / 4;
}

kernel void terrain_kernel(constant float* edge_factors      [[ buffer(0) ]],
                           constant float* inside_factors    [[ buffer(1) ]],
                           device MTLQuadTessellationFactorsHalf* factors [[ buffer(2) ]],
                           constant float4 &camera_position  [[ buffer(3) ]],
                           constant float4x4 &modelMatrix    [[ buffer(4) ]],
                           constant float3* control_points   [[ buffer(5) ]],
                           constant STLRTerrainUniforms &terrain [[ buffer(6) ]],
                           uint pid [[ thread_position_in_grid ]]) {
    uint index = pid * 4;
    float totalTessellation = 0;
    for (int i = 0; i < 4; i++) {
        int pointAIndex = i;
        int pointBIndex = i + 1;
        if (pointAIndex == 3) {
            pointBIndex = 0;
        }
        int edgeIndex = pointBIndex;
        float cameraDistance = calc_distance(control_points[pointAIndex + index],
                                             control_points[pointBIndex + index],
                                             camera_position.xyz,
                                             modelMatrix);
        float tessellation = max(4.0, terrain.maxTessellation / cameraDistance);
        factors[pid].edgeTessellationFactor[edgeIndex] = tessellation;
        totalTessellation += tessellation;
    }
    factors[pid].insideTessellationFactor[0] = totalTessellation * 0.25;
    factors[pid].insideTessellationFactor[1] = totalTessellation * 0.25;
}

// function qualifier, tells the vertex function that the vertices are coming from tesellated patches
// a quad with 4 control points
[[ patch(quad, 4) ]]
vertex VertexOut terrain_vertex(patch_control_point<ControlPoint> control_points [[ stage_in ]],
                                constant float4x4 &mvp [[ buffer(1) ]],
                                uint patchID [[ patch_id ]],
                                texture2d<float> heightMap [[ texture(0) ]],
                                texture2d<float> terrainSlope [[ texture (4) ]],
                                constant STLRTerrainUniforms &terrain [[ buffer(6) ]],
                                float2 patch_coord [[ position_in_patch ]]) {
    float u = patch_coord.x;
    float v = patch_coord.y;
    
    float2 top = mix(control_points[0].position.xz, control_points[1].position.xz, u);
    float2 bottom = mix(control_points[3].position.xz, control_points[2].position.xz, u);
    
    VertexOut out;
    float2 interpolated = mix(top, bottom, v);
    float4 position = float4(interpolated.x, 0.0, interpolated.y, 1.0);
    
    float2 xy = (position.xz + terrain.size / 2.0) / terrain.size;
    constexpr sampler sample;
    float4 color = heightMap.sample(sample, xy);
    out.color = float4(color.r);
    out.slope = terrainSlope.sample(sample, xy).r;
    
    float height = (color.r * 2 - 1) * terrain.height;
    position.y = height;
    
    out.position = mvp * position;
    out.uv = xy;
    out.height = height;
    return out;
}

fragment float4 terrain_fragment(VertexOut in [[ stage_in ]],
                                 constant float &tiling [[ buffer(1) ]],
                                 texture2d<float> cliffMap [[ texture(1) ]],
                                 texture2d<float> snowMap [[ texture(2) ]],
                                 texture2d<float> grassMap [[ texture(3) ]]) {
    constexpr sampler sample(filter::linear, address::repeat);
    float4 color;
    float4 grass = grassMap.sample(sample, in.uv * tiling);
    float4 cliff = cliffMap.sample(sample, in.uv * tiling);
    float4 snow = snowMap.sample(sample, in.uv * tiling);
    if (in.height < -0.6) {
        color = grass;
    } else if (in.height < -0.4) {
        float value = 1 - ((in.height + 0.4) / -0.2);
        value = (in.height + 0.6) / 0.2;
        color = mix(grass, cliff, value);
    } else if (in.height < -0.2) {
        color = cliff;
    } else {
        if (in.slope < 0.1) {
            color = snow;
        } else {
            color = cliff;
        }
    }
    return color;
}
