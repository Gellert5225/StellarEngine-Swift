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
    
    var uniformsBuffer: MTLBuffer!
    var fragmentUniformsBuffer: MTLBuffer!
    var modelParamsBuffer: MTLBuffer!
    var materialBuffer: MTLBuffer!
    var icb: MTLIndirectCommandBuffer!
        
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
        
    var quadVerticesBuffer: MTLBuffer!
    var quadTexCoordBuffer: MTLBuffer!
    
    var gbufferFragmentFunction: MTLFunction!
    var gbufferFragmentArgumentBuffer: MTLBuffer!
    var gbufferArgumentEncoder: MTLArgumentEncoder!
    
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
        
        gbufferFragmentFunction = STLRRenderer.library.makeFunction(name: "gBufferFragment")
        gbufferArgumentEncoder = gbufferFragmentFunction.makeArgumentEncoder(bufferIndex: Int(Shadow.rawValue))
        gbufferFragmentArgumentBuffer = STLRRenderer.metalDevice.makeBuffer(length: gbufferArgumentEncoder.encodedLength, options: [])
                
        renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.setUpColorAttachment(position: 0, texture: RenderPass.buildTexture(size: metalView.drawableSize, multiplier: 1.0, label: "drawable", pixelFormat: .bgra8Unorm, sample: true), resolveTexture: RenderPass.buildTexture(size: metalView.drawableSize, multiplier: 1.0, label: "drawable", pixelFormat: .bgra8Unorm, sample: false))
//        renderPassDescriptor.setUpDepthAttachment(texture: RenderPass.buildTexture(size: metalView.drawableSize, multiplier: 1.0, label: "drawable", pixelFormat: .depth32Float, sample: true), resolveTexture: RenderPass.buildTexture(size: metalView.drawableSize, multiplier: 1.0, label: "drawable", pixelFormat: .depth32Float, sample: false))
        
        depthStencilState = buildDepthStencilState(depthWrite: true, compareFunction: .less)
        buildShadowTexture(size: self.metalView.drawableSize)
        buildShadowPipelineState()
        
        buildGbufferPipelineState(withFragmentFunctionName: "fragment_PBR")
        gBufferRenderPass = RenderPass(name: "G-Buffer Pass", size: self.metalView.frame.size, multiplier: 1.0)
        
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
        //pipelineDescriptor.supportIndirectCommandBuffers = true
        do {
            shadowPipelineState = try STLRRenderer.metalDevice.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    func buildGbufferPipelineState(withFragmentFunctionName name: String) {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        descriptor.colorAttachments[1].pixelFormat = .rgba16Float
        descriptor.colorAttachments[2].pixelFormat = .rgba16Float
        descriptor.sampleCount = 4
        descriptor.depthAttachmentPixelFormat = .depth32Float
        descriptor.label = "GBuffer state"
        descriptor.vertexFunction = STLRRenderer.library.makeFunction(name: "vertex_main")
        descriptor.fragmentFunction = gbufferFragmentFunction
        gbufferFragmentFunction = descriptor.fragmentFunction
        descriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(STLRModel.defaultVertexDescriptor)
        //let a = STLRModel.defaultVertexDescriptor.attributes[3] as! MDLVertexAttribute
        descriptor.supportIndirectCommandBuffers = true
        do {
            gBufferPipelineState = try STLRRenderer.metalDevice.makeRenderPipelineState(descriptor: descriptor)
        } catch let error {
            fatalError("Failed to create pipeline state. Reason: \(error.localizedDescription)")
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
        
        if let heap = STLRTextureController.heap {
            renderEncoder.useHeap(heap)
        }
        
        gbufferArgumentEncoder.setArgumentBuffer(gbufferFragmentArgumentBuffer, offset: 0)
        gbufferFragmentArgumentBuffer.label = "Shadow Texture Buffer"
        gbufferArgumentEncoder.setTexture(shadowTexture, index: 0)
        //initializeCommands()
        renderEncoder.useResource(lightsBuffer!, usage: .read)
        if let skybox = scene.skybox {
            renderEncoder.useResource(skybox.textureBuffer, usage: .read)
        }
        
        for child in scene.renderables {
            if let renderable = child as? STLRModel {
                updateUniforms()
                renderEncoder.useResource((renderable.mesh?.vertexBuffers[0].buffer)!, usage: .read)
                guard let modelSubmesh = renderable.submeshes else { return }
                renderEncoder.useResource(uniformsBuffer, usage: .read)
                renderEncoder.useResource(fragmentUniformsBuffer, usage: .read)
                renderEncoder.useResource(modelParamsBuffer, usage: .read)
                renderEncoder.useResource(gbufferFragmentArgumentBuffer!, usage: .sample)
                for submesh in modelSubmesh {
                    renderEncoder.useResource(submesh.submesh.indexBuffer.buffer, usage: .read)
                    renderEncoder.useResource(submesh.materialBuffer!, usage: .sample)
                    renderEncoder.useResource(submesh.textureBuffer!, usage: .sample)
                }
            }
        }
        
        renderEncoder.executeCommandsInBuffer(icb, range: 0..<getSubmeshCount())
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
        renderEncoder.setFragmentBytes(&scene.fragmentUniforms, length: MemoryLayout<STLRFragmentUniforms>.stride, index: Int(BufferIndexFragmentUniforms.rawValue))
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
    
    func getSubmeshCount() -> Int {
        guard let scene = scene else { return 0 }
        var result = 0
        for renerable in scene.renderables {
            if let model = renerable as? STLRModel {
                for _ in model.submeshes! {
                    result += 1
                }
            }
        }
        return result
    }
    
    func initialize() {
        STLRTextureController.heap = STLRTextureController.buildHeap()
        scene?.renderables.forEach { renderable in
            if let model = renderable as? STLRModel {
                model.submeshes!.forEach { submesh in
                    submesh.initializeTextures()
                }
            }
        }
        
        var bufferLength = MemoryLayout<STLRUniforms>.stride
        uniformsBuffer = STLRRenderer.metalDevice.makeBuffer(length: bufferLength, options: [])
        uniformsBuffer.label = "STLRUniforms"
        
//        bufferLength = MemoryLayout<Material>.stride
//        materialBuffer = STLRRenderer.metalDevice.makeBuffer(length: bufferLength, options: [])
//        materialBuffer.label = "STLRMaterial"
        
        bufferLength = MemoryLayout<STLRFragmentUniforms>.stride
        fragmentUniformsBuffer = STLRRenderer.metalDevice.makeBuffer(length: bufferLength, options: [])
        fragmentUniformsBuffer.label = "STLRFragmentUniforms"
        
        bufferLength = (scene?.renderables.count)! * MemoryLayout<STLRModelParams>.stride
        modelParamsBuffer = STLRRenderer.metalDevice.makeBuffer(length: bufferLength, options: [])
        modelParamsBuffer.label = "Model Parameters"
    }
    
    func initializeCommands() {
        guard let scene = scene else { return }
        let icbDescriptor = MTLIndirectCommandBufferDescriptor()
        icbDescriptor.commandTypes = [.drawIndexed]
        icbDescriptor.inheritBuffers = false
        icbDescriptor.maxVertexBufferBindCount = 25
        icbDescriptor.maxFragmentBufferBindCount = 25
        icbDescriptor.inheritPipelineState = false
        
        guard let icb = STLRRenderer.metalDevice.makeIndirectCommandBuffer(descriptor: icbDescriptor, maxCommandCount: getSubmeshCount(), options: [])
        else { fatalError("Failed to create ICB") }
        
        self.icb = icb
        
        let lights = scene.lights
        let lightsBuffer = STLRRenderer.metalDevice.makeBuffer(bytes: lights, length: MemoryLayout<Light>.stride * lights.count, options: [])
        
        var currentIndex = 0
        for (modelIndex, renderable) in scene.renderables.enumerated() {
            if let model = renderable as? STLRModel {
                guard let modelSubmeshes = model.submeshes else { return }
                for (_, submesh) in modelSubmeshes.enumerated() {
                    updateUniforms()
                    let icbCommand = icb.indirectRenderCommandAt(currentIndex)
                    icbCommand.setRenderPipelineState(gBufferPipelineState)
                    icbCommand.setVertexBuffer(uniformsBuffer, offset: 0, at: Int(BufferIndexUniforms.rawValue))
                    icbCommand.setVertexBuffer(modelParamsBuffer, offset: 0, at: Int(BufferIndexModelParams.rawValue))
                    icbCommand.setVertexBuffer(model.mesh!.vertexBuffers[0].buffer, offset: 0, at: Int(BufferIndexVertices.rawValue))
                    icbCommand.setFragmentBuffer(fragmentUniformsBuffer, offset: 0, at: Int(BufferIndexFragmentUniforms.rawValue))
                    icbCommand.setFragmentBuffer(modelParamsBuffer, offset: 0, at: Int(BufferIndexModelParams.rawValue))
                    icbCommand.setFragmentBuffer(submesh.materialBuffer!, offset: 0, at: Int(BufferIndexMaterials.rawValue))
                    icbCommand.setFragmentBuffer(submesh.textureBuffer!, offset: 0, at: Int(STLRGBufferTexturesIndex.rawValue))
                    icbCommand.setFragmentBuffer(gbufferFragmentArgumentBuffer!, offset: 0, at: Int(Shadow.rawValue))
                    icbCommand.setFragmentBuffer(lightsBuffer!, offset: 0, at: 2)
                    icbCommand.setFragmentBuffer(scene.skybox!.textureBuffer, offset: 0, at: Int(BufferIndexSkyboxTextures.rawValue))
                    icbCommand.drawIndexedPrimitives(.triangle,
                                                     indexCount: submesh.submesh.indexCount,
                                                     indexType: submesh.submesh.indexType,
                                                     indexBuffer: submesh.submesh.indexBuffer.buffer,
                                                     indexBufferOffset: submesh.submesh.indexBuffer.offset,
                                                     instanceCount: 1,
                                                     baseVertex: 0,
                                                     baseInstance: modelIndex)
                    currentIndex += 1
                }
            }
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
        
        // reflection
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
//
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
    
    func updateUniforms() {
        guard let scene = scene else { return }
        
        var bufferLength = MemoryLayout<STLRUniforms>.stride
        uniformsBuffer.contents().copyMemory(from: &scene.uniforms, byteCount: bufferLength)
        
        bufferLength = MemoryLayout<STLRFragmentUniforms>.stride
        fragmentUniformsBuffer.contents().copyMemory(from: &scene.fragmentUniforms, byteCount: bufferLength)
        
        var pointer = modelParamsBuffer.contents().bindMemory(to: STLRModelParams.self, capacity: scene.renderables.count)
        
        for renderable in scene.renderables {
            if let model = renderable as? STLRModel {
                pointer.pointee.modelMatrix = model.worldTransform
                pointer.pointee.tiling = model.tiling
                pointer = pointer.advanced(by: 1)
            }
        }
    }
    
    func draw(renderEncoder: MTLRenderCommandEncoder, model: STLRModel) {
        guard let scene = scene else { return }
                
        scene.uniforms.modelMatrix = model.worldTransform
        scene.uniforms.normalMatrix = float3x3(normalFrom4x4: model.modelMatrix)
        renderEncoder.setVertexBytes(&scene.uniforms, length: MemoryLayout<STLRUniforms>.stride, index: 11)
        renderEncoder.setVertexBuffer(model.mesh?.vertexBuffers[0].buffer, offset: 0, index: 0)
        guard let modelSubmeshes = model.submeshes else { return }
        
        for modelSubmesh in modelSubmeshes {
            let submesh = modelSubmesh.submesh

            renderEncoder.drawIndexedPrimitives(type: .triangle,
                                                indexCount: submesh.indexCount,
                                                indexType: submesh.indexType,
                                                indexBuffer: submesh.indexBuffer.buffer,
                                                indexBufferOffset: submesh.indexBuffer.offset)
        }
        
    }
    
}
