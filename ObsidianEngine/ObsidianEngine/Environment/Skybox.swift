//
//  Skybox.swift
//  ObsidianEngine
//
//  Created by Jiahe Li on 05/03/2019.
//  Copyright © 2019 Gellert. All rights reserved.
//

import MetalKit

open class OBSDSkybox {
    var texture: MTLTexture?
    var diffuseTexture: MTLTexture?
    var brdfLut: MTLTexture?
    
    var transform = Transform()
    
    let mesh: MTKMesh
    let pipelineState: MTLRenderPipelineState
    let depthStencilState: MTLDepthStencilState?
    
    public struct SkySettings {
        var turbidity: Float = 0.17
        var sunElevation: Float = 0.64
        var upperAtmosphereScattering: Float = 0.48
        var groundAlbedo: Float = 1.35
    }
    
    open var skySettings = SkySettings()
    
    public init(textureName: String?) {
        let allocator = MTKMeshBufferAllocator(device: OBSDRenderer.metalDevice)
        let cube = MDLMesh(boxWithExtent: [1, 1, 1], segments: [1, 1, 1], inwardNormals: true, geometryType: .triangles, allocator: allocator)
        do {
            mesh = try MTKMesh(mesh: cube, device: OBSDRenderer.metalDevice)
        } catch {
            fatalError("failed to create skybox mesh")
        }
        
        pipelineState = OBSDSkybox.buildPipelineState(vertexDescriptor: cube.vertexDescriptor)
        depthStencilState = OBSDSkybox.buildDepthStencilState()
        
        if let textureName = textureName {
            do {
                texture = try OBSDSkybox.loadCubeTexture(imageName: textureName)
                diffuseTexture = try OBSDSkybox.loadCubeTexture(imageName: "irradiance.png")
            } catch {
                fatalError(error.localizedDescription)
            }
        } else {
            texture = loadGeneratedSkyboxTexture(dimensions: [256, 256])
            diffuseTexture = texture
        }
        
        brdfLut = OBSDRenderer.buildBRDF()
    }
    
    private static func buildPipelineState(vertexDescriptor: MDLVertexDescriptor) -> MTLRenderPipelineState {
        let descriptor = MTLRenderPipelineDescriptor()
        //descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        descriptor.colorAttachments[1].pixelFormat = .rgba16Float
        descriptor.colorAttachments[2].pixelFormat = .rgba16Float
        //descriptor.sampleCount = 4;
        descriptor.depthAttachmentPixelFormat = .depth32Float
        descriptor.vertexFunction = OBSDRenderer.library.makeFunction(name: "vertexSkybox")
        descriptor.fragmentFunction = OBSDRenderer.library.makeFunction(name: "fragmentSkybox")
        descriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(vertexDescriptor)
        
        do {
            return try OBSDRenderer.metalDevice.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    private static func buildDepthStencilState() -> MTLDepthStencilState? {
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.depthCompareFunction = .lessEqual
        descriptor.isDepthWriteEnabled = true
        return OBSDRenderer.metalDevice.makeDepthStencilState(descriptor: descriptor)
    }
    
    func render(renderEncoder: MTLRenderCommandEncoder, uniforms: OBSDUniforms) {
        renderEncoder.pushDebugGroup("Skybox pass")
        renderEncoder.label = "Skybox"
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setDepthStencilState(depthStencilState)
        //renderEncoder.setCullMode(.front)
        
//        for (index, vertexBuffer) in mesh.vertexBuffers.enumerated() {
//            renderEncoder.setVertexBuffer(vertexBuffer.buffer, offset: 0, index: index)
//        }
        
        renderEncoder.setVertexBuffer(mesh.vertexBuffers[0].buffer, offset: 0, index: 0)

        var uniform = uniforms
        var viewMatrix = uniforms.viewMatrix
        viewMatrix.columns.3 = [0, 0, 0, 1]
        uniform.viewMatrix = viewMatrix
        uniform.modelMatrix = transform.modelMatrix
        
        renderEncoder.setVertexBytes(&uniform, length: MemoryLayout<OBSDUniforms>.stride, index: Int(BufferIndexUniforms.rawValue))
        
        let submesh = mesh.submeshes[0]
        renderEncoder.setFragmentTexture(texture, index: 20)
        renderEncoder.drawIndexedPrimitives(type: .triangle,
                                            indexCount: submesh.indexCount,
                                            indexType: submesh.indexType,
                                            indexBuffer: submesh.indexBuffer.buffer,
                                            indexBufferOffset: submesh.indexBuffer.offset)
        
        renderEncoder.popDebugGroup()
    }
    
    func loadGeneratedSkyboxTexture(dimensions: int2) -> MTLTexture? {
        var texture: MTLTexture?
        let skyTexture = MDLSkyCubeTexture(name: "sky",
                                           channelEncoding: .uInt8,
                                           textureDimensions: dimensions,
                                           turbidity: skySettings.turbidity,
                                           sunElevation: skySettings.sunElevation,
                                           upperAtmosphereScattering: skySettings.upperAtmosphereScattering,
                                           groundAlbedo: skySettings.groundAlbedo)
        do {
            let textureLoader = MTKTextureLoader(device: OBSDRenderer.metalDevice)
            texture = try textureLoader.newTexture(texture: skyTexture,
                                                   options: nil)
        } catch {
            print(error.localizedDescription)
        }
        
        return texture
    }
    
    func update(renderEncoder: MTLRenderCommandEncoder) {
        renderEncoder.setFragmentTexture(texture,
                                         index: Int(BufferIndexSkybox.rawValue))
        renderEncoder.setFragmentTexture(diffuseTexture,
                                         index: Int(BufferIndexSkyboxDiffuse.rawValue))
        renderEncoder.setFragmentTexture(brdfLut,
                                         index: Int(BufferIndexBRDFLut.rawValue))
    }
}

extension OBSDSkybox: Texturable {}
