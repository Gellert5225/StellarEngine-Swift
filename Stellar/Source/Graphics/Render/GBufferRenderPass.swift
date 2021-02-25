//
//  GBufferRenderPass.swift
//  Stellar
//
//  Created by Gellert Li on 2/24/21.
//  Copyright © 2021 Gellert. All rights reserved.
//

import MetalKit

class GBufferRenderPass: RenderPass {
    var albedo: MTLTexture?
    var normal: MTLTexture?
    var position: MTLTexture?
    
    var albedo_resolve: MTLTexture?
    var normal_resolve: MTLTexture?
    var position_resolve: MTLTexture?
    
    override init(name: String, size: CGSize, multiplier: Float, sample: Bool = true) {
        super.init(name: name, size: size, multiplier: multiplier)
        
        updateTextures(size: size)
    }
    
    override func updateTextures(size: CGSize) {
        albedo = RenderPass.buildTexture(size: size, multiplier: multiplier, label: name, pixelFormat: .bgra8Unorm, sample: true)
        normal = RenderPass.buildTexture(size: size, multiplier: multiplier, label: name, pixelFormat: .rgba16Float, sample: true)
        position = RenderPass.buildTexture(size: size, multiplier: multiplier, label: name, pixelFormat: .rgba16Float, sample: true)
        depthTexture = RenderPass.buildTexture(size: size, multiplier: multiplier, label: name, pixelFormat: .depth32Float, sample: true)
        albedo_resolve = RenderPass.buildTexture(size: size, multiplier: multiplier, label: name + " Albedo Texture - Resolved", pixelFormat: .bgra8Unorm)
        normal_resolve = RenderPass.buildTexture(size: size, multiplier: multiplier, label: name + " Normal Texture - Resolved", pixelFormat: .rgba16Float)
        position_resolve = RenderPass.buildTexture(size: size, multiplier: multiplier, label: name + " Position Texture - Resolved", pixelFormat: .rgba16Float)
        depthTexture_resolve = RenderPass.buildTexture(size: size, multiplier: multiplier, label: name + " Depth Texture - Resolved", pixelFormat: .depth32Float)
        resolveTextures = [albedo_resolve, normal_resolve, position_resolve]
        textures = [albedo, normal, position]
        resolveTextures = [albedo_resolve, normal_resolve, position_resolve]
        descriptor = RenderPass.setupRenderPassDescriptor(textures: textures, resolveTextures: resolveTextures, depthTexture: depthTexture!, depthTextureResolve: depthTexture_resolve!)
    }
}
