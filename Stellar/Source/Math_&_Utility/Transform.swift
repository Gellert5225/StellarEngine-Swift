//
//  Transform.swift
//  ObsidianEngine
//
//  Created by Jiahe Li on 15/03/2019.
//  Copyright © 2019 Gellert. All rights reserved.
//

import Foundation

public struct Transform {
    public var position = float3(repeating: 0)
    public var rotation = float3(repeating: 0)
    public var scale = float3(repeating: 1)
    
    public var modelMatrix: float4x4 {
        let translateMatrix = float4x4(translation: position)
        let rotateMatrix = float4x4(rotation: rotation)
        let scaleMatrix = float4x4(scaling: scale)
        return translateMatrix * rotateMatrix * scaleMatrix
    }
    
    public var normalMatrix: float3x3 {
        return float3x3(normalFrom4x4: modelMatrix)
    }
    
    public init() {
        
    }
}
