//
//  Renderable.swift
//  ObsidianEngine
//
//  Created by Gellert on 6/13/18.
//  Copyright © 2018 Gellert. All rights reserved.
//

import MetalKit

protocol Renderable {
    
    func doRender(commandEncoder: MTLRenderCommandEncoder, uniforms: OBSDUniforms, fragmentUniforms: OBSDFragmentUniforms)
    
}
