//
//  Morph.swift
//  ObsidianEngine
//
//  Created by Jiahe Li on 15/03/2019.
//  Copyright © 2019 Gellert. All rights reserved.
//

import MetalKit
import ModelIO

open class STLRMorph: STLRNode {
    
    let instanceCount: Int
    let instanceBuffer: MTLBuffer
    let pipelineState: MTLRenderPipelineState
    
    let morphTargetCount: Int
    let textureCount: Int
    
    let vertexBuffer: MTLBuffer
    let submesh: MTKSubmesh?
    
    var vertexCount: Int
    
    static let mdlVertexDescriptor: MDLVertexDescriptor = {
        let vertexDescriptor = MDLVertexDescriptor()
        var offset = 0
        let packedFloat3Size = MemoryLayout<Float>.stride * 3;
        vertexDescriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition,
                                                            format: .float3,
                                                            offset: offset,
                                                            bufferIndex: 0)
        offset += packedFloat3Size
        vertexDescriptor.attributes[1] = MDLVertexAttribute(name: MDLVertexAttributeNormal,
                                                            format: .float3,
                                                            offset: offset,
                                                            bufferIndex: 0)
        offset += packedFloat3Size
        vertexDescriptor.attributes[2] = MDLVertexAttribute(name: MDLVertexAttributeTextureCoordinate,
                                                            format: .float2,
                                                            offset: offset,
                                                            bufferIndex: 0)
        offset += MemoryLayout<simd_float2>.stride
        vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: offset)
        return vertexDescriptor
    }()
    
    static let mtlVertexDescriptor: MTLVertexDescriptor = {
        return MTKMetalVertexDescriptorFromModelIO(STLRMorph.mdlVertexDescriptor)!
    }()
    
    let baseColorTexture: MTLTexture?
    
    public init(name: String, instanceCount: Int = 1, textureNames: [String] = [], morphTargetNames: [String] = []){
        morphTargetCount = morphTargetNames.count
        textureCount = textureNames.count
        
        guard let mesh = STLRMorph.loadMesh(name: morphTargetNames[0]) else {
            fatalError("morph target not loaded")
        }
        
        submesh = STLRMorph.loadSubmesh(mesh: mesh)
        let bufferLength = mesh.vertexBuffers[0].buffer.length
        vertexBuffer = STLRRenderer.metalDevice.makeBuffer(length: bufferLength * morphTargetNames.count)!
        
        let layout = mesh.vertexDescriptor.layouts[0] as! MDLVertexBufferLayout
        vertexCount = bufferLength / layout.stride
        
        let commandBuffer = STLRRenderer.commandQueue.makeCommandBuffer()
        let blitEncoder = commandBuffer?.makeBlitCommandEncoder()
        
        for i in 0..<morphTargetNames.count {
            guard let mesh = STLRMorph.loadMesh(name: morphTargetNames[i]) else {
                fatalError("morph target not loaded")
            }
            let buffer = mesh .vertexBuffers[0].buffer
            blitEncoder?.copy(from: buffer,
                              sourceOffset: 0,
                              to: vertexBuffer,
                              destinationOffset: buffer.length * i,
                              size: buffer.length)
        }
        
        blitEncoder?.endEncoding()
        commandBuffer?.commit()
        
        let library = STLRRenderer.library
        guard let vertexFunction = library?.makeFunction(name: "vertex_morph"),
            let fragmentFunction = library?.makeFunction(name: "fragment_morph") else {
                fatalError("failed to create functions")
        }
        pipelineState = STLRMorph.makePipelineState(vertex: vertexFunction, fragment: fragmentFunction)
        
        self.instanceCount = instanceCount
        instanceBuffer = STLRMorph.buildInstanceBuffer(instanceCount: instanceCount)
        
        baseColorTexture = STLRMorph.loadTextureArray(textureNames: textureNames, bundle: Bundle.main)
        super.init()
        
        // initialize the instance buffer in case there is only one instance
        // (there is no array of Transforms in this class)
        updateBuffer(instance: 0, transform: Transform(), textureID: 0, morphtargetID: 0)
        self.name = name
    }
    
    static func loadSubmesh(mesh: MTKMesh) -> MTKSubmesh {
        guard let submesh = mesh.submeshes.first else {
            fatalError("No submesh found")
        }
        return submesh
    }
    
    static func loadMesh(name: String) -> MTKMesh? {
        let assetURL = Bundle.main.url(forResource: name, withExtension: "obj")!
        let allocator = MTKMeshBufferAllocator(device: STLRRenderer.metalDevice)
        let asset = MDLAsset(url: assetURL,
                             vertexDescriptor: mdlVertexDescriptor,
                             bufferAllocator: allocator)
        let mdlMesh = asset.object(at: 0) as! MDLMesh
        return try? MTKMesh(mesh: mdlMesh, device: STLRRenderer.metalDevice)
    }
    
    static func buildInstanceBuffer(instanceCount: Int) -> MTLBuffer {
        guard let instanceBuffer = STLRRenderer.metalDevice.makeBuffer(length: MemoryLayout<MorphInstance>.stride * instanceCount, options: []) else {
            fatalError("Failed to create instance buffer")
        }
        return instanceBuffer
    }
    
    static func makePipelineState(vertex: MTLFunction, fragment: MTLFunction) -> MTLRenderPipelineState {
        
        var pipelineState: MTLRenderPipelineState
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertex
        pipelineDescriptor.fragmentFunction = fragment
        pipelineDescriptor.sampleCount = 4;
        pipelineDescriptor.vertexDescriptor = STLRMorph.mtlVertexDescriptor
        pipelineDescriptor.colorAttachments[0].pixelFormat = STLRRenderer.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        do {
            pipelineState = try STLRRenderer.metalDevice.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch let error {
            fatalError(error.localizedDescription)
        }
        return pipelineState
    }
    
    public func updateBuffer(instance: Int, transform: Transform, textureID: Int, morphtargetID: Int) {
        guard textureID < textureCount && morphtargetID < morphTargetCount else {
            fatalError("ID is too high")
        }
        var pointer = instanceBuffer.contents().bindMemory(to: MorphInstance.self, capacity: instanceCount)
        pointer = pointer.advanced(by: instance)
        pointer.pointee.modelMatrix = transform.modelMatrix
        pointer.pointee.normalMatrix = transform.normalMatrix
        pointer.pointee.textureID = UInt32(textureID)
        pointer.pointee.morphTargetID = UInt32(morphtargetID)
    }
    
}

extension STLRMorph: Texturable {}

extension STLRMorph: Renderable {
    
    public func doRender(commandEncoder: MTLRenderCommandEncoder, uniforms: STLRUniforms, fragmentUniforms: STLRFragmentUniforms) {
        guard let submesh = submesh else { return }
        var uniforms = uniforms
        var fragmentUniforms = fragmentUniforms
        uniforms.modelMatrix = worldTransform
        uniforms.normalMatrix = float3x3(normalFrom4x4: modelMatrix)
        
        commandEncoder.setRenderPipelineState(pipelineState)
        
        commandEncoder.setVertexBytes(&uniforms,
                                     length: MemoryLayout<STLRUniforms>.stride,
                                     index: Int(BufferIndexUniforms.rawValue))
        commandEncoder.setVertexBuffer(instanceBuffer, offset: 0,
                                      index: Int(BufferIndexInstances.rawValue))
        
        // set vertex buffer
        commandEncoder.setVertexBytes(&vertexCount,
                                     length: MemoryLayout<Int>.stride,
                                     index: 1)
        commandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        commandEncoder.setFragmentBytes(&fragmentUniforms,
                                       length: MemoryLayout<STLRFragmentUniforms>.stride,
                                       index: Int(BufferIndexFragmentUniforms.rawValue))
        commandEncoder.setFragmentTexture(baseColorTexture, index: Int(BaseColorTexture.rawValue))
        commandEncoder.drawIndexedPrimitives(type: .triangle,
                                            indexCount: submesh.indexCount,
                                            indexType: submesh.indexType,
                                            indexBuffer: submesh.indexBuffer.buffer,
                                            indexBufferOffset: submesh.indexBuffer.offset,
                                            instanceCount:  instanceCount)
    }
    
    
}
