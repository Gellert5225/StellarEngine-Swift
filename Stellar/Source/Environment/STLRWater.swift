//
//  STLRWater.swift
//  ObsidianEngine
//
//  Created by Jiahe Li on 23/03/2019.
//  Copyright © 2019 Gellert. All rights reserved.
//

import MetalKit
import ModelIO

open class STLRWater: STLRNode, Texturable {
    
    var transform = Transform()
    var pipelineState: MTLRenderPipelineState!
    var reflectionRenderPass: RenderPass
    var texture: MTLTexture?
    var timer: Float = 0
    
    var mesh: MTKMesh?
    
    public override init() {
        reflectionRenderPass = RenderPass(name: "reflection", size: STLRRenderer.drawableSize, multiplier: 0.5)
        super.init()
        
        name = "Water"
        
        let allocator = MTKMeshBufferAllocator(device: STLRRenderer.metalDevice)
        let plane = MDLMesh.newPlane(withDimensions: [1000, 1000], segments: [1, 1], geometryType: .triangles, allocator: allocator)
        
        do {
            mesh = try MTKMesh(mesh: plane, device: STLRRenderer.metalDevice)
            let frameworkBundle = Bundle(for: STLRShape.self)
            texture = try STLRWater.loadTexture(imageName: "ocean2", bundle: frameworkBundle)
        } catch {
            fatalError(error.localizedDescription)
        }
        
        makePipelineState()
    }
    
    func makePipelineState() {
        let descriptor = MTLRenderPipelineDescriptor()
        //descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        descriptor.colorAttachments[1].pixelFormat = .rgba16Float
        descriptor.colorAttachments[2].pixelFormat = .rgba16Float
        descriptor.sampleCount = 4;
        descriptor.depthAttachmentPixelFormat = .depth32Float
        descriptor.vertexFunction = STLRRenderer.library.makeFunction(name: "vertex_water")
        descriptor.fragmentFunction = STLRRenderer.library.makeFunction(name: "fragment_water")
        descriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(mesh!.vertexDescriptor)
        do {
            try pipelineState = STLRRenderer.metalDevice.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    func render(renderEncoder: MTLRenderCommandEncoder, uniforms: STLRUniforms, fragmentUniform: STLRFragmentUniforms) {
        guard let mesh = mesh else {
            fatalError("Could not load water mesh")
        }
        
        renderEncoder.pushDebugGroup("Water Pass")
        
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(mesh.vertexBuffers[0].buffer, offset: 0, index: 0)
        
        var uniform = uniforms
        uniform.modelMatrix = transform.modelMatrix
        
        var frag = fragmentUniform
        
        renderEncoder.setVertexBytes(&uniform, length: MemoryLayout<STLRUniforms>.stride, index: Int(BufferIndexUniforms.rawValue))
        renderEncoder.setFragmentTexture(reflectionRenderPass.texture_resolve, index: 0)
        renderEncoder.setFragmentTexture(texture, index: 2)
        renderEncoder.setFragmentBytes(&timer, length: MemoryLayout<Float>.size, index: 3)
        renderEncoder.setFragmentBytes(&frag, length: MemoryLayout<STLRFragmentUniforms>.stride, index: 15)
        
        for submesh in mesh.submeshes {
            renderEncoder.drawIndexedPrimitives(type: .triangle, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer: submesh.indexBuffer.buffer, indexBufferOffset: submesh.indexBuffer.offset)
        }
        
        renderEncoder.popDebugGroup()
    }
    
    func update() {
        timer += 0.0001
    }
    
    //func renderReflextion()
    
}
