//
//  Camera.swift
//  ObsidianEngine
//
//  Created by Gellert on 6/17/18.
//  Copyright © 2018 Gellert. All rights reserved.
//

import MetalKit

open class STLRCamera: STLRNode {
    
    var viewMatrix = float4x4.identity()
    
    open var fovDegrees: Float = 80
    open var nearZ: Float = 0.1
    open var farZ: Float = 1000
    open var aspect: Float = 1.0
    
    var projectionMatrix: float4x4 {
        return float4x4(projectionFov: radians(fromDegrees: fovDegrees),
                        near: nearZ,
                        far: farZ,
                        aspect: aspect)
    }
    
    var transform = Transform() {
        didSet {
            let translateMatrix = float4x4(translation: [-transform.position.x,
                                                         -transform.position.y,
                                                         -transform.position.z])
            let rotateMatrix = float4x4(rotation: transform.rotation)
            viewMatrix =  rotateMatrix * translateMatrix
        }
    }
    
    override init() {
        super.init()
        name = "Defualt Camera"
    }
    
    func zoom(delta: Float) {
        let sensitivity = Float(0.01)
        let result = transform.position.y + Float(delta) * sensitivity
        transform.position.y = result
    }
    
    func rotate(delta: simd_float2) {
        let sensitivity: Float = 0.002
        transform.rotation.x += delta.y * sensitivity
        transform.rotation.y -= delta.x * sensitivity
    }
}

open class STLRArcballCamera: STLRCamera {
    
    var minDistance: Float = 0.5
    var maxDistance: Float = 100
    var target: simd_float3 = [0, 0, 0] {
        didSet {
            viewMatrix = updateViewMatrix()
        }
    }

    var distance: Float = 0 {
        didSet {
            viewMatrix = updateViewMatrix()
        }
    }
    
    override init() {
        super.init()
        name = "Arcball Camera"
        viewMatrix = updateViewMatrix()
    }

    public func updateViewMatrix() -> float4x4 {
        let translateMatrix = float4x4(translation: [target.x, target.y, target.z - distance])
        let rotateMatrix = float4x4(rotationYXZ: [-transform.rotation.x, transform.rotation.y, 0])
        let matrix = (rotateMatrix * translateMatrix).inverse
        //transform.position = rotateMatrix.upperLeft() * -matrix.columns.3.xyz
        
        return matrix
    }

    override func zoom(delta: Float) {
        let sensitivity: Float = 0.05
        distance -= delta * sensitivity
        viewMatrix = updateViewMatrix()
    }

    override func rotate(delta: simd_float2) {
        let sensitivity: Float = 0.005
        transform.rotation.y += delta.x * sensitivity
        transform.rotation.x += delta.y * sensitivity
        transform.rotation.x = max(-Float.pi/2, min(transform.rotation.x, Float.pi/2))
        viewMatrix = updateViewMatrix()
    }
}

public enum STLRCameraType {
    case Arcball
    case FPP
    case TPP
    case Ortho
}
