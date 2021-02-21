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
    
    static func addTexture(texture: MTLTexture?) -> Int? {
        guard let texture = texture else { return nil }
        STLRTextureController.textures.append(texture)
        return STLRTextureController.textures.count - 1;
    }
}
