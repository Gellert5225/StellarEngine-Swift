//
//  TextureController.swift
//  Stellar
//
//  Created by Gellert Li on 2/20/21.
//  Copyright © 2021 Gellert. All rights reserved.
//

import MetalKit

// for a larger project, make this into an instance per scene
class STLRTextureController {
    static var textures: [MTLTexture] = []
    static var materials: [MDLMaterial] = []
    static var heap: MTLHeap?
    
    static func addTexture(texture: MTLTexture?) -> Int? {
        guard let texture = texture else { return nil }
        STLRTextureController.textures.append(texture)
        return STLRTextureController.textures.count - 1;
    }
    
    static func addMaterial(material: MDLMaterial?) -> Int? {
        guard let material = material else { return nil }
        STLRTextureController.materials.append(material)
        return STLRTextureController.materials.count - 1;
    }
    
    static func buildHeap() -> MTLHeap? {
        let heapDescriptor = MTLHeapDescriptor()
        
        let descriptors = textures.map { texture in
            MTLTextureDescriptor.descriptor(from: texture)
        }
        
        let sizeAndAligns = descriptors.map {
            STLRRenderer.metalDevice.heapTextureSizeAndAlign(descriptor: $0)
        }
        heapDescriptor.size = sizeAndAligns.reduce(0) { // align texture size with memory blocks
            $0 + $1.size - ($1.size & ($1.align - 1)) + $1.align
        }
        if heapDescriptor.size == 0 {
            return nil
        }
        
        guard let heap = STLRRenderer.metalDevice.makeHeap(descriptor: heapDescriptor) else { fatalError("Failed to makeheap") }
        let heapTextures = descriptors.map { descriptor -> MTLTexture in
            descriptor.storageMode = heapDescriptor.storageMode
            return heap.makeTexture(descriptor: descriptor)!
        } // empty texture resources on heap
                
        guard let commandBuffer = STLRRenderer.commandQueue.makeCommandBuffer(),
              let blitEncoder = commandBuffer.makeBlitCommandEncoder()
        else { fatalError("Failed to creat blit encoder") }
        
        zip(textures, heapTextures).forEach { (texture, heapTexture) in
            var region = MTLRegionMake2D(0, 0, texture.width, texture.height)
            for level in 0..<texture.mipmapLevelCount {
                for slice in 0..<texture.arrayLength {
                    blitEncoder.copy(from: texture, sourceSlice: slice, sourceLevel: level, sourceOrigin: region.origin, sourceSize: region.size, to: heapTexture, destinationSlice: slice, destinationLevel: level, destinationOrigin: region.origin)
                }
                region.size.width /= 2
                region.size.height /= 2
            }
        } // copy to heap
        
        blitEncoder.endEncoding()
        commandBuffer.commit()
        STLRTextureController.textures = heapTextures
        
        return heap
    }
}
