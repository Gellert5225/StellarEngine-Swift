//
//  Camera.swift
//  ObsidianEngine
//
//  Created by Gellert on 6/17/18.
//  Copyright © 2018 Gellert. All rights reserved.
//

import MetalKit

open class STLRCamera: STLRNode {
    
    var viewMatrix: matrix_float4x4 {
        get{
            let translateMatrix = float4x4(translation: position)
            let rotateMatrix = float4x4(rotation: rotation)
            return (translateMatrix * rotateMatrix)
        }
    }
    
    open var fovDegrees: Float = 80
    open var nearZ: Float = 0.1
    open var farZ: Float = 1000
    open var aspect: Float = 1.0
    
    var mod: Float {
        return modulus(vector: position)
    }
    
    var projectionMatrix: float4x4 {
        return float4x4(projectionFov: radians(fromDegrees: fovDegrees),
                        near: nearZ,
                        far: farZ,
                        aspect: aspect)
        
    }
    
    override init() {
        super.init()
        name = "Defualt Camera"
    }
    
    func zoom(delta: Float) {}
    func rotate(delta: simd_float2) {}
}

open class STLRArcballCamera: STLRCamera {
    
    var minDistance: Float = 0.5
    var maxDistance: Float = 100
    var target: simd_float3 = [0, 0, 0] {
        didSet {
          _viewMatrix = updateViewMatrix()
        }
    }

    var distance: Float = 0 {
        didSet {
          _viewMatrix = updateViewMatrix()
        }
    }

    open override var rotation: simd_float3 {
        didSet {
          _viewMatrix = updateViewMatrix()
        }
    }

    override var viewMatrix: float4x4 {
        return _viewMatrix
    }
    
    private var _viewMatrix = float4x4.identity()

    override init() {
        super.init()
        name = "Archball Camera"
        _viewMatrix = updateViewMatrix()
    }

    private func updateViewMatrix() -> float4x4 {
        let translateMatrix = float4x4(translation: [target.x, target.y, target.z - distance])
        let rotateMatrix = float4x4(rotationYXZ: [-rotation.x, rotation.y, 0])
        let matrix = (rotateMatrix * translateMatrix).inverse
        position = rotateMatrix.upperLeft() * -matrix.columns.3.xyz
        
        return matrix
    }

    override func zoom(delta: Float) {
        let sensitivity: Float = 0.1
        distance -= delta * sensitivity
        _viewMatrix = updateViewMatrix()
    }

    override func rotate(delta: simd_float2) {
        let sensitivity: Float = 0.005
        rotation.y += delta.x * sensitivity
        rotation.x += delta.y * sensitivity
        rotation.x = max(-Float.pi/2, min(rotation.x, Float.pi/2))
        _viewMatrix = updateViewMatrix()
    }
}
