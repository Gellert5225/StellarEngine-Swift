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
    
    var scene: STLRScene?
    
    var depthStencilState: MTLDepthStencilState!
    
    var shadowPipelineState: MTLRenderPipelineState!
    var shadowRenderPass: RenderPass!
    
    var gBufferPipelineState: MTLRenderPipelineState!
    var gBufferRenderPass: GBufferRenderPass!
    
    var compositionPipelineState: MTLRenderPipelineState!
        
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
        
        initialize()
        depthStencilState = buildDepthStencilState(depthWrite: true, compareFunction: .less)
        shadowRenderPass = RenderPass(name: "Shadow Pass", size: metalView.frame.size, multiplier: 2.0)
        buildShadowPipelineState()
        
        gBufferRenderPass = GBufferRenderPass(name: "G-Buffer Pass", size: metalView.frame.size, multiplier: 1.0)
        buildGbufferPipelineState(withFragmentFunctionName: "fragment_PBR")
        
        quadVerticesBuffer = STLRRenderer.metalDevice.makeBuffer(bytes: quadVertices, length: MemoryLayout<Float>.size * quadVertices.count, options: [])
        quadVerticesBuffer.label = "Quad vertices"
        
        quadTexCoordBuffer = STLRRenderer.metalDevice.makeBuffer(bytes: quadTexCoords, length: MemoryLayout<Float>.size * quadTexCoords.count, options: [])
        quadTexCoordBuffer.label = "Quad texCoords"
        
        buildCompositionPipelineState()
    }
    
    fileprivate func buildDepthStencilState(depthWrite: Bool, compareFunction: MTLCompareFunction) -> MTLDepthStencilState? {
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = compareFunction
        depthStencilDescriptor.isDepthWriteEnabled = depthWrite
        return STLRRenderer.metalDevice.makeDepthStencilState(descriptor: depthStencilDescriptor)
    }
    
    // MARK: Shadow Pass
    
    func buildShadowPipelineState() {
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = STLRRenderer.library.makeFunction(name: "vertex_depth")
        pipelineDescriptor.colorAttachments[0].pixelFormat = .invalid
        pipelineDescriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(STLRModel.defaultVertexDescriptor)
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        pipelineDescriptor.sampleCount = 4
        do {
            shadowPipelineState = try STLRRenderer.metalDevice.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
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
        
        // shadow matrix
        let position: simd_float3 = [scene.sunLignt.position.x, scene.sunLignt.position.y, scene.sunLignt.position.z]
        let center: simd_float3 = [0, 0, 0]
        let lookAt = float4x4(eye: position, center: center, up: [0, 1, 0])
        
        scene.uniforms.projectionMatrix = float4x4(orthoLeft: -15, right: 15, bottom: -15, top: 15, near: 0.1, far: 30)
        scene.uniforms.viewMatrix = lookAt
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
    
    // MARK: G-Buffer Pass
    
    func buildGbufferPipelineState(withFragmentFunctionName name: String) {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        descriptor.colorAttachments[1].pixelFormat = .rgba16Float
        descriptor.colorAttachments[2].pixelFormat = .rgba16Float
        descriptor.sampleCount = 4
        descriptor.depthAttachmentPixelFormat = .depth32Float
        descriptor.label = "GBuffer state"
        descriptor.vertexFunction = STLRRenderer.library.makeFunction(name: "vertex_main")
        if (name == "fragment_PBR") {
            descriptor.fragmentFunction = STLRRenderer.library.makeFunction(name: "gBufferFragment")
        } else {
            descriptor.fragmentFunction = STLRRenderer.library.makeFunction(name: "gBufferFragment_IBL")
        }
        descriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(STLRModel.defaultVertexDescriptor)
        do {
            gBufferPipelineState = try STLRRenderer.metalDevice.makeRenderPipelineState(descriptor: descriptor)
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }
    
    func renderGbufferPass(renderEncoder: MTLRenderCommandEncoder, label: String = "G-Buffer") {
        guard let scene = scene else { return }
        
        renderEncoder.pushDebugGroup("\(label) pass")
        renderEncoder.label = "\(label) encoder"
        
        renderEncoder.setRenderPipelineState(gBufferPipelineState)
        renderEncoder.setDepthStencilState(depthStencilState)
        
        let lights = scene.lights
        let lightsBuffer = STLRRenderer.metalDevice.makeBuffer(bytes: lights, length: MemoryLayout<STLRLight>.stride * lights.count, options: [])
        renderEncoder.setFragmentBuffer(lightsBuffer, offset: 0, index: 2)
        
        renderEncoder.setFragmentTexture(shadowRenderPass.depthTexture_resolve, index: Int(Shadow.rawValue))
        renderEncoder.setFragmentBytes(&scene.fragmentUniforms, length: MemoryLayout<STLRFragmentUniforms>.stride, index: 15)
        
        for child in scene.renderables {
            if let renderable = child as? STLRModel {
                draw(renderEncoder: renderEncoder, model: renderable)
            }
        }
    }
    
    // MARK: Composite Pass
    
    func buildCompositionPipelineState() {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.colorAttachments[0].pixelFormat = STLRRenderer.colorPixelFormat
        
        descriptor.depthAttachmentPixelFormat = .depth32Float
        descriptor.sampleCount = 4
        descriptor.label = "Composition state"
        descriptor.vertexFunction = STLRRenderer.library.makeFunction(name: "composition_vert")
        descriptor.fragmentFunction = STLRRenderer.library.makeFunction(name: "composition_frag")
        
        do {
            compositionPipelineState = try STLRRenderer.metalDevice.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    func renderCompositionPass(renderEncoder: MTLRenderCommandEncoder) {
        renderEncoder.pushDebugGroup("Composition Pass")
        renderEncoder.label = "Composition encoder"
        
        let depthStencilState = buildDepthStencilState(depthWrite: false, compareFunction: .always)
        
        renderEncoder.setRenderPipelineState(compositionPipelineState)
        renderEncoder.setDepthStencilState(depthStencilState)
        renderEncoder.setStencilReferenceValue(128)
        renderEncoder.setVertexBuffer(quadVerticesBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(quadTexCoordBuffer, offset: 0, index: 1)
        
        renderEncoder.setFragmentTexture(gBufferRenderPass.albedo_resolve, index: Int(Albedo.rawValue))
        renderEncoder.setFragmentTexture(gBufferRenderPass.normal_resolve, index: Int(Normal.rawValue))
        renderEncoder.setFragmentTexture(gBufferRenderPass.position_resolve, index: Int(Position.rawValue))
        
        guard let scene = scene else { return }
        
        let lights = scene.lights
        let lightsBuffer = STLRRenderer.metalDevice.makeBuffer(bytes: lights, length: MemoryLayout<STLRLight>.stride * lights.count, options: [])
        renderEncoder.setFragmentBuffer(lightsBuffer, offset: 0, index: 2)
        renderEncoder.setFragmentBytes(&scene.fragmentUniforms, length: MemoryLayout<STLRFragmentUniforms>.stride, index: 15)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: quadVertices.count)
        
        renderEncoder.endEncoding()
        renderEncoder.popDebugGroup()
    }
    
    // MARK: Initialize Textures
    
    func initialize() {
        STLRTextureController.heap = STLRTextureController.buildHeap()
        scene?.renderables.forEach { renderable in
            if let model = renderable as? STLRModel {
                model.submeshes!.forEach { submesh in
                    submesh.initializeTextures()
                }
            }
        }
    }
}

// MARK: MTKViewDelegate

extension STLRRenderer: MTKViewDelegate {
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        guard let scene = scene else {return}
        scene.sceneSizeWillChange(to: size)
//        buildShadowTexture(size: size)
        shadowRenderPass.updateTextures(size: size)
        gBufferRenderPass.updateTextures(size: size)
        for water in scene.waters {
            water.reflectionRenderPass.updateTextures(size: size)
        }
    }
        
    public func draw(in view: MTKView) {
        STLRRenderer.commandBuffer = STLRRenderer.commandQueue.makeCommandBuffer()
        guard let scene = scene else { return }
        
        STLRRenderer.commandBuffer?.addCompletedHandler({ buffer in
            DispatchQueue.main.async {
                let deltaTime = buffer.gpuEndTime - buffer.gpuStartTime
                scene.fps = Int(1 / deltaTime)
                scene.update(deltaTime: 1 / Float(view.preferredFramesPerSecond))
            }
        })
        
        // shadow pass
        guard let shadowEncoder = STLRRenderer.commandBuffer?.makeRenderCommandEncoder(descriptor: shadowRenderPass.descriptor!) else { return }
        renderShadowPass(renderEncoder: shadowEncoder)
        
        for water in scene.waters {
            guard let reflectEncoder = STLRRenderer.commandBuffer?.makeRenderCommandEncoder(descriptor: water.reflectionRenderPass.descriptor!)
                else { return }

            scene.fragmentUniforms.cameraPosition = scene.camera.transform.position
            scene.fragmentUniforms.lightCount = uint(scene.lights.count)
            scene.uniforms.projectionMatrix = scene.camera.projectionMatrix
            scene.uniforms.cameraPosition = scene.camera.transform.position

            // Render reflection
            //reflectEncoder.setDepthStencilState(depthStencilState)
            scene.reflectionCamera.transform = scene.camera.transform
            scene.reflectionCamera.transform.position.y = -scene.camera.transform.position.y
            scene.reflectionCamera.transform.rotation.x = -scene.camera.transform.rotation.x
            if let reflectionCam = scene.reflectionCamera as? STLRArcballCamera, let cam = scene.camera as? STLRArcballCamera {
                reflectionCam.distance = cam.distance
                scene.reflectionCamera = reflectionCam
                scene.uniforms.viewMatrix = reflectionCam.viewMatrix
            }

            scene.uniforms.clipPlane = float4(0, 1, 0, 0.1)

            scene.skybox?.update(renderEncoder: reflectEncoder)
            renderGbufferPass(renderEncoder: reflectEncoder, label: "Reflection")

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
        guard let gBufferEncoder = STLRRenderer.commandBuffer?.makeRenderCommandEncoder(descriptor: gBufferRenderPass.descriptor!) else {return}
        
        scene.skybox?.update(renderEncoder: gBufferEncoder)
        scene.skybox?.render(renderEncoder: gBufferEncoder, uniforms: scene.uniforms)
        for water in scene.waters {
            water.update()
            water.render(renderEncoder: gBufferEncoder, uniforms: scene.uniforms, fragmentUniform: scene.fragmentUniforms)
        }
        renderGbufferPass(renderEncoder: gBufferEncoder)
        
//        for terrain in scene.terrains {
//            terrain.doRender(commandEncoder: gBufferEncoder, uniforms: scene.uniforms, fragmentUniforms: scene.fragmentUniforms)
//        }
        
        gBufferEncoder.endEncoding()
        gBufferEncoder.popDebugGroup()
        
        guard let drawable = view.currentDrawable else {
            return
        }
        
        // composition pass
        guard let descriptor = view.currentRenderPassDescriptor else {return}
        guard let compositionEncoder = STLRRenderer.commandBuffer?.makeRenderCommandEncoder(descriptor: descriptor) else {return}
        renderCompositionPass(renderEncoder: compositionEncoder)
        
        STLRRenderer.commandBuffer?.present(drawable)
        STLRRenderer.commandBuffer?.commit()
        //STLRRenderer.commandBuffer = nil
    }
    
    /// draw the model with provided render encoder
    func draw(renderEncoder: MTLRenderCommandEncoder, model: STLRModel) {
        guard let scene = scene else { return }
        if let heap = STLRTextureController.heap {
            renderEncoder.useHeap(heap)
        }
        
        scene.uniforms.modelMatrix = model.worldTransform
        scene.uniforms.normalMatrix = float3x3(normalFrom4x4: model.modelMatrix)
        renderEncoder.setVertexBytes(&scene.uniforms, length: MemoryLayout<STLRUniforms>.stride, index: 11)
        renderEncoder.setVertexBuffer(model.mesh?.vertexBuffers[0].buffer, offset: 0, index: 0)
        renderEncoder.setFragmentSamplerState(model.samplerState, index: 0)
        guard let modelSubmeshes = model.submeshes else { return }
        
        for modelSubmesh in modelSubmeshes {
            let submesh = modelSubmesh.submesh
            var material = modelSubmesh.material

            renderEncoder.setFragmentBuffer(modelSubmesh.textureBuffer, offset: 0, index: Int(STLRGBufferTexturesIndex.rawValue))
            
            renderEncoder.setFragmentBytes(&material, length: MemoryLayout<STLRMaterial>.stride, index: 13)
            renderEncoder.drawIndexedPrimitives(type: .triangle,
                                                indexCount: submesh.indexCount,
                                                indexType: submesh.indexType,
                                                indexBuffer: submesh.indexBuffer.buffer,
                                                indexBufferOffset: submesh.indexBuffer.offset)
        }
    }
    
}
