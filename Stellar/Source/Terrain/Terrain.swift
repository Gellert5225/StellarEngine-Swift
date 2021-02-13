//
//  Terrain.swift
//  ObsidianEngine
//
//  Created by Jiahe Li on 16/03/2019.
//  Copyright © 2019 Gellert. All rights reserved.
//

import MetalKit
import MetalPerformanceShaders

open class STLRTerrain: STLRNode {
    static let maxTessellation: Int = {
        #if os(macOS)
        return 64
        #else
        return 16
        #endif
    } ()
    
    // set up patch
    let patches = (horizontal: 7, vertical: 7)
    var patchCount: Int {
        return patches.horizontal * patches.vertical
    }
    
    // edge and inside factors
    var edgeFactors: [Float] = [4]
    var insideFactors: [Float] = [4]
    
    var controlPointsBuffer: MTLBuffer?
    
    lazy var tessellationFactorsBuffer: MTLBuffer? = {
        let count = patchCount * (4 + 2) // 4 edge factors and 2 inside factors
        let size = count * MemoryLayout<Float>.size / 2 // size of buffer, half-float
        return STLRRenderer.metalDevice.makeBuffer(length: size, options: .storageModePrivate)
    }()
    let tessellationPipelineState: MTLComputePipelineState
    let renderPipelineState: MTLRenderPipelineState
    
    // terrain textures
    let heightMap: MTLTexture?
    let cliffMap: MTLTexture?
    let snowMap: MTLTexture?
    let grassMap: MTLTexture?
    let terrainSlope: MTLTexture
    
    var tiling: Float = 32
    
    var terrainUniforms = STLRTerrainUniforms()
    
    public init(withSize size: simd_float2, heightScale: Float, heightTexture: String, cliffTexture: String, snowTexture: String, grassTexture: String) {
        
        do {
            heightMap = try STLRTerrain.loadTexture(imageName: heightTexture, bundle: Bundle.main)
            cliffMap = try STLRTerrain.loadTexture(imageName: cliffTexture, bundle: Bundle.main)
            snowMap = try STLRTerrain.loadTexture(imageName: snowTexture, bundle: Bundle.main)
            grassMap = try STLRTerrain.loadTexture(imageName: grassTexture, bundle: Bundle.main)
        } catch {
            fatalError(error.localizedDescription)
        }
        
        // fill the beffer with control points
        let controlPoints = STLRTerrain.createControlPoints(patches: patches, size: (width: size.x, height: size.y))
        controlPointsBuffer = STLRRenderer.metalDevice.makeBuffer(bytes: controlPoints, length: MemoryLayout<simd_float3>.stride * controlPoints.count)
        
        // compute pipeline state and render pipeline state
        tessellationPipelineState = STLRTerrain.buildComputePipelineState()
        renderPipelineState = STLRTerrain.buildRenderPipelineState()
        terrainSlope = STLRTerrain.heightToSlope(source: heightMap!)
        
        super.init()
        name = "Terrain"
        terrainUniforms.height = heightScale
        terrainUniforms.size = size
        terrainUniforms.maxTessellation = UInt32(STLRTerrain.maxTessellation)
    }
    
    static func buildRenderPipelineState() -> MTLRenderPipelineState {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        descriptor.depthAttachmentPixelFormat = .depth32Float
        //descriptor.sampleCount = 4
        
        let vertexFunction = STLRRenderer.library?.makeFunction(name: "terrain_vertex")
        let fragmentFunction = STLRRenderer.library?.makeFunction(name: "terrain_fragment")
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        
        vertexDescriptor.layouts[0].stepFunction = .perPatchControlPoint
        vertexDescriptor.layouts[0].stride = MemoryLayout<simd_float3>.stride
        descriptor.vertexDescriptor = vertexDescriptor
        
        descriptor.tessellationFactorStepFunction = .perPatch
        descriptor.maxTessellationFactor = STLRTerrain.maxTessellation
        descriptor.tessellationPartitionMode = .fractionalEven //pow2
        
        return try! STLRRenderer.metalDevice.makeRenderPipelineState(descriptor: descriptor)
    }
    
    static func buildComputePipelineState() -> MTLComputePipelineState {
        guard let kernelFunction =
            STLRRenderer.library?.makeFunction(name: "terrain_kernel") else {
                fatalError("Tessellation shader function not found")
        }
        return try! STLRRenderer.metalDevice.makeComputePipelineState(function: kernelFunction)
    }
    
    static func createControlPoints(patches: (horizontal: Int, vertical: Int),
                                    size: (width: Float, height: Float)) -> [simd_float3] {
        
        var points: [simd_float3] = []
        // per patch width and height
        let width = 1 / Float(patches.horizontal)
        let height = 1 / Float(patches.vertical)
        
        for j in 0..<patches.vertical {
            let row = Float(j)
            for i in 0..<patches.horizontal {
                let column = Float(i)
                let left = width * column
                let bottom = height * row
                let right = width * column + width
                let top = height * row + height
                
                points.append([left, 0, top])
                points.append([right, 0, top])
                points.append([right, 0, bottom])
                points.append([left, 0, bottom])
            }
        }
        // size and convert to Metal coordinates
        // eg. 6 across would be -3 to + 3
        points = points.map {
            [$0.x * size.width - size.width / 2,
             0,
             $0.z * size.height - size.height / 2]
        }
        return points
    }
    
    static func heightToSlope(source: MTLTexture) -> MTLTexture {
        let descriptor =
            MTLTextureDescriptor.texture2DDescriptor(pixelFormat: source.pixelFormat,
                                                     width: source.width,
                                                     height: source.height,
                                                     mipmapped: false)
        descriptor.usage = [.shaderWrite, .shaderRead]
        guard let destination = STLRRenderer.metalDevice.makeTexture(descriptor: descriptor),
            let commandBuffer = STLRRenderer.commandQueue.makeCommandBuffer()
            else {
                fatalError()
        }
        let shader = MPSImageSobel(device: STLRRenderer.metalDevice)
        shader.encode(commandBuffer: commandBuffer,
                      sourceTexture: source,
                      destinationTexture: destination)
        commandBuffer.commit()
        return destination
    }
    
    func update(viewMatrix: float4x4) {
        guard let computeEncoder = STLRRenderer.commandBuffer?.makeComputeCommandEncoder() else {
            fatalError("failed to create compute encoder")
        }
        computeEncoder.setComputePipelineState(tessellationPipelineState)
        computeEncoder.setBytes(&edgeFactors,
                                length: MemoryLayout<Float>.size * edgeFactors.count,
                                index: 0)
        computeEncoder.setBytes(&insideFactors,
                                length: MemoryLayout<Float>.size * insideFactors.count,
                                index: 1)
        computeEncoder.setBuffer(tessellationFactorsBuffer, offset: 0, index: 2)
        
        var cameraPosition = viewMatrix.columns.3
        computeEncoder.setBytes(&cameraPosition,
                                length: MemoryLayout<simd_float4>.stride,
                                index: 3)
        
        var matrix = modelMatrix
        computeEncoder.setBytes(&matrix,
                                length: MemoryLayout<float4x4>.stride,
                                index: 4)
        computeEncoder.setBuffer(controlPointsBuffer, offset: 0, index: 5)
        computeEncoder.setBytes(&terrainUniforms,
                                length: MemoryLayout<STLRTerrainUniforms>.stride,
                                index: 6)
        
        let width = min(patchCount, tessellationPipelineState.threadExecutionWidth)
        computeEncoder.dispatchThreadgroups(MTLSizeMake(patchCount, 1, 1),
                                            threadsPerThreadgroup: MTLSizeMake(width, 1, 1))
        computeEncoder.endEncoding()
        
    }
}

extension STLRTerrain: Texturable {}


extension STLRTerrain: Renderable {
    
    func doRender(commandEncoder: MTLRenderCommandEncoder, uniforms: STLRUniforms, fragmentUniforms: STLRFragmentUniforms) {
        var mvp = uniforms.projectionMatrix * uniforms.viewMatrix * modelMatrix
        commandEncoder.setVertexBytes(&mvp, length: MemoryLayout<float4x4>.stride, index: 1)
        commandEncoder.setRenderPipelineState(renderPipelineState)
        commandEncoder.setVertexBuffer(controlPointsBuffer, offset: 0, index: 0)
        commandEncoder.setTessellationFactorBuffer(tessellationFactorsBuffer,
                                                  offset: 0,
                                                  instanceStride: 0)
        commandEncoder.setTriangleFillMode(.fill)
        commandEncoder.setVertexTexture(heightMap, index: 0)
        commandEncoder.setVertexTexture(terrainSlope, index: 4)
        commandEncoder.setVertexBytes(&terrainUniforms,
                                     length: MemoryLayout<STLRTerrainUniforms>.stride, index: 6)
        commandEncoder.setFragmentTexture(cliffMap, index: 1)
        commandEncoder.setFragmentTexture(snowMap, index: 2)
        commandEncoder.setFragmentTexture(grassMap, index: 3)
        commandEncoder.setFragmentBytes(&tiling, length: MemoryLayout<Float>.stride, index: 1)
        // draw
        commandEncoder.drawPatches(numberOfPatchControlPoints: 4,
                                  patchStart: 0, patchCount: patchCount,
                                  patchIndexBuffer: nil,
                                  patchIndexBufferOffset: 0,
                                  instanceCount: 1, baseInstance: 0)
        
        
    }
}
