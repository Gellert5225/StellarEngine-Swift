//
//  Texturable.swift
//  ObsidianEngine
//
//  Created by Gellert on 6/14/18.
//  Copyright © 2018 Gellert. All rights reserved.
//

import MetalKit

protocol Texturable {}

extension Texturable {
    
    static func loadTexture(imageName: String, bundle: Bundle) throws -> MTLTexture? {
        let textureLoader = MTKTextureLoader(device: STLRRenderer.metalDevice)
        let textureLoaderOptions: [MTKTextureLoader.Option: Any] =
            [.origin: MTKTextureLoader.Origin.bottomLeft,
             .SRGB: false,
             .generateMipmaps: NSNumber(booleanLiteral: true)]
        let fileExtension =
            (URL(fileURLWithPath: imageName).pathExtension.isEmpty ?
                "png" : nil) ?? ""
        
        guard let url = recursivePathsForResource(name: imageName, extensionName: fileExtension, in: bundle.bundleURL.path)
            else {
            STLRLog.CORE_WARNING("Failed to load \(imageName)\n - loading from Assets Catalog")
                return try textureLoader.newTexture(name: imageName, scaleFactor: 1.0,
                                                    bundle: bundle, options: nil)
        }
        
        let texture = try textureLoader.newTexture(URL: url.absoluteURL, options: textureLoaderOptions)
        STLRLog.CORE_INFO("Loaded Texture: \(url.lastPathComponent)")
        return texture
    }
    
    static func loadCubeTexture(imageName: String) throws -> MTLTexture {
        let textureLoader = MTKTextureLoader(device: STLRRenderer.metalDevice)
        if let texture = MDLTexture(cubeWithImagesNamed: [imageName]) {
            let options: [MTKTextureLoader.Option: Any] =
                [.origin: MTKTextureLoader.Origin.topLeft,
                 .SRGB: false,
                 .generateMipmaps: NSNumber(booleanLiteral: false)]
            return try textureLoader.newTexture(texture: texture, options: options)
        }
        let texture = try textureLoader.newTexture(name: imageName, scaleFactor: 1.0,
                                                   bundle: .main)
        return texture
    }
    
    static func loadTextureArray(textureNames: [String], bundle: Bundle) -> MTLTexture? {
        var textures: [MTLTexture] = []
        for textureName in textureNames {
            do {
                if let texture = try STLRMorph.loadTexture(imageName: textureName, bundle: bundle) {
                    textures.append(texture)
                }
            } catch {
                fatalError(error.localizedDescription)
            }
        }
        guard textures.count > 0 else {return nil}
        
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = .type2DArray
        descriptor.pixelFormat = textures[0].pixelFormat
        descriptor.width = textures[0].width
        descriptor.height = textures[0].height
        descriptor.arrayLength = textures.count
        let arrayTexture = STLRRenderer.metalDevice.makeTexture(descriptor: descriptor)!
        let commandBuffer = STLRRenderer.commandQueue.makeCommandBuffer()!
        let blitEncoder = commandBuffer.makeBlitCommandEncoder()!
        let origin = MTLOrigin(x: 0, y: 0, z: 0)
        let size = MTLSize(width: arrayTexture.width, height: arrayTexture.height, depth: 1)
        for (index, texture) in textures.enumerated() {
            blitEncoder.copy(from: texture, sourceSlice: 0, sourceLevel: 0,
                             sourceOrigin: origin, sourceSize: size,
                             to: arrayTexture, destinationSlice: index,
                             destinationLevel: 0, destinationOrigin: origin)
        }
        blitEncoder.endEncoding()
        commandBuffer.commit()
        return arrayTexture
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromMTKTextureLoaderOrigin(_ input: MTKTextureLoader.Origin) -> String {
    return input.rawValue
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromMTKTextureLoaderOption(_ input: MTKTextureLoader.Option) -> String {
    return input.rawValue
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToOptionalMTKTextureLoaderOptionDictionary(_ input: [String: Any]?) -> [MTKTextureLoader.Option: Any]? {
    guard let input = input else { return nil }
    return Dictionary(uniqueKeysWithValues: input.map { key, value in (MTKTextureLoader.Option(rawValue: key), value)})
}

