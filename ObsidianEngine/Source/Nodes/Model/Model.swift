//
//  Model.swift
//  ObsidianEngine
//
//  Created by Gellert on 6/18/18.
//  Copyright © 2018 Gellert. All rights reserved.
//

import MetalKit
import ModelIO

open class OBSDModel: OBSDNode {
    
    static var defaultVertexDescriptor: MDLVertexDescriptor = {
        let descriptor = MTKModelIOVertexDescriptorFromMetal(vertexDescriptor)
        
        let attributePosition = descriptor.attributes[0] as! MDLVertexAttribute
        attributePosition.name = MDLVertexAttributePosition
        descriptor.attributes[0] = attributePosition
        
        let attributeNormal = descriptor.attributes[1] as! MDLVertexAttribute
        attributeNormal.name = MDLVertexAttributeNormal
        descriptor.attributes[1] = attributeNormal
        
        let attributeTexture = descriptor.attributes[2] as! MDLVertexAttribute
        attributeTexture.name = MDLVertexAttributeTextureCoordinate
        descriptor.attributes[2] = attributeTexture
        
        return descriptor
    }()
    
    private var transforms: [Transform]
    
    var texture: MTLTexture?
    var mesh: MTKMesh?
    var submeshes: [OBSDSubmesh]?
    var instanceBuffer: MTLBuffer
    
    open var tiling: UInt32 = 1
    open var fragmentFunctionName: String = "fragment_PBR"
    open var vertexFunctionName: String = "mp_vertex"
    
    let instanceCount: Int
    let samplerState: MTLSamplerState?
    var pipelineState: MTLRenderPipelineState!
    static var vertexDescriptor: MTLVertexDescriptor {
        let vertexDescriptor = MTLVertexDescriptor()
        
        vertexDescriptor.attributes[0].format = .float4
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        
        vertexDescriptor.attributes[1].format = .float3
        vertexDescriptor.attributes[1].offset = MemoryLayout<Float>.stride * 4
        vertexDescriptor.attributes[1].bufferIndex = 0
        
        vertexDescriptor.attributes[2].format = .float2
        vertexDescriptor.attributes[2].offset = MemoryLayout<Float>.stride * 7
        vertexDescriptor.attributes[2].bufferIndex = 0
        
        vertexDescriptor.attributes[3].format = .float3
        vertexDescriptor.attributes[3].offset = MemoryLayout<Float>.stride * 9
        vertexDescriptor.attributes[3].bufferIndex = 0
        
        vertexDescriptor.attributes[4].format = .float3
        vertexDescriptor.attributes[4].offset = MemoryLayout<Float>.stride * 12
        vertexDescriptor.attributes[4].bufferIndex = 0
        
        vertexDescriptor.layouts[0].stride = MemoryLayout<Float>.stride * 15
        return vertexDescriptor
    }
    
    public init(modelName: String, vertexFunctionName: String = "mp_vertex",
                fragmentFunctionName: String = "fragment_IBL", instanceCount: Int = 1) {
        self.instanceCount = instanceCount
        samplerState = OBSDModel.buildSamplerState()
        transforms = OBSDModel.buildTransforms(instanceCount: instanceCount)
        instanceBuffer = OBSDModel.buildInstanceBuffer(transforms: transforms)
        super.init()
        name = modelName
        loadModel(modelName: modelName, vertexFunctionName: vertexFunctionName, fragmentFunctionName: fragmentFunctionName)
        self.vertexFunctionName = vertexFunctionName
        self.fragmentFunctionName = fragmentFunctionName
        //pipelineState = buildPipelineState()
    }
    
    private static func buildSamplerState() -> MTLSamplerState? {
        let descriptor = MTLSamplerDescriptor()
        descriptor.sAddressMode = .repeat
        descriptor.tAddressMode = .repeat
        descriptor.mipFilter = .linear
        descriptor.magFilter = .linear
        descriptor.maxAnisotropy = 8
        
        let samplerState = OBSDRenderer.metalDevice.makeSamplerState(descriptor: descriptor)
        return samplerState
    }
    
    static func buildTransforms(instanceCount: Int) -> [Transform] {
        return [Transform](repeatElement(Transform(), count: instanceCount))
    }
    
    static func buildInstanceBuffer(transforms: [Transform]) -> MTLBuffer {
        let instances = transforms.map {
            Instances(modelMatrix: $0.modelMatrix, normalMatrix: float3x3(normalFrom4x4: $0.modelMatrix))
        }
        
        guard let instanceBuffer = OBSDRenderer.metalDevice.makeBuffer(bytes: instances, length: MemoryLayout<Instances>.stride * instances.count)
            else {
                fatalError("Failed to create instance buffer")
        }
        
        return instanceBuffer
    }
    
    open func updateBuffer(instance: Int, transform: Transform) {
        transforms[instance] = transform
        var pointer = instanceBuffer.contents().bindMemory(to: Instances.self, capacity: transforms.count)
        pointer = pointer.advanced(by: instance)
        pointer.pointee.modelMatrix = transforms[instance].modelMatrix
        pointer.pointee.normalMatrix = transforms[instance].normalMatrix
    }
    
    func loadModel(modelName: String, vertexFunctionName: String, fragmentFunctionName: String) {
        guard let assetURL = Bundle.main.url(forResource: modelName, withExtension: "obj") else {
            fatalError("Asset \(modelName) does not exist")
        }
        print("LOADED MODEL")
        let descriptor = MTKModelIOVertexDescriptorFromMetal(OBSDModel.vertexDescriptor)
        
        let attributePosition = descriptor.attributes[0] as! MDLVertexAttribute
        attributePosition.name = MDLVertexAttributePosition
        descriptor.attributes[0] = attributePosition
        
        let attributeNormal = descriptor.attributes[1] as! MDLVertexAttribute
        attributeNormal.name = MDLVertexAttributeNormal
        descriptor.attributes[1] = attributeNormal
        
        let attributeTexture = descriptor.attributes[2] as! MDLVertexAttribute
        attributeTexture.name = MDLVertexAttributeTextureCoordinate
        descriptor.attributes[2] = attributeTexture
        
        OBSDModel.defaultVertexDescriptor = descriptor
        
        let bufferAllocator = MTKMeshBufferAllocator(device: OBSDRenderer.metalDevice)
        let asset = MDLAsset(url: assetURL, vertexDescriptor: descriptor, bufferAllocator: bufferAllocator)
        let mdlMesh = asset.object(at: 0) as! MDLMesh
        
        do {
            mdlMesh.addTangentBasis(forTextureCoordinateAttributeNamed: MDLVertexAttributeTextureCoordinate, tangentAttributeNamed: MDLVertexAttributeTangent, bitangentAttributeNamed: MDLVertexAttributeBitangent)
            mesh = try MTKMesh(mesh: mdlMesh, device: OBSDRenderer.metalDevice)
            submeshes = mdlMesh.submeshes?.enumerated().compactMap {index, submesh in
                (submesh as? MDLSubmesh).map {
                    //print($0.material?.name ?? "unknown")
                    return OBSDSubmesh(submesh: (mesh?.submeshes[index])!,
                                       mdlSubmesh: $0, vertexFunctionName: vertexFunctionName, fragmentFunctionName: fragmentFunctionName)
                }
            }
            ?? []
        } catch {
            print("Mesh error: \(error.localizedDescription)")
        }
    }
    
}

extension OBSDModel: Renderable {
    
    func doRender(commandEncoder: MTLRenderCommandEncoder, uniforms: OBSDUniforms, fragmentUniforms: OBSDFragmentUniforms) {
        var fragConsts = fragmentUniforms
        fragConsts.tiling = tiling
        var vertexUniform = uniforms
        vertexUniform.modelMatrix = worldTransform
        vertexUniform.normalMatrix = float3x3(normalFrom4x4: modelMatrix)
        
        commandEncoder.setVertexBuffer(instanceBuffer, offset: 0, index: Int(BufferIndexInstances.rawValue))
        
        commandEncoder.setFragmentSamplerState(samplerState, index: 0)
        
        commandEncoder.setFragmentBytes(&fragConsts, length: MemoryLayout<OBSDFragmentUniforms>.stride, index: 15)
        commandEncoder.setVertexBytes(&vertexUniform, length: MemoryLayout<OBSDUniforms>.stride, index: 11)
        
        for (index, vertexBuffer) in (mesh?.vertexBuffers.enumerated())! {
            commandEncoder.setVertexBuffer(vertexBuffer.buffer, offset: 0, index: index)
        }
        
        for mesh in submeshes! {
            commandEncoder.setRenderPipelineState(mesh.pipelineState)
            
            commandEncoder.setFragmentTexture(mesh.textures.baseColor, index: 0)
            commandEncoder.setFragmentTexture(mesh.textures.normal, index: 1)
            commandEncoder.setFragmentTexture(mesh.textures.roughness, index: 2)
            commandEncoder.setFragmentTexture(mesh.textures.metallic, index: 3)
            commandEncoder.setFragmentTexture(mesh.textures.ao, index: 4)
            var material = mesh.material
            commandEncoder.setFragmentBytes(&material, length: MemoryLayout<Material>.stride, index: 13)

            commandEncoder.drawIndexedPrimitives(type: mesh.submesh.primitiveType,
                                                 indexCount: mesh.submesh.indexCount,
                                                 indexType: mesh.submesh.indexType,
                                                 indexBuffer: mesh.submesh.indexBuffer.buffer,
                                                 indexBufferOffset: mesh.submesh.indexBuffer.offset,
                                                 instanceCount: instanceCount)
        }
    }
    
}

extension OBSDModel: Texturable {}
