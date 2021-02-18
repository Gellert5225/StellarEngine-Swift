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
        let baseColor: MTLTexture?
        let normal: MTLTexture?
        let roughness: MTLTexture?
        let metallic: MTLTexture?
        let ao: MTLTexture?
    }
    let textures: Textures
    let material: Material
    let pipelineState: MTLRenderPipelineState!
    
    init(submesh: MTKSubmesh, mdlSubmesh: MDLSubmesh, vertexFunctionName: String, fragmentFunctionName: String) {
        self.submesh = submesh
        textures = Textures(material: mdlSubmesh.material)
        material = Material(material: mdlSubmesh.material)
        pipelineState = STLRSubmesh.makePipelineState(textures: textures, vertexFunctionName: vertexFunctionName, fragmentFunctionName: fragmentFunctionName)
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
    
    static func makePipelineState(textures: Textures, vertexFunctionName: String, fragmentFunctionName: String) -> MTLRenderPipelineState {
        let library = STLRRenderer.library
        let functionConstants = makeFunctionConstants(textures: textures)
        let vertexFunction = library?.makeFunction(name: vertexFunctionName)
        
        let fragmentFunction: MTLFunction?
        do {
            fragmentFunction = try library?.makeFunction(name: fragmentFunctionName, constantValues: functionConstants)
        } catch {
            fatalError("No metal function exists")
        }
        
        var pipelineState: MTLRenderPipelineState
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        
        pipelineDescriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(STLRModel.defaultVertexDescriptor)
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.colorAttachments[1].pixelFormat = .rgba16Float
        pipelineDescriptor.colorAttachments[2].pixelFormat = .rgba16Float
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
        baseColor = property(with: .baseColor)
        normal = property(with: .tangentSpaceNormal)
        roughness = property(with: .roughness)
        metallic = property(with: .metallic)
        ao = property(with: .ambientOcclusion)
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

