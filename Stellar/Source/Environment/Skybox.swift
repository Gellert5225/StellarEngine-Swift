//
//  Skybox.swift
//  ObsidianEngine
//
//  Created by Jiahe Li on 05/03/2019.
//  Copyright © 2019 Gellert. All rights reserved.
//

import MetalKit

open class STLRSkybox {
    var texture: MTLTexture?
    var diffuseTexture: MTLTexture?
    var brdfLut: MTLTexture?
    
    var transform = Transform()
    
    let mesh: MTKMesh
    let pipelineState: MTLRenderPipelineState
    let depthStencilState: MTLDepthStencilState?
    
    var renderPass: RenderPass?
    
    public struct SkySettings {
        var turbidity: Float = 0.5597
        var sunElevation: Float = 0.5164
        var upperAtmosphereScattering: Float = 0.1767
        var groundAlbedo: Float = 0.6885
    }
    
    open var skySettings = SkySettings(turbidity: 0.5597, sunElevation: 0.5164, upperAtmosphereScattering: 0.1767, groundAlbedo: 0.6885) {
        didSet {
            texture = loadGeneratedSkyboxTexture(dimensions: [1024, 1024])
            diffuseTexture = texture
        }
    }
    
    public static var SunRise = SkySettings(turbidity: 0.5597, sunElevation: 0.5164, upperAtmosphereScattering: 0.1767, groundAlbedo: 0.6885)
    public static var MidDay = SkySettings(turbidity: 0.7982, sunElevation: 0.7221, upperAtmosphereScattering: 0.6449, groundAlbedo: 0.0)
    public static var SunSet = SkySettings(turbidity: 0.6778, sunElevation: 0.4551, upperAtmosphereScattering: 0.0497, groundAlbedo: 0.0)
    
    public init(textureName: String?) {
        //renderPass = RenderPass(name: "skyBoxPass", size: STLRRenderer.drawableSize, sample: false)
        let allocator = MTKMeshBufferAllocator(device: STLRRenderer.metalDevice)
        let cube = MDLMesh(boxWithExtent: [1, 1, 1], segments: [1, 1, 1], inwardNormals: true, geometryType: .triangles, allocator: allocator)
        do {
            mesh = try MTKMesh(mesh: cube, device: STLRRenderer.metalDevice)
        } catch {
            fatalError("failed to create skybox mesh")
        }
        
        pipelineState = STLRSkybox.buildPipelineState(vertexDescriptor: cube.vertexDescriptor)
        depthStencilState = STLRSkybox.buildDepthStencilState()
        
        if let textureName = textureName {
            do {
                texture = try STLRSkybox.loadCubeTexture(imageName: textureName)
                diffuseTexture = try STLRSkybox.loadCubeTexture(imageName: "irradiance.png")
            } catch {
                fatalError(error.localizedDescription)
            }
        } else {
            texture = loadGeneratedSkyboxTexture(dimensions: [1024, 1024])
            diffuseTexture = texture
        }
        
        brdfLut = STLRRenderer.buildBRDF()
    }
    
    private static func buildPipelineState(vertexDescriptor: MDLVertexDescriptor) -> MTLRenderPipelineState {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        descriptor.colorAttachments[1].pixelFormat = .rgba16Float
        descriptor.colorAttachments[2].pixelFormat = .rgba16Float
        descriptor.depthAttachmentPixelFormat = .depth32Float
        descriptor.sampleCount = 4
        descriptor.vertexFunction = STLRRenderer.library.makeFunction(name: "vertexSkybox")
        descriptor.fragmentFunction = STLRRenderer.library.makeFunction(name: "fragmentSkybox")
        descriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(vertexDescriptor)
        
        do {
            return try STLRRenderer.metalDevice.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    private static func buildDepthStencilState() -> MTLDepthStencilState? {
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.depthCompareFunction = .lessEqual
        descriptor.isDepthWriteEnabled = true
        return STLRRenderer.metalDevice.makeDepthStencilState(descriptor: descriptor)
    }
    
    func render(renderEncoder: MTLRenderCommandEncoder, uniforms: STLRUniforms) {
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
        
        renderEncoder.setVertexBytes(&uniform, length: MemoryLayout<STLRUniforms>.stride, index: Int(BufferIndexUniforms.rawValue))
        
        let submesh = mesh.submeshes[0]
        renderEncoder.setFragmentTexture(texture, index: 20)
        renderEncoder.drawIndexedPrimitives(type: .triangle,
                                            indexCount: submesh.indexCount,
                                            indexType: submesh.indexType,
                                            indexBuffer: submesh.indexBuffer.buffer,
                                            indexBufferOffset: submesh.indexBuffer.offset)
        
        renderEncoder.popDebugGroup()
    }
    
    func loadGeneratedSkyboxTexture(dimensions: SIMD2<Int32>) -> MTLTexture? {
        var texture: MTLTexture?
        let skyTexture = MDLSkyCubeTexture(name: "sky",
                                           channelEncoding: .uInt8,
                                           textureDimensions: dimensions,
                                           turbidity: skySettings.turbidity,
                                           sunElevation: skySettings.sunElevation,
                                           upperAtmosphereScattering: skySettings.upperAtmosphereScattering,
                                           groundAlbedo: skySettings.groundAlbedo)
        do {
            let textureLoader = MTKTextureLoader(device: STLRRenderer.metalDevice)
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

extension STLRSkybox: Texturable {}
