//
//  ShapeRenderer.swift
//  ObsidianEngine
//
//  Created by Gellert on 6/8/18.
//  Copyright © 2018 Gellert. All rights reserved.
//

import Foundation
import Metal
import MetalKit

open class STLRRenderer: NSObject {
    
    static var metalDevice: MTLDevice!
    static var library: MTLLibrary!
    static var colorPixelFormat: MTLPixelFormat!
    static var commandQueue: MTLCommandQueue!
    static var commandBuffer: MTLCommandBuffer?
    static var drawableSize: CGSize!
    
    var renderPassDescriptor: MTLRenderPassDescriptor!
    
    var metalLayer: CAMetalLayer!
    var depthStencilState: MTLDepthStencilState!
    
    var shadowTexture: MTLTexture!
    let shadowRenderPassDescriptor = MTLRenderPassDescriptor()
    var shadowPipelineState: MTLRenderPipelineState!
    
    var albedoTexture: MTLTexture!
    var normalTexture: MTLTexture!
    var positionTexture: MTLTexture!
    var depthTexture: MTLTexture!
    
    var gBufferPipelineState: MTLRenderPipelineState!
    var gBufferRenderPassDescriptor: MTLRenderPassDescriptor!
    //var gBufferRenderPipelineDescriptor: MTLRenderPipelineDescriptor!
    
    var compositionPipelineState: MTLRenderPipelineState!
    
    //var reflectionRenderPass: RenderPass
    
    var quadVerticesBuffer: MTLBuffer!
    var quadTexCoordBuffer: MTLBuffer!
    
    let quadVertices: [Float] = [
        -1.0,  1.0,
         1.0, -1.0,
        -1.0, -1.0,
        -1.0,  1.0,
         1.0,  1.0,
         1.0, -1.0
    ]
    
    let quadTexCoords: [Float] = [
        0.0, 0.0,
        1.0, 1.0,
        0.0, 1.0,
        0.0, 0.0,
        1.0, 0.0,
        1.0, 1.0
    ]
    
    var samplerState: MTLSamplerState?
    
    var scene: STLRScene?
    
    public init(metalView: MTKView) {
        metalView.device = MTLCreateSystemDefaultDevice()
        guard let device = metalView.device else {
            fatalError("Device not created. Run on a physical device")
        }
        STLRLog.CORE_INFO("Renderer Device: \(device.name)")
        STLRRenderer.commandQueue = device.makeCommandQueue()
        STLRRenderer.metalDevice = device
        STLRRenderer.colorPixelFormat = metalView.colorPixelFormat
        STLRRenderer.drawableSize = metalView.drawableSize
        
        super.init()
        
        metalView.depthStencilPixelFormat = .depth32Float
        metalView.delegate = self
        
        mtkView(metalView, drawableSizeWillChange: metalView.bounds.size)
        metalView.framebufferOnly = false
        
        let frameworkBundle = Bundle(for: STLRShape.self)
        guard let defaultLibrary = try? device.makeDefaultLibrary(bundle: frameworkBundle) else {
            fatalError("Could not load default library from specified bundle")
        }
        STLRRenderer.library = defaultLibrary
                
        renderPassDescriptor = MTLRenderPassDescriptor()
        
        buildDepthStencilState()
        buildShadowTexture(size: metalView.drawableSize)
        buildShadowPipelineState()
        
        buildGBufferRenderPassDescriptor(size: metalView.drawableSize)
        buildGbufferPipelineState(withFragmentFunctionName: "fragment_PBR")
        
        quadVerticesBuffer = STLRRenderer.metalDevice.makeBuffer(bytes: quadVertices, length: MemoryLayout<Float>.size * quadVertices.count, options: [])
        quadVerticesBuffer.label = "Quad vertices"
        
        quadTexCoordBuffer = STLRRenderer.metalDevice.makeBuffer(bytes: quadTexCoords, length: MemoryLayout<Float>.size * quadTexCoords.count, options: [])
        quadTexCoordBuffer.label = "Quad texCoords"
        
        buildCompositionPipelineState()
    }
    
    fileprivate func buildDepthStencilState() {
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .less
        depthStencilDescriptor.isDepthWriteEnabled = true
        depthStencilState = STLRRenderer.metalDevice.makeDepthStencilState(descriptor: depthStencilDescriptor)
    }
    
    func buildTexture(pixelFormat: MTLPixelFormat, size: CGSize, label: String) -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat, width: Int(size.width), height: Int(size.height), mipmapped: false)
        descriptor.usage = [.shaderRead, .renderTarget]
        descriptor.storageMode = .private
        guard let texture = STLRRenderer.metalDevice.makeTexture(descriptor: descriptor) else {
            fatalError()
        }
        texture.label = "\(label) texture"
        return texture
    }
    
    func buildShadowTexture(size: CGSize) {
        shadowTexture = buildTexture(pixelFormat: .depth32Float, size: size, label: "Shadow")
        shadowRenderPassDescriptor.setUpDepthAttachment(texture: shadowTexture)
    }
    
    func buildShadowPipelineState() {
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = STLRRenderer.library.makeFunction(name: "vertex_depth")
        pipelineDescriptor.colorAttachments[0].pixelFormat = .invalid
        pipelineDescriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(STLRModel.defaultVertexDescriptor)
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        do {
            shadowPipelineState = try STLRRenderer.metalDevice.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    func buildGbufferTextures(size: CGSize) {
        albedoTexture = buildTexture(pixelFormat: .bgra8Unorm, size: size, label: "Albedo")
        normalTexture = buildTexture(pixelFormat: .rgba16Float, size: size, label: "Normal")
        positionTexture = buildTexture(pixelFormat: .rgba16Float, size: size, label: "Position")
        depthTexture = buildTexture(pixelFormat: .depth32Float, size: size, label: "Depth")
    }
    
    func buildGBufferRenderPassDescriptor(size: CGSize) {
        gBufferRenderPassDescriptor = MTLRenderPassDescriptor()
        buildGbufferTextures(size: size)
        let textures: [MTLTexture] = [albedoTexture, normalTexture, positionTexture]
        for (index, texture) in textures.enumerated() {
            gBufferRenderPassDescriptor.setUpColorAttachment(position: index, texture: texture)
        }

        gBufferRenderPassDescriptor.setUpDepthAttachment(texture: depthTexture)
    }
    
    func buildGbufferPipelineState(withFragmentFunctionName name: String) {
        let descriptor = MTLRenderPipelineDescriptor()
        //descriptor.colorAttachments[0].pixelFormat = STLRRenderer.colorPixelFormat
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        descriptor.colorAttachments[1].pixelFormat = .rgba16Float
        descriptor.colorAttachments[2].pixelFormat = .rgba16Float
        descriptor.depthAttachmentPixelFormat = .depth32Float
        descriptor.label = "GBuffer state"
        descriptor.vertexFunction = STLRRenderer.library.makeFunction(name: "vertex_main")
        if (name == "fragment_PBR") {
            descriptor.fragmentFunction = STLRRenderer.library.makeFunction(name: "gBufferFragment")
        } else {
            descriptor.fragmentFunction = STLRRenderer.library.makeFunction(name: "gBufferFragment_IBL")
        }
        descriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(STLRModel.defaultVertexDescriptor)
        //let a = STLRModel.defaultVertexDescriptor.attributes[3] as! MDLVertexAttribute
        do {
            gBufferPipelineState = try STLRRenderer.metalDevice.makeRenderPipelineState(descriptor: descriptor)
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }
    
    func renderShadowPass(renderEncoder: MTLRenderCommandEncoder) {
        guard let scene = scene else { return }
        
        renderEncoder.pushDebugGroup("Shadow pass")
        renderEncoder.label = "Shadow encoder"
        renderEncoder.setCullMode(.none)
        renderEncoder.setDepthStencilState(depthStencilState)
        renderEncoder.setDepthBias(0.01, slopeScale: 1.0, clamp: 0.01)
        scene.uniforms.projectionMatrix = float4x4(orthoLeft: -15, right: 15, bottom: -15, top: 15, near: 0.1, far: 30)
        let position: simd_float3 = [-scene.sunLignt.position.x, -scene.sunLignt.position.y, -scene.sunLignt.position.z]
        let center: simd_float3 = [0, 0, 0]
        let lookAt = float4x4(eye: position, center: center, up: [0, 1, 0])
        scene.uniforms.viewMatrix = float4x4(translation: [0, 0, 7]) * lookAt
        scene.uniforms.shadowMatrix = scene.uniforms.projectionMatrix * scene.uniforms.viewMatrix
        
        renderEncoder.setRenderPipelineState(shadowPipelineState)
        for child in scene.renderables {
            if let renderable = child as? STLRModel {
                draw(renderEncoder: renderEncoder, model: renderable)
            }
        }
        renderEncoder.endEncoding()
        renderEncoder.popDebugGroup()
    }
    
    func renderGbufferPass(renderEncoder: MTLRenderCommandEncoder) {
        guard let scene = scene else { return }
        
        renderEncoder.pushDebugGroup("Gbuffer pass")
        renderEncoder.label = "Gbuffer encoder"
        
        renderEncoder.setRenderPipelineState(gBufferPipelineState)
        renderEncoder.setDepthStencilState(depthStencilState)
        
        let lights = scene.lights
        let lightsBuffer = STLRRenderer.metalDevice.makeBuffer(bytes: lights, length: MemoryLayout<Light>.stride * lights.count, options: [])
        renderEncoder.setFragmentBuffer(lightsBuffer, offset: 0, index: 2)
        
        renderEncoder.setFragmentTexture(shadowTexture, index: 5)
        renderEncoder.setFragmentBytes(&scene.fragmentUniforms, length: MemoryLayout<STLRFragmentUniforms>.stride, index: 15)
        
        for child in scene.renderables {
            if let renderable = child as? STLRModel {
                //renderable.doRender(commandEncoder: renderEncoder, uniforms: scene.uniforms, fragmentUniforms: scene.fragmentUniforms)
                draw(renderEncoder: renderEncoder, model: renderable)
            }
        }
    }
    
    func renderCompositionPass(renderEncoder: MTLRenderCommandEncoder) {
        renderEncoder.pushDebugGroup("Composition Pass")
        renderEncoder.label = "Composition encoder"
        
        renderEncoder.setRenderPipelineState(compositionPipelineState)
        renderEncoder.setDepthStencilState(depthStencilState)
        renderEncoder.setVertexBuffer(quadVerticesBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(quadTexCoordBuffer, offset: 0, index: 1)
        
        renderEncoder.setFragmentTexture(albedoTexture, index: 0)
        renderEncoder.setFragmentTexture(normalTexture, index: 1)
        renderEncoder.setFragmentTexture(positionTexture, index: 2)
        
        guard let scene = scene else { return }
        
        let lights = scene.lights
        let lightsBuffer = STLRRenderer.metalDevice.makeBuffer(bytes: lights, length: MemoryLayout<Light>.stride * lights.count, options: [])
        renderEncoder.setFragmentBuffer(lightsBuffer, offset: 0, index: 2)
        renderEncoder.setFragmentBytes(&scene.fragmentUniforms, length: MemoryLayout<STLRFragmentUniforms>.stride, index: 15)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: quadVertices.count)
        
        renderEncoder.endEncoding()
        renderEncoder.popDebugGroup()
    }
    
    func buildCompositionPipelineState() {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.colorAttachments[0].pixelFormat = STLRRenderer.colorPixelFormat
        //descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        descriptor.depthAttachmentPixelFormat = .depth32Float
        //descriptor.sampleCount = 4
        descriptor.label = "Composition state"
        descriptor.vertexFunction = STLRRenderer.library.makeFunction(name: "composition_vert")
        descriptor.fragmentFunction = STLRRenderer.library.makeFunction(name: "composition_frag")
        
        do {
            compositionPipelineState = try STLRRenderer.metalDevice.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            fatalError(error.localizedDescription)
        }
    }
}

private extension MTLRenderPassDescriptor {
    func setUpDepthAttachment(texture: MTLTexture) {
        depthAttachment.texture = texture
        depthAttachment.loadAction = .clear
        depthAttachment.storeAction = .store
        depthAttachment.clearDepth = 1
    }
    
    func setUpColorAttachment(position: Int, texture: MTLTexture) {
        colorAttachments[position].texture = texture
        colorAttachments[position].loadAction = .clear
        colorAttachments[position].storeAction = .store
        colorAttachments[position].clearColor = MTLClearColorMake(0.66, 0.9, 0.96, 1)
    }
}

extension STLRRenderer: MTKViewDelegate {
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        guard let scene = scene else {return}
        scene.sceneSizeWillChange(to: size)
        buildShadowTexture(size: size)
        buildGBufferRenderPassDescriptor(size: size)
        for water in scene.waters {
            water.reflectionRenderPass.updateTextures(size: size)
        }
    }
    
    public func draw(in view: MTKView) {
        guard let descriptor = view.currentRenderPassDescriptor else {return}
        STLRRenderer.commandBuffer = STLRRenderer.commandQueue.makeCommandBuffer()
        guard let scene = scene else { return }
        
        STLRRenderer.commandBuffer?.addCompletedHandler({ buffer in
            let deltaTime = buffer.gpuEndTime - buffer.gpuStartTime
            scene.fps = Int(1 / deltaTime)
            scene.update(deltaTime: 1 / Float(view.preferredFramesPerSecond))
        })
        
        // shadow pass
        guard let shadowEncoder = STLRRenderer.commandBuffer?.makeRenderCommandEncoder(descriptor: shadowRenderPassDescriptor) else { return }
        renderShadowPass(renderEncoder: shadowEncoder)
        
        for water in scene.waters {
            guard let reflectEncoder = STLRRenderer.commandBuffer?.makeRenderCommandEncoder(descriptor: water.reflectionRenderPass.descriptor)
                else { return }

            scene.fragmentUniforms.cameraPosition = scene.camera.transform.position
            scene.fragmentUniforms.lightCount = uint(scene.lights.count)
            scene.uniforms.projectionMatrix = scene.camera.projectionMatrix
            scene.uniforms.cameraPosition = scene.camera.transform.position

            // Render reflection
            reflectEncoder.setDepthStencilState(depthStencilState)
            scene.reflectionCamera.transform = scene.camera.transform
            scene.reflectionCamera.transform.position.y = -scene.camera.transform.position.y
            scene.reflectionCamera.transform.rotation.x = -scene.camera.transform.rotation.x
            if let reflectionCam = scene.reflectionCamera as? STLRArcballCamera, let cam = scene.camera as? STLRArcballCamera {
                reflectionCam.distance = cam.distance
                scene.reflectionCamera = reflectionCam
                scene.uniforms.viewMatrix = reflectionCam.updateViewMatrix()
            }
            if let reflectionCam = scene.reflectionCamera as? STLRCamera {
                scene.uniforms.viewMatrix = reflectionCam.viewMatrix
            }
            scene.uniforms.clipPlane = float4(0, 1, 0, 0.1)

            scene.skybox?.update(renderEncoder: reflectEncoder)
            renderGbufferPass(renderEncoder: reflectEncoder)

            scene.skybox?.render(renderEncoder: reflectEncoder, uniforms: scene.uniforms)

            reflectEncoder.endEncoding()
            reflectEncoder.popDebugGroup()
        }
        
        scene.fragmentUniforms.cameraPosition = scene.camera.transform.position
        scene.fragmentUniforms.lightCount = uint(scene.lights.count)

        scene.uniforms.viewMatrix = scene.camera.viewMatrix
        scene.uniforms.projectionMatrix = scene.camera.projectionMatrix
        scene.uniforms.cameraPosition = scene.camera.transform.position
        scene.uniforms.clipPlane = float4(0, -1, 0, 1000)
        
        // gbuffer pass
        guard let gBufferEncoder = STLRRenderer.commandBuffer?.makeRenderCommandEncoder(descriptor: gBufferRenderPassDescriptor) else {return}
        
        scene.skybox?.update(renderEncoder: gBufferEncoder)
        renderGbufferPass(renderEncoder: gBufferEncoder)
        scene.skybox?.render(renderEncoder: gBufferEncoder, uniforms: scene.uniforms)
        for water in scene.waters {
            water.update()
            water.render(renderEncoder: gBufferEncoder, uniforms: scene.uniforms, fragmentUniform: scene.fragmentUniforms)
        }
        
//        for terrain in scene.terrains {
//            terrain.doRender(commandEncoder: gBufferEncoder, uniforms: scene.uniforms, fragmentUniforms: scene.fragmentUniforms)
//        }
        
        gBufferEncoder.endEncoding()
        gBufferEncoder.popDebugGroup()
        
        // composition pass
        guard let compositionEncoder = STLRRenderer.commandBuffer?.makeRenderCommandEncoder(descriptor: descriptor) else {return}
        renderCompositionPass(renderEncoder: compositionEncoder)
        
        guard let drawable = view.currentDrawable else {
            //STLRRenderer.commandBuffer?.commit()
            return
        }
        
        STLRRenderer.commandBuffer?.present(drawable)
        STLRRenderer.commandBuffer?.commit()
        //STLRRenderer.commandBuffer = nil
    }
    
    func draw(renderEncoder: MTLRenderCommandEncoder, model: STLRModel) {
        guard let scene = scene else { return }
        
        scene.uniforms.modelMatrix = model.worldTransform
        scene.uniforms.normalMatrix = float3x3(normalFrom4x4: model.modelMatrix)
        renderEncoder.setVertexBytes(&scene.uniforms, length: MemoryLayout<STLRUniforms>.stride, index: 11)
        renderEncoder.setVertexBuffer(model.mesh?.vertexBuffers[0].buffer, offset: 0, index: 0)
        renderEncoder.setFragmentSamplerState(model.samplerState, index: 0)
        guard let modelSubmeshes = model.submeshes else { return }
        
        for modelSubmesh in modelSubmeshes {
            let submesh = modelSubmesh.submesh
            var material = modelSubmesh.material
            renderEncoder.setFragmentTexture(modelSubmesh.textures.baseColor, index: 0)
            renderEncoder.setFragmentTexture(modelSubmesh.textures.normal, index: 1)
            renderEncoder.setFragmentTexture(modelSubmesh.textures.roughness, index: 2)
            renderEncoder.setFragmentTexture(modelSubmesh.textures.metallic, index: 3)
            renderEncoder.setFragmentTexture(modelSubmesh.textures.ao, index: 4)
            renderEncoder.setFragmentBytes(&material, length: MemoryLayout<Material>.stride, index: 13)
            renderEncoder.drawIndexedPrimitives(type: .triangle,
                                                indexCount: submesh.indexCount,
                                                indexType: submesh.indexType,
                                                indexBuffer: submesh.indexBuffer.buffer,
                                                indexBufferOffset: submesh.indexBuffer.offset)
        }
    }
    
}
