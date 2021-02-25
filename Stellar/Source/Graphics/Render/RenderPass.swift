import MetalKit

class RenderPass {
    var descriptor: MTLRenderPassDescriptor?

    var depthTexture: MTLTexture?
    var depthTexture_resolve: MTLTexture?
    
    let name: String
    let multiplier: Float
    
    var textures: [MTLTexture?] = []
    var resolveTextures: [MTLTexture?] = []
    
    var loadAction: MTLLoadAction = .clear

    init(name: String, size: CGSize, multiplier: Float, sample: Bool = true) {
        self.name = name
        self.multiplier = multiplier
        updateTextures(size: size)
    }
    
    func updateTextures(size: CGSize) {
        depthTexture = RenderPass.buildTexture(size: size, multiplier: multiplier, label: name, pixelFormat: .depth32Float, sample: true)
        depthTexture_resolve = RenderPass.buildTexture(size: size, multiplier: multiplier, label: name + " Depth Texture - Resolved", pixelFormat: .depth32Float)
        descriptor = setupRenderPassDescriptor(textures: [], resolveTextures: [], depthTexture: depthTexture!, depthTextureResolve: depthTexture_resolve!)
    }
    
    func setupRenderPassDescriptor(textures: [MTLTexture?], resolveTextures: [MTLTexture?], depthTexture: MTLTexture, depthTextureResolve: MTLTexture) -> MTLRenderPassDescriptor {
        let descriptor = MTLRenderPassDescriptor()
        for i in 0..<textures.count {
            descriptor.setUpColorAttachment(position: i, texture: textures[i]!, resolveTexture: resolveTextures[i]!, loadAction: self.loadAction)
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
        stencilAttachment.clearStencil = 0
    }
    
    func setUpColorAttachment(position: Int, texture: MTLTexture, resolveTexture: MTLTexture, loadAction: MTLLoadAction) {
        colorAttachments[position].texture = texture
        colorAttachments[position].resolveTexture = resolveTexture
        colorAttachments[position].loadAction = loadAction
        colorAttachments[position].storeAction = .multisampleResolve
        colorAttachments[position].clearColor = MTLClearColorMake(0.66, 0.9, 0.96, 1)
    }
}
