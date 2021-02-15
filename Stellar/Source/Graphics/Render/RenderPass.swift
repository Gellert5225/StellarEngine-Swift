import MetalKit

class RenderPass {
    var descriptor: MTLRenderPassDescriptor
    var texture: MTLTexture
    var normal: MTLTexture
    var position: MTLTexture
    var depthTexture: MTLTexture
    let name: String
    
    var textures: [MTLTexture]!

    init(name: String, size: CGSize) {
        self.name = name
        texture = RenderPass.buildTexture(size: size, label: name, pixelFormat: .bgra8Unorm)
        normal = RenderPass.buildTexture(size: size, label: name, pixelFormat: .rgba16Float)
        position = RenderPass.buildTexture(size: size, label: name, pixelFormat: .rgba16Float)
        depthTexture = RenderPass.buildTexture(size: size, label: name, pixelFormat: .depth32Float)
        textures = [texture, normal, position]
        descriptor = RenderPass.setupRenderPassDescriptor(textures: textures, depthTexture: depthTexture)
    }

    func updateTextures(size: CGSize) {
        texture = RenderPass.buildTexture(size: size, label: name, pixelFormat: .bgra8Unorm)
        normal = RenderPass.buildTexture(size: size, label: name, pixelFormat: .rgba16Float)
        position = RenderPass.buildTexture(size: size, label: name, pixelFormat: .rgba16Float)
        depthTexture = RenderPass.buildTexture(size: size, label: name, pixelFormat: .depth32Float)
        textures = [texture, normal, position]
        descriptor = RenderPass.setupRenderPassDescriptor(textures: textures, depthTexture: depthTexture)
    }
    
    static func setupRenderPassDescriptor(textures: [MTLTexture], depthTexture: MTLTexture) -> MTLRenderPassDescriptor {
        let descriptor = MTLRenderPassDescriptor()
        for (index, texture) in textures.enumerated() {
            descriptor.setUpColorAttachment(position: index, texture: texture)
        }
        descriptor.setUpDepthAttachment(texture: depthTexture)
        return descriptor
    }
    
    static func buildTexture(size: CGSize, label: String, pixelFormat: MTLPixelFormat) -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat,
                                                                  width: Int(size.width * 0.5),
                                                                  height: Int(size.height * 0.5),
                                                                  mipmapped: false)
        //descriptor.sampleCount = 4
        descriptor.storageMode = .private
        descriptor.textureType = .type2D
        descriptor.usage = [.renderTarget, .shaderRead]
        guard let texture = STLRRenderer.metalDevice.makeTexture(descriptor: descriptor) else {
            fatalError("Texture not created")
        }
        texture.label = label
        return texture
    }
}

private extension MTLRenderPassDescriptor {
    func setUpDepthAttachment(texture: MTLTexture) {
        depthAttachment.texture = texture
        depthAttachment.loadAction = .clear
        depthAttachment.storeAction = .store
        depthAttachment.clearDepth = 1
    }
  
    func setUpColorAttachment(position: Int, texture: MTLTexture) {
        let attachment: MTLRenderPassColorAttachmentDescriptor = colorAttachments[position]
        attachment.texture = texture
        attachment.loadAction = .clear
        attachment.storeAction = .store
        attachment.clearColor = MTLClearColorMake(0.73, 0.92, 1, 1)
    }
}
