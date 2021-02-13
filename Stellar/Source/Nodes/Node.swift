//
//  Node.swift
//  ObsidianEngine
//
//  Created by Gellert on 6/17/18.
//  Copyright © 2018 Gellert. All rights reserved.
//

import MetalKit

open class STLRNode {
    
    // MARK: Public
    static public var count = 0
    
    open var name: String = "untitled"
    
    open var materialColor = float4(repeating: 1)
    
    open var specularIntensity: Float = 1
    
    open var shininess: Float = 1

    open var position = float3(repeating: 0)
    
    open var rotation: simd_float3 = [0, 0, 0] {
        didSet {
            let rotationMatrix = float4x4(rotation: rotation)
            quaternion = simd_quatf(rotationMatrix)
        }
    }
    
    open var scale: simd_float3 = [1.0, 1.0, 1.0]
    
    open func rotate(x: Float, y: Float, z: Float) {
        rotation = [radians(fromDegrees: x), radians(fromDegrees: y), radians(fromDegrees: z)]
    }
    
    var modelMatrix: matrix_float4x4 {
        let translateMatrix = float4x4(translation: position)
        let rotateMatrix = float4x4(quaternion)
        let scaleMatrix = float4x4(scaling: scale)
        return translateMatrix * rotateMatrix * scaleMatrix
    }
    
    var worldTransform: float4x4 {
        if let parent = parent {
            return parent.worldTransform * self.modelMatrix
        }
        return modelMatrix
    }
    
    open var children: [STLRNode] = []
    
    open var parent: STLRNode?
    
    var quaternion = simd_quatf()
    
    open func add(childNode: STLRNode) {
        children.append(childNode)
        childNode.parent = self
    }
    
    open func remove(childNode: STLRNode) {
        for child in childNode.children {
            child.parent = self
            children.append(child)
        }
        childNode.children = []
        guard let index = (children.firstIndex {
            $0 === childNode
        }) else { return }
        children.remove(at: index)
        childNode.parent = nil
    }
}
