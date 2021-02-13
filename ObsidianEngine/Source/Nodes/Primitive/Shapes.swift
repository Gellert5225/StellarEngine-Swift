//
//  Shapes.swift
//  ObsidianEngine
//
//  Created by Gellert on 6/8/18.
//  Copyright © 2018 Gellert. All rights reserved.
//

import MetalKit

open class OBSDShape: OBSDNode {
    
    // MARK: Public
    override open var position: simd_float3 {
        didSet {
            updateBuffers()
        }
    }
    
    override open var rotation: simd_float3 {
        didSet {
            updateBuffers()
        }
    }
    
    override open var scale: simd_float3 {
        didSet {
            updateBuffers()
        }
    }
        
    open var fragmentFunctionName: String = "lit_textured_shader"
    open var vertexFunctionName: String = "mp_vertex"
    open var textureImage: String? {
        didSet {
            //self.texture = Texturable.loadTexture(imageName: self.textureImage!)
        }
    }
    var texture: MTLTexture?
    
    // MARK: Private
    var pipelineState: MTLRenderPipelineState!
    
    var indices = [UInt16]()
    
    var vertexBuffer: MTLBuffer!

    var indexBuffer: MTLBuffer!
    
    var vertexDescriptor: MTLVertexDescriptor {
        let vertexDescriptor = MTLVertexDescriptor()
        
        vertexDescriptor.attributes[0].format = .float4
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        
        vertexDescriptor.attributes[1].format = .float4
        vertexDescriptor.attributes[1].offset = MemoryLayout<simd_float4>.stride
        vertexDescriptor.attributes[1].bufferIndex = 0
        
        vertexDescriptor.attributes[2].format = .float2
        vertexDescriptor.attributes[2].offset = MemoryLayout<simd_float4>.stride * 2
        vertexDescriptor.attributes[2].bufferIndex = 0
        
        vertexDescriptor.attributes[3].format = .float3
        vertexDescriptor.attributes[3].offset = MemoryLayout<Float>.stride * 10
        vertexDescriptor.attributes[3].bufferIndex = 0
        
        vertexDescriptor.layouts[0].stride = MemoryLayout<Float>.stride * 13
        return vertexDescriptor
    }
        
    // MARK: Public function
    public init(name: String) {
        super.init()
        self.name = name
    }
    
    // MAKR: Private function
    func updateBuffers() {
        
    }
}

extension OBSDShape: Texturable {}
