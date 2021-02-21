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
        
    var metalView: MTKView!
    var renderPassDescriptor: MTLRenderPassDescriptor!
    
    var metalLayer: CAMetalLayer!
    var depthStencilState: MTLDepthStencilState!
    
    var shadowTexture: MTLTexture!
    var shadowTexture_AA: MTLTexture!
    let shadowRenderPassDescriptor = MTLRenderPassDescriptor()
    var shadowPipelineState: MTLRenderPipelineState!
    
    var albedoTexture: MTLTexture!
    var albedoTexture_AA: MTLTexture!
    var normalTexture: MTLTexture!
    var normalTexture_AA: MTLTexture!
    var positionTexture: MTLTexture!
    var positionTexture_AA: MTLTexture!
    var depthTexture: MTLTexture!
    var depthTexture_AA: MTLTexture!
    
    var gBufferPipelineState: MTLRenderPipelineState!
    var gBufferRenderPass: RenderPass!
    
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
        self.metalView = metalView
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
        renderPassDescriptor.setUpColorAttachment(position: 0, texture: RenderPass.buildTexture(size: metalView.drawableSize, multiplier: 1.0, label: "drawable", pixelFormat: .bgra8Unorm, sample: true), resolveTexture: RenderPass.buildTexture(size: metalView.drawableSize, multiplier: 1.0, label: "drawable", pixelFormat: .bgra8Unorm, sample: false))
//        renderPassDescriptor.setUpDepthAttachment(texture: RenderPass.buildTexture(size: metalView.drawableSize, multiplier: 1.0, label: "drawable", pixelFormat: .depth32Float, sample: true), resolveTexture: RenderPass.buildTexture(size: metalView.drawableSize, multiplier: 1.0, label: "drawable", pixelFormat: .depth32Float, sample: false))
        
        depthStencilState = buildDepthStencilState(depthWrite: true, compareFunction: .less)
        buildShadowTexture(size: self.metalView.drawableSize)
        buildShadowPipelineState()
        
        gBufferRenderPass = RenderPass(name: "G-Buffer Pass", size: self.metalView.frame.size, multiplier: 1.0)
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
    
    func buildResolveTexture(pixelFormat: MTLPixelFormat, size: CGSize) -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat, width: Int(size.width * 2), height: Int(size.height * 2), mipmapped: true)
        //descriptor.usage = [.shaderRead, .renderTarget]
        descriptor.storageMode = .private
        
        guard let texture = STLRRenderer.metalDevice.makeTexture(descriptor: descriptor) else {
            fatalError()
        }
        return texture
    }
    
    func buildTexture(pixelFormat: MTLPixelFormat, size: CGSize, label: String, antiAliased: Bool = false) -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat, width: Int(size.width * 2), height: Int(size.height * 2), mipmapped: false)
        descriptor.usage = [.shaderRead, .renderTarget]
        descriptor.storageMode = .private
        descriptor.textureType = .type2DMultisample
        descriptor.sampleCount = 4
        guard let texture = STLRRenderer.metalDevice.makeTexture(descriptor: descriptor) else {
            fatalError()
        }
        texture.label = "\(label) texture"
        return texture
    }
    
    func buildShadowTexture(size: CGSize) {
        shadowTexture = buildResolveTexture(pixelFormat: .depth32Float, size: size)
        shadowTexture_AA = buildTexture(pixelFormat: .depth32Float, size: size, label: "Shadow_AA", antiAliased: true)
        shadowRenderPassDescriptor.setUpDepthAttachment(texture: shadowTexture_AA, resolveTexture: shadowTexture)
    }
    
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
    
    func buildGbufferPipelineState(withFragmentFunctionName name: String) {
        let descriptor = MTLRenderPipelineDescriptor()
        //descriptor.colorAttachments[0].pixelFormat = STLRRenderer.colorPixelFormat
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
    
    func renderGbufferPass(renderEncoder: MTLRenderCommandEncoder, label: String = "G-Buffer") {
        guard let scene = scene else { return }
        
        renderEncoder.pushDebugGroup("\(label) pass")
        renderEncoder.label = "\(label) encoder"
        
        renderEncoder.setRenderPipelineState(gBufferPipelineState)
        renderEncoder.setDepthStencilState(depthStencilState)
        
        let lights = scene.lights
        let lightsBuffer = STLRRenderer.metalDevice.makeBuffer(bytes: lights, length: MemoryLayout<Light>.stride * lights.count, options: [])
        renderEncoder.setFragmentBuffer(lightsBuffer, offset: 0, index: 2)
        
        renderEncoder.setFragmentTexture(shadowTexture, index: Int(Shadow.rawValue))
        renderEncoder.setFragmentBytes(&scene.fragmentUniforms, length: MemoryLayout<STLRFragmentUniforms>.stride, index: 15)
        
        for child in scene.renderables {
            if let renderable = child as? STLRModel {
                draw(renderEncoder: renderEncoder, model: renderable)
            }
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
        
        renderEncoder.setFragmentTexture(gBufferRenderPass.texture_resolve, index: Int(Albedo.rawValue))
        renderEncoder.setFragmentTexture(gBufferRenderPass.normal_resolve, index: Int(Normal.rawValue))
        renderEncoder.setFragmentTexture(gBufferRenderPass.position_resolve, index: Int(Position.rawValue))
        
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
}

extension STLRRenderer: MTKViewDelegate {
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        self.metalView = view
        guard let scene = scene else {return}
        scene.sceneSizeWillChange(to: size)
        buildShadowTexture(size: size)
        gBufferRenderPass.updateTextures(size: size)
        //renderPassDescriptor.setUpColorAttachment(position: 0, texture: gBufferRenderPass.texture, resolveTexture: gBufferRenderPass.texture_resolve)
//        if let descriptor = view.currentRenderPassDescriptor, let drawable = view.currentDrawable {
//            descriptor.setUpColorAttachment(position: 0, texture: RenderPass.buildTexture(size: size, multiplier: 1.0, label: "drawable", pixelFormat: .bgra8Unorm, sample: true), resolveTexture: drawable.texture)
//            descriptor.setUpDepthAttachment(texture: RenderPass.buildTexture(size: size, multiplier: 1.0, label: "drawable", pixelFormat: .depth32Float, sample: true), resolveTexture: RenderPass.buildTexture(size: size, multiplier: 1.0, label: "drawable", pixelFormat: .depth32Float, sample: false))
//        }
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
        guard let gBufferEncoder = STLRRenderer.commandBuffer?.makeRenderCommandEncoder(descriptor: gBufferRenderPass.descriptor) else {return}
        
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
        
        // skybox pass
//        guard let mainEncoder = STLRRenderer.commandBuffer?.makeRenderCommandEncoder(descriptor: (scene.skybox?.renderPass.descriptor)!) else {return}
//        scene.skybox?.update(renderEncoder: mainEncoder)
//        scene.skybox?.render(renderEncoder: mainEncoder, uniforms: scene.uniforms)
//        mainEncoder.endEncoding()
//        mainEncoder.popDebugGroup()
        
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
//            renderEncoder.setFragmentTexture(modelSubmesh.textures.baseColor, index: Int(BaseColorTexture.rawValue))
//            renderEncoder.setFragmentTexture(modelSubmesh.textures.normal, index: Int(NormalTexture.rawValue))
//            renderEncoder.setFragmentTexture(modelSubmesh.textures.roughness, index: Int(RoughnessTexture.rawValue))
//            renderEncoder.setFragmentTexture(modelSubmesh.textures.metallic, index: Int(MetallicTexture.rawValue))
//            renderEncoder.setFragmentTexture(modelSubmesh.textures.ao, index: Int(AOTexture.rawValue))
            renderEncoder.setFragmentBuffer(modelSubmesh.textureBuffer, offset: 0, index: Int(STLRGBufferTexturesIndex.rawValue))
            if let colorTexture = modelSubmesh.textures.baseColor {
                renderEncoder.useResource(colorTexture, usage: .read)
            }
            if let normalTexture = modelSubmesh.textures.normal {
                renderEncoder.useResource(normalTexture, usage: .read)
            }
            if let roughnessTexture = modelSubmesh.textures.roughness {
                renderEncoder.useResource(roughnessTexture, usage: .read)
            }
            if let metallicTexture = modelSubmesh.textures.metallic {
                renderEncoder.useResource(metallicTexture, usage: .read)
            }
            if let aoTexture = modelSubmesh.textures.ao {
                renderEncoder.useResource(aoTexture, usage: .read)
            }
            renderEncoder.setFragmentBytes(&material, length: MemoryLayout<Material>.stride, index: 13)
            renderEncoder.drawIndexedPrimitives(type: .triangle,
                                                indexCount: submesh.indexCount,
                                                indexType: submesh.indexType,
                                                indexBuffer: submesh.indexBuffer.buffer,
                                                indexBufferOffset: submesh.indexBuffer.offset)
        }
    }
    
}
