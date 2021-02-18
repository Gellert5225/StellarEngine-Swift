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
    
    var textures: [MTLTexture]
    var resolveTextures: [MTLTexture]

    init(name: String, size: CGSize, sample: Bool = true) {
        self.name = name
        texture = RenderPass.buildTexture(size: size, label: name, pixelFormat: .bgra8Unorm)
        normal = RenderPass.buildTexture(size: size, label: name, pixelFormat: .rgba16Float)
        position = RenderPass.buildTexture(size: size, label: name, pixelFormat: .rgba16Float)
        depthTexture = RenderPass.buildTexture(size: size, label: name, pixelFormat: .depth32Float)
        texture_resolve = RenderPass.buildResolveTexture(size: size, pixelFormat: .bgra8Unorm)
        normal_resolve = RenderPass.buildResolveTexture(size: size, pixelFormat: .rgba16Float)
        position_resolve = RenderPass.buildResolveTexture(size: size, pixelFormat: .rgba16Float)
        depthTexture_resolve = RenderPass.buildResolveTexture(size: size, pixelFormat: .depth32Float)
        textures = [texture, normal, position]
        resolveTextures = [texture_resolve, normal_resolve, position_resolve]
        descriptor = RenderPass.setupRenderPassDescriptor(textures: textures, resolveTextures: resolveTextures, depthTexture: depthTexture, depthTextureResolve: depthTexture_resolve)
    }

    func updateTextures(size: CGSize) {
        texture = RenderPass.buildTexture(size: size, label: name, pixelFormat: .bgra8Unorm)
        normal = RenderPass.buildTexture(size: size, label: name, pixelFormat: .rgba16Float)
        position = RenderPass.buildTexture(size: size, label: name, pixelFormat: .rgba16Float)
        depthTexture = RenderPass.buildTexture(size: size, label: name, pixelFormat: .depth32Float)
        texture_resolve = RenderPass.buildResolveTexture(size: size, pixelFormat: .bgra8Unorm)
        normal_resolve = RenderPass.buildResolveTexture(size: size, pixelFormat: .rgba16Float)
        position_resolve = RenderPass.buildResolveTexture(size: size, pixelFormat: .rgba16Float)
        depthTexture_resolve = RenderPass.buildResolveTexture(size: size, pixelFormat: .depth32Float)
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
    
    static func buildResolveTexture(size: CGSize, pixelFormat: MTLPixelFormat) -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat,
                                                                  width: Int(size.width * 0.5),
                                                                  height: Int(size.height * 0.5),
                                                                  mipmapped: true)
        descriptor.textureType = .type2D
        descriptor.sampleCount = 1
        descriptor.storageMode = .private
        guard let texture = STLRRenderer.metalDevice.makeTexture(descriptor: descriptor) else {
            fatalError("Texture not created")
        }
        return texture
    }
    
    static func buildTexture(size: CGSize, label: String, pixelFormat: MTLPixelFormat, sample: Bool = false) -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat,
                                                                  width: Int(size.width * 0.5),
                                                                  height: Int(size.height * 0.5),
                                                                  mipmapped: false)
        descriptor.textureType = .type2DMultisample
        descriptor.sampleCount = 4
        descriptor.storageMode = .private
        //descriptor.textureType = .type2D
        descriptor.usage = [.renderTarget, .shaderRead]
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
    
    func setUpColorAttachment(position: Int, texture: MTLTexture, resolveTexture: MTLTexture) {
        colorAttachments[position].texture = texture
        colorAttachments[position].resolveTexture = resolveTexture
        colorAttachments[position].loadAction = .clear
        colorAttachments[position].storeAction = .multisampleResolve
        colorAttachments[position].clearColor = MTLClearColorMake(0.66, 0.9, 0.96, 1)
    }
}
