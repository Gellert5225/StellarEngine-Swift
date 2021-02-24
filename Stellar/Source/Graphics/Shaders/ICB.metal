//
//  ICB.metal
//  Stellar
//
//  Created by Gellert Li on 2/24/21.
//  Copyright © 2021 Gellert. All rights reserved.
//

#include <metal_stdlib>
#include "Types.h"
#include "ShadersCommon.h"
using namespace metal;

struct ICBContainer {
    command_buffer icb [[ id(0) ]];
};

struct Model {
    constant float *vertexBuffer;
    constant uint *indexBuffer;
    constant float *textureBuffer;
    render_pipeline_state pipelineState;
};

kernel void encodeCommands(uint modelIndex                                                          [[ thread_position_in_grid ]],
                           constant MTLDrawIndexedPrimitivesIndirectArguments *drawArgumentsBuffer  [[ buffer(BufferIndexDrawArguments) ]],
                           constant STLRUniforms &uniforms                                          [[ buffer(BufferIndexUniforms) ]],
                           constant STLRFragmentUniforms &fragmentUniforms                          [[ buffer(BufferIndexFragmentUniforms) ]],
                           constant STLRModelParams *modelParamsArray                               [[ buffer(BufferIndexModelParams) ]],
                           constant Model *modelsArray                                              [[ buffer(BufferIndexModels) ]],
                           device ICBContainer *icbContainer                                        [[ buffer(BufferIndexICB) ]]) {
    Model model = modelsArray[modelIndex];
    MTLDrawIndexedPrimitivesIndirectArguments drawArguments = drawArgumentsBuffer[modelIndex];
    render_command cmd(icbContainer->icb, modelIndex);
    
    cmd.set_render_pipeline_state(model.pipelineState);
    cmd.set_vertex_buffer(&uniforms, BufferIndexUniforms);
    cmd.set_fragment_buffer(&fragmentUniforms, BufferIndexFragmentUniforms);
    cmd.set_vertex_buffer(modelParamsArray, BufferIndexModelParams);
    cmd.set_fragment_buffer(modelParamsArray, BufferIndexModelParams);
    cmd.set_vertex_buffer(model.vertexBuffer, 0);
    cmd.set_fragment_buffer(model.textureBuffer, STLRGBufferTexturesIndex);
    
    cmd.draw_indexed_primitives(primitive_type::triangle,
                                drawArguments.indexCount,
                                model.indexBuffer + drawArguments.indexStart,
                                drawArguments.instanceCount,
                                drawArguments.baseVertex,
                                drawArguments.baseInstance);
}
