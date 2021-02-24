//
//  TextureDescriptorExtension.swift
//  Stellar
//
//  Created by Gellert Li on 2/20/21.
//  Copyright © 2021 Gellert. All rights reserved.
//

import MetalKit

extension MTLTextureDescriptor {
  static func descriptor(from texture: MTLTexture) -> MTLTextureDescriptor {
    let descriptor = MTLTextureDescriptor()
    descriptor.textureType = texture.textureType
    descriptor.pixelFormat = texture.pixelFormat
    descriptor.width = texture.width
    descriptor.height = texture.height
    descriptor.depth = texture.depth
    descriptor.mipmapLevelCount = texture.mipmapLevelCount
    descriptor.arrayLength = texture.arrayLength
    descriptor.sampleCount = texture.sampleCount
    descriptor.cpuCacheMode = texture.cpuCacheMode
    descriptor.usage = texture.usage
    descriptor.storageMode = texture.storageMode
    return descriptor
  }
}
