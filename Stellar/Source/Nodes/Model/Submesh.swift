//
//  Submesh.swift
//  ObsidianEngine
//
//  Created by Jiahe Li on 28/06/2018.
//  Copyright © 2018 Gellert. All rights reserved.
//

import MetalKit

class STLRSubmesh {
    let submesh: MTKSubmesh
    
    struct Textures {
        let baseColor: Int?
        let normal: Int?
        let roughness: Int?
        let metallic: Int?
        let ao: Int?
    }
    let textures: Textures
    let material: Material
    //let pipelineState: MTLRenderPipelineState?
    
    var fragmentFunction: MTLFunction
    var vertexFunction: MTLFunction
    
    var textureBuffer: MTLBuffer?
    
    init(submesh: MTKSubmesh, mdlSubmesh: MDLSubmesh, vertexFunctionName: String, fragmentFunctionName: String) {
        self.submesh = submesh
        textures = Textures(material: mdlSubmesh.material)
        material = Material(material: mdlSubmesh.material)
        
        let library = STLRRenderer.library
        let functionConstants = STLRSubmesh.makeFunctionConstants(textures: textures)
        vertexFunction = (library?.makeFunction(name: vertexFunctionName))!
        
        do {
            fragmentFunction = try library!.makeFunction(name: fragmentFunctionName, constantValues: functionConstants)
        } catch {
            fatalError("No metal function exists")
        }
        
//        let pipelineDescriptor = MTLRenderPipelineDescriptor()
//        pipelineDescriptor.vertexFunction = vertexFunction
//        pipelineDescriptor.fragmentFunction = fragmentFunction
//
//        pipelineDescriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(STLRModel.defaultVertexDescriptor)
//        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
//        pipelineDescriptor.colorAttachments[1].pixelFormat = .rgba16Float
//        pipelineDescriptor.colorAttachments[2].pixelFormat = .rgba16Float
//        pipelineDescriptor.colorAttachments[3].pixelFormat = .bgra8Unorm
//        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
//        pipelineDescriptor.sampleCount = 4
//        //pipelineDescriptor.supportIndirectCommandBuffers = true
//        do {
//            pipelineState = try STLRRenderer.metalDevice.makeRenderPipelineState(descriptor: pipelineDescriptor)
//        } catch let error {
//            fatalError(error.localizedDescription)
//        }
        
        initializeTextures()
    }
    
    func initializeTextures() {
        let textureEncoder = fragmentFunction.makeArgumentEncoder(bufferIndex: Int(STLRGBufferTexturesIndex.rawValue))
        textureBuffer = STLRRenderer.metalDevice.makeBuffer(length: textureEncoder.encodedLength, options: [])!
        textureBuffer?.label = "TextureBuffer"
        textureEncoder.setArgumentBuffer(textureBuffer, offset: 0)
        if let index = textures.baseColor {
            textureEncoder.setTexture(STLRTextureController.textures[index], index: 0)
        }
        if let index = textures.normal {
            textureEncoder.setTexture(STLRTextureController.textures[index], index: 1)
        }
        if let index = textures.roughness {
            textureEncoder.setTexture(STLRTextureController.textures[index], index: 2)
        }
        if let index = textures.metallic {
            textureEncoder.setTexture(STLRTextureController.textures[index], index: 3)
        }
        if let index = textures.ao {
            textureEncoder.setTexture(STLRTextureController.textures[index], index: 4)
        }
    }
}

private extension STLRSubmesh {
    static func makeFunctionConstants(textures: Textures)
        -> MTLFunctionConstantValues {
            let functionConstants = MTLFunctionConstantValues()
            var property = textures.baseColor != nil
            functionConstants.setConstantValue(&property, type: .bool, index: 0)
            property = textures.normal != nil
            functionConstants.setConstantValue(&property, type: .bool, index: 1)
            property = textures.roughness != nil
            functionConstants.setConstantValue(&property, type: .bool, index: 2)
            property = textures.metallic != nil
            functionConstants.setConstantValue(&property, type: .bool, index: 3)
            property = textures.ao != nil
            functionConstants.setConstantValue(&property, type: .bool, index: 4)
            
            return functionConstants
    }
    
    func makePipelineState(textures: Textures) -> MTLRenderPipelineState {
        var pipelineState: MTLRenderPipelineState
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        
        pipelineDescriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(MDLVertexDescriptor.defaultVertexDescriptor)
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.colorAttachments[1].pixelFormat = .rgba16Float
        pipelineDescriptor.colorAttachments[2].pixelFormat = .rgba16Float
        pipelineDescriptor.colorAttachments[3].pixelFormat = .bgra8Unorm
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        pipelineDescriptor.sampleCount = 4
        do {
            pipelineState = try STLRRenderer.metalDevice.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch let error {
            fatalError(error.localizedDescription)
        }
        return pipelineState
    }
}

extension STLRSubmesh: Texturable {}

private extension STLRSubmesh.Textures {
    init(material: MDLMaterial?) {
        func property(with semantic: MDLMaterialSemantic) -> MTLTexture? {
            guard let property = material?.property(with: semantic),
                property.type == .string,
                let filename = property.stringValue,
                let bundleURL = Bundle.main.url(forResource: "Assets", withExtension: "bundle"),
                let bundle = Bundle(url: bundleURL),
                let texture = ((try? STLRSubmesh.loadTexture(imageName: filename, bundle: bundle)) as MTLTexture??) else {
                    return nil
            }
            return texture
        }
        baseColor = STLRTextureController.addTexture(texture: property(with: .baseColor))
        normal = STLRTextureController.addTexture(texture: property(with: .tangentSpaceNormal))
        roughness = STLRTextureController.addTexture(texture: property(with: .roughness))
        metallic = STLRTextureController.addTexture(texture: property(with: .metallic))
        ao = STLRTextureController.addTexture(texture: property(with: .ambientOcclusion))
    }
}

private extension Material {
    init(material: MDLMaterial?) {
        self.init()
        if let baseColor = material?.property(with: .baseColor),
            baseColor.type == .float3 {
            self.baseColor = baseColor.float3Value
        }
        if let specular = material?.property(with: .specular),
            specular.type == .float3 {
            self.specularColor = specular.float3Value
        }
        if let shininess = material?.property(with: .specularExponent),
            shininess.type == .float {
            self.shininess = shininess.floatValue
        }
        if let roughness = material?.property(with: .roughness),
            roughness.type == .float3 {
            self.roughness = roughness.floatValue
        }
        if let metallic = material?.property(with: .metallic),
            metallic.type == .float3 {
            self.metallic = metallic.floatValue
        }
    }
}

extension MDLVertexDescriptor {
  static var defaultVertexDescriptor: MDLVertexDescriptor = {
    let vertexDescriptor = MDLVertexDescriptor()
    var offset  = 0
    
    // position attribute
    vertexDescriptor.attributes[0]
      = MDLVertexAttribute(name: MDLVertexAttributePosition,
                           format: .float3,
                           offset: 0,
                           bufferIndex: Int(BufferIndexVertices.rawValue))
    offset += MemoryLayout<float3>.stride
    
    // normal attribute
    vertexDescriptor.attributes[1] =
      MDLVertexAttribute(name: MDLVertexAttributeNormal,
                         format: .float3,
                         offset: offset,
                         bufferIndex: Int(BufferIndexVertices.rawValue))
    offset += MemoryLayout<float3>.stride
    
    // uv attribute
    vertexDescriptor.attributes[2] =
      MDLVertexAttribute(name: MDLVertexAttributeTextureCoordinate,
                         format: .float2,
                         offset: offset,
                         bufferIndex: Int(BufferIndexVertices.rawValue))
    offset += MemoryLayout<float2>.stride
    
    vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: offset)
    return vertexDescriptor
  }()
}

