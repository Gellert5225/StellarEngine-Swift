//
//  OBSDWater.swift
//  ObsidianEngine
//
//  Created by Jiahe Li on 23/03/2019.
//  Copyright © 2019 Gellert. All rights reserved.
//

import MetalKit
import ModelIO

open class OBSDWater: OBSDNode, Texturable {
    
    var transform = Transform()
    var pipelineState: MTLRenderPipelineState!
    var reflectionRenderPass: RenderPass
    var texture: MTLTexture?
    var timer: Float = 0
    
    var mesh: MTKMesh?
    
    public override init() {
        reflectionRenderPass = RenderPass(name: "reflection", size: OBSDRenderer.drawableSize)
        super.init()
        
        let allocator = MTKMeshBufferAllocator(device: OBSDRenderer.metalDevice)
        let plane = MDLMesh.newPlane(withDimensions: [1000, 1000], segments: [1, 1], geometryType: .triangles, allocator: allocator)
        
        do {
            mesh = try MTKMesh(mesh: plane, device: OBSDRenderer.metalDevice)
            let frameworkBundle = Bundle(for: OBSDShape.self)
            texture = try OBSDWater.loadTexture(imageName: "ocean3", bundle: frameworkBundle)
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
        //descriptor.sampleCount = 4;
        descriptor.depthAttachmentPixelFormat = .depth32Float
        descriptor.vertexFunction = OBSDRenderer.library.makeFunction(name: "vertex_water")
        descriptor.fragmentFunction = OBSDRenderer.library.makeFunction(name: "fragment_water")
        descriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(mesh!.vertexDescriptor)
        do {
            try pipelineState = OBSDRenderer.metalDevice.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    func render(renderEncoder: MTLRenderCommandEncoder, uniforms: OBSDUniforms, fragmentUniform: OBSDFragmentUniforms) {
        guard let mesh = mesh else {
            fatalError("Could not load water mesh")
        }
        
        renderEncoder.pushDebugGroup("Water encoder")
        
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(mesh.vertexBuffers[0].buffer, offset: 0, index: 0)
        
        var uniform = uniforms
        uniform.modelMatrix = transform.modelMatrix
        
        var frag = fragmentUniform
        
        renderEncoder.setVertexBytes(&uniform, length: MemoryLayout<OBSDUniforms>.stride, index: Int(BufferIndexUniforms.rawValue))
        renderEncoder.setFragmentTexture(reflectionRenderPass.texture, index: 0)
        renderEncoder.setFragmentTexture(texture, index: 2)
        renderEncoder.setFragmentBytes(&timer, length: MemoryLayout<Float>.size, index: 3)
        renderEncoder.setFragmentBytes(&frag, length: MemoryLayout<OBSDFragmentUniforms>.stride, index: 15)
        
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
