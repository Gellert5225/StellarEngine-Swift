//
//  Shadow.metal
//  ObsidianEngine
//
//  Created by Jiahe Li on 17/03/2019.
//  Copyright © 2019 Gellert. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

#import "Types.h"

struct VertexIn {
    float4 position [[ attribute(0) ]];
};

vertex float4 vertex_depth(const VertexIn vertexIn [[ stage_in ]],
                           constant STLRUniforms &uniforms [[ buffer(11) ]]) {
    matrix_float4x4 mvp = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix;
    float4 position = mvp * vertexIn.position;
    return position;
}
