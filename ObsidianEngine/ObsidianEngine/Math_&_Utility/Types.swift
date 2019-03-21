//
//  Types.swift
//  ObsidianEngine
//
//  Created by Gellert on 6/17/18.
//  Copyright © 2018 Gellert. All rights reserved.
//

import Foundation
import simd

public struct OBSDVertex {
    var position: vector_float4
    var color: vector_float4
    var texture: vector_float2
    
    var positionSize: Int {
        get {
            return position.count * MemoryLayout.size(ofValue: position[0])
        }
    }
    
    var colorSize: Int {
        get {
            return color.count * MemoryLayout.size(ofValue: color[0])
        }
    }
}
