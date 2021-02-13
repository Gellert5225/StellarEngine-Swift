//
//  Matrixmath.swift
//  ObsidianEngine
//
//  Created by Gellert on 6/17/18.
//  Copyright © 2018 Gellert. All rights reserved.
//

import simd

let π = Float.pi

func radians(fromDegrees degrees: Float) -> Float {
  return (degrees / 180) * π
}

func degrees(fromRadians radians: Float) -> Float {
  return (radians / π) * 180
}

public func modulus(vector: simd_float3) -> Float {
    return sqrtf(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
}

struct Rectangle {
    var left: Float = 0
    var right: Float = 0
    var top: Float = 0
    var bottom: Float = 0
}

extension Float {
    var radiansToDegrees: Float {
        return (self / π) * 180
    }
    var degreesToRadians: Float {
        return (self / 180) * π
    }
}

extension float4x4 {
    init(translation: simd_float3) {
        self = matrix_identity_float4x4
        columns.3.x = translation.x
        columns.3.y = translation.y
        columns.3.z = translation.z
    }
    
    init(scaling: simd_float3) {
        self = matrix_identity_float4x4
        columns.0.x = scaling.x
        columns.1.y = scaling.y
        columns.2.z = scaling.z
    }
    
    init(scaling: Float) {
        self = matrix_identity_float4x4
        columns.3.w = 1 / scaling
    }
    
    init(rotationX angle: Float) {
        self = matrix_identity_float4x4
        columns.1.y = cos(angle)
        columns.1.z = sin(angle)
        columns.2.y = -sin(angle)
        columns.2.z = cos(angle)
    }
    
    init(rotationY angle: Float) {
        self = matrix_identity_float4x4
        columns.0.x = cos(angle)
        columns.0.z = -sin(angle)
        columns.2.x = sin(angle)
        columns.2.z = cos(angle)
    }
    
    init(rotationZ angle: Float) {
        self = matrix_identity_float4x4
        columns.0.x = cos(angle)
        columns.0.y = sin(angle)
        columns.1.x = -sin(angle)
        columns.1.y = cos(angle)
    }
    
    init(rotation angle: SIMD3<Float>) {
        let rotationX = float4x4(rotationX: angle.x)
        let rotationY = float4x4(rotationY: angle.y)
        let rotationZ = float4x4(rotationZ: angle.z)
        self = rotationX * rotationY * rotationZ
    }
    
    static func identity() -> float4x4 {
        let matrix:float4x4 = matrix_identity_float4x4
        return matrix
    }
    
    func upperLeft() -> float3x3 {
        let x = columns.0.xyz
        let y = columns.1.xyz
        let z = columns.2.xyz
        return float3x3(columns: (x, y, z))
    }
    
    init(projectionFov fov: Float, near: Float, far: Float, aspect: Float, lhs: Bool = true) {
        let y = 1 / tan(fov * 0.5)
        let x = y / aspect
        let z = lhs ? far / (far - near) : far / (near - far)
        let X = float4( x,  0,  0,  0)
        let Y = float4( 0,  y,  0,  0)
        let Z = lhs ? float4( 0,  0,  z, 1) : float4( 0,  0,  z, -1)
        let W = lhs ? float4( 0,  0,  z * -near,  0) : float4( 0,  0,  z * near,  0)
        self.init()
        columns = (X, Y, Z, W)
    }
    
    // left-handed LookAt
    init(eye: simd_float3, center: simd_float3, up: simd_float3) {
        let z = normalize(eye - center)
        let x = normalize(cross(up, z))
        let y = cross(z, x)
        let w = float3(dot(x, -eye), dot(y, -eye), dot(z, -eye))
        
        let X = float4(x.x, y.x, z.x, 0)
        let Y = float4(x.y, y.y, z.y, 0)
        let Z = float4(x.z, y.z, z.z, 0)
        let W = float4(w.x, w.y, x.z, 1)
        self.init()
        columns = (X, Y, Z, W)
    }
    
    init(orthographic rect: Rectangle, near: Float, far: Float) {
        let X = float4(2 / (rect.right - rect.left), 0, 0, 0)
        let Y = float4(0, 2 / (rect.top - rect.bottom), 0, 0)
        let Z = float4(0, 0, 1 / (far - near), 0)
        let W = float4((rect.left + rect.right) / (rect.left - rect.right),
                       (rect.top + rect.bottom) / (rect.bottom - rect.top),
                       near / (near - far),
                       1)
        self.init()
        columns = (X, Y, Z, W)
    }
    
    init(orthoLeft left: Float, right: Float, bottom: Float, top: Float, near: Float, far: Float) {
        let X = float4(2 / (right - left), 0, 0, 0)
        let Y = float4(0, 2 / (top - bottom), 0, 0)
        let Z = float4(0, 0, 1 / (far - near), 0)
        let W = float4((left + right) / (left - right),
                       (top + bottom) / (bottom - top),
                       near / (near - far),
                       1)
        self.init()
        columns = (X, Y, Z, W)
    }
}

extension float3x3 {
    init(normalFrom4x4 matrix: float4x4) {
        self.init()
        columns = matrix.upperLeft().inverse.transpose.columns
    }
}

extension simd_float4 {
    var xyz: simd_float3 {
        get {
            return float3(x, y, z)
        }
        set {
            x = newValue.x
            y = newValue.y
            z = newValue.z
        }
    }
    
    init(_ start: simd_float3, _ end: Float) {
        self.init(start.x, start.y, start.z, end)
    }
}
