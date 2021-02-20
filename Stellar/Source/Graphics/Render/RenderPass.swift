import MetalKit

class RenderPass {
    var descriptor: MTLRenderPassDescriptor
    var texture: MTLTexture
    var normal: MTLTexture
    var position: MTLTexture
    var depthTexture: MTLTexture
    
    var texture_resolve: MTLTexture
    var normal_resolve: MTLTexture
    var position_resolve: MTLTexture
    var depthTexture_resolve: MTLTexture
    
    let name: String
    let multiplier: Float
    
    var textures: [MTLTexture]
    var resolveTextures: [MTLTexture]

    init(name: String, size: CGSize, multiplier: Float, sample: Bool = true) {
        self.name = name
        self.multiplier = multiplier
        texture = RenderPass.buildTexture(size: size, multiplier: multiplier, label: name + " Albedo Texture", pixelFormat: .bgra8Unorm, sample: true)
        normal = RenderPass.buildTexture(size: size, multiplier: multiplier, label: name + " Normal Texture", pixelFormat: .rgba16Float, sample: true)
        position = RenderPass.buildTexture(size: size, multiplier: multiplier, label: name + " Position Texture", pixelFormat: .rgba16Float, sample: true)
        depthTexture = RenderPass.buildTexture(size: size, multiplier: multiplier, label: name + " Depth Texture", pixelFormat: .depth32Float, sample: true)
        texture_resolve = RenderPass.buildTexture(size: size, multiplier: multiplier, label: name + " Albedo Texture - Resolved", pixelFormat: .bgra8Unorm)
        normal_resolve = RenderPass.buildTexture(size: size, multiplier: multiplier, label: name + " Normal Texture - Resolved", pixelFormat: .rgba16Float)
        position_resolve = RenderPass.buildTexture(size: size, multiplier: multiplier, label: name + " Position Texture - Resolved", pixelFormat: .rgba16Float)
        depthTexture_resolve = RenderPass.buildTexture(size: size, multiplier: multiplier, label: name + " Depth Texture - Resolved", pixelFormat: .depth32Float)
        textures = [texture, normal, position]
        resolveTextures = [texture_resolve, normal_resolve, position_resolve]
        descriptor = RenderPass.setupRenderPassDescriptor(textures: textures, resolveTextures: resolveTextures, depthTexture: depthTexture, depthTextureResolve: depthTexture_resolve)
    }

    func updateTextures(size: CGSize) {
        texture = RenderPass.buildTexture(size: size, multiplier: multiplier, label: name, pixelFormat: .bgra8Unorm, sample: true)
        normal = RenderPass.buildTexture(size: size, multiplier: multiplier, label: name, pixelFormat: .rgba16Float, sample: true)
        position = RenderPass.buildTexture(size: size, multiplier: multiplier, label: name, pixelFormat: .rgba16Float, sample: true)
        depthTexture = RenderPass.buildTexture(size: size, multiplier: multiplier, label: name, pixelFormat: .depth32Float, sample: true)
        texture_resolve = RenderPass.buildTexture(size: size, multiplier: multiplier, label: name + " Albedo Texture - Resolved", pixelFormat: .bgra8Unorm)
        normal_resolve = RenderPass.buildTexture(size: size, multiplier: multiplier, label: name + " Normal Texture - Resolved", pixelFormat: .rgba16Float)
        position_resolve = RenderPass.buildTexture(size: size, multiplier: multiplier, label: name + " Position Texture - Resolved", pixelFormat: .rgba16Float)
        depthTexture_resolve = RenderPass.buildTexture(size: size, multiplier: multiplier, label: name + " Depth Texture - Resolved", pixelFormat: .depth32Float)
        resolveTextures = [texture_resolve, normal_resolve, position_resolve]
        textures = [texture, normal, position]
        resolveTextures = [texture_resolve, normal_resolve, position_resolve]
        descriptor = RenderPass.setupRenderPassDescriptor(textures: textures, resolveTextures: resolveTextures, depthTexture: depthTexture, depthTextureResolve: depthTexture_resolve)
    }
    
    static func setupRenderPassDescriptor(textures: [MTLTexture], resolveTextures: [MTLTexture], depthTexture: MTLTexture, depthTextureResolve: MTLTexture) -> MTLRenderPassDescriptor {
        let descriptor = MTLRenderPassDescriptor()
        for i in 0..<3 {
            descriptor.setUpColorAttachment(position: i, texture: textures[i], resolveTexture: resolveTextures[i])
        }
        descriptor.setUpDepthAttachment(texture: depthTexture, resolveTexture: depthTextureResolve)
        return descriptor
    }
    
    static func buildTexture(size: CGSize, multiplier: Float, label: String, pixelFormat: MTLPixelFormat, sample: Bool = false) -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat,
                                                                  width: Int(size.width * CGFloat(multiplier)),
                                                                  height: Int(size.height * CGFloat(multiplier)),
                                                                  mipmapped: !sample)
        if (sample) {
            descriptor.textureType = .type2DMultisample
            descriptor.sampleCount = 4
            descriptor.usage = [.renderTarget, .shaderRead]
        }
        descriptor.storageMode = .private
        guard let texture = STLRRenderer.metalDevice.makeTexture(descriptor: descriptor) else {
            fatalError("Texture not created")
        }
        texture.label = label
        return texture
    }
}

extension MTLRenderPassDescriptor {
    func setUpDepthAttachment(texture: MTLTexture, resolveTexture: MTLTexture) {
        depthAttachment.texture = texture
        depthAttachment.resolveTexture = resolveTexture
        depthAttachment.loadAction = .clear
        depthAttachment.storeAction = .multisampleResolve
        depthAttachment.clearDepth = 1
    }
    
    func setUpStencilAttachment(texture: MTLTexture, resolveTexture: MTLTexture) {
        stencilAttachment.texture = texture
        stencilAttachment.resolveTexture = resolveTexture
        stencilAttachment.loadAction = .clear
        stencilAttachment.storeAction = .multisampleResolve
    }
    
    func setUpColorAttachment(position: Int, texture: MTLTexture, resolveTexture: MTLTexture) {
        colorAttachments[position].texture = texture
        colorAttachments[position].resolveTexture = resolveTexture
        colorAttachments[position].loadAction = .clear
        colorAttachments[position].storeAction = .multisampleResolve
        colorAttachments[position].clearColor = MTLClearColorMake(0.66, 0.9, 0.96, 1)
    }
}
