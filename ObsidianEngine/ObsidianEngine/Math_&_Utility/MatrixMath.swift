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

public func modulus(vector: float3) -> Float {
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
    init(translation: float3) {
        self = matrix_identity_float4x4
        columns.3.x = translation.x
        columns.3.y = translation.y
        columns.3.z = translation.z
    }
    
    init(scaling: float3) {
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
    
    init(rotation angle: float3) {
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
    init(eye: float3, center: float3, up: float3) {
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

extension float4 {
    var xyz: float3 {
        get {
            return float3(x, y, z)
        }
        set {
            x = newValue.x
            y = newValue.y
            z = newValue.z
        }
    }
    
    init(_ start: float3, _ end: Float) {
        self.init(start.x, start.y, start.z, end)
    }
}

//extension Float {
//  var radiansToDegrees: Float {
//    return (self / π) * 180
//  }
//  var degreesToRadians: Float {
//    return (self / 180) * π
//  }
//}
//
//extension matrix_float4x4 {
//    init(translationX x: Float, y: Float, z: Float) {
//        self.init()
//        columns = (
//          float4( 1,  0,  0,  0),
//          float4( 0,  1,  0,  0),
//          float4( 0,  0,  1,  0),
//          float4( x,  y,  z,  1)
//        )
//      }
//
//    init(rotationX angle: Float) {
//        self = matrix_identity_float4x4
//        columns.1.y = cos(angle)
//        columns.1.z = sin(angle)
//        columns.2.y = -sin(angle)
//        columns.2.z = cos(angle)
//    }
//
//    init(rotationY angle: Float) {
//        self = matrix_identity_float4x4
//        columns.0.x = cos(angle)
//        columns.0.z = -sin(angle)
//        columns.2.x = sin(angle)
//        columns.2.z = cos(angle)
//    }
//
//    init(rotationZ angle: Float) {
//        self = matrix_identity_float4x4
//        columns.0.x = cos(angle)
//        columns.0.y = sin(angle)
//        columns.1.x = -sin(angle)
//        columns.1.y = cos(angle)
//    }
//
//    init(translation: float3) {
//        self = matrix_identity_float4x4
//        columns.3.x = translation.x
//        columns.3.y = translation.y
//        columns.3.z = translation.z
//    }
//
//    init(scaling: float3) {
//        self = matrix_identity_float4x4
//        columns.0.x = scaling.x
//        columns.1.y = scaling.y
//        columns.2.z = scaling.z
//    }
//
//    init(scaling: Float) {
//        self = matrix_identity_float4x4
//        columns.3.w = 1 / scaling
//    }
//
//    init(rotation angle: float3) {
//        let rotationX = float4x4(rotationX: angle.x)
//        let rotationY = float4x4(rotationY: angle.y)
//        let rotationZ = float4x4(rotationZ: angle.z)
//        self = rotationX * rotationY * rotationZ
//    }
//
//      func translatedBy(x: Float, y: Float, z: Float) -> matrix_float4x4 {
//        let translateMatrix = matrix_float4x4(translationX: x, y: y, z: z)
//        return matrix_multiply(self, translateMatrix)
//      }
//
//      init(scaleX x: Float, y: Float, z: Float) {
//        self.init()
//        columns = (
//          float4( x,  0,  0,  0),
//          float4( 0,  y,  0,  0),
//          float4( 0,  0,  z,  0),
//          float4( 0,  0,  0,  1)
//        )
//      }
//
//      func scaledBy(x: Float, y: Float, z: Float) -> matrix_float4x4 {
//        let scaledMatrix = matrix_float4x4(scaleX: x, y: y, z: z)
//        return matrix_multiply(self, scaledMatrix)
//      }
//
//      // angle should be in radians
//      init(rotationAngle angle: Float, x: Float, y: Float, z: Float) {
//        let c = cos(angle)
//        let s = sin(angle)
//
//        var column0 = float4(0)
//        column0.x = x * x + (1 - x * x) * c
//        column0.y = x * y * (1 - c) - z * s
//        column0.z = x * z * (1 - c) + y * s
//        column0.w = 0
//
//        var column1 = float4(0)
//        column1.x = x * y * (1 - c) + z * s
//        column1.y = y * y + (1 - y * y) * c
//        column1.z = y * z * (1 - c) - x * s
//        column1.w = 0.0
//
//        var column2 = float4(0)
//        column2.x = x * z * (1 - c) - y * s
//        column2.y = y * z * (1 - c) + x * s
//        column2.z = z * z + (1 - z * z) * c
//        column2.w = 0.0
//
//        let column3 = float4(0, 0, 0, 1)
//
//        self.init()
//        columns = (
//          column0, column1, column2, column3
//        )
//      }
//
//      func rotatedBy(rotationAngle angle: Float,
//                     x: Float, y: Float, z: Float) -> matrix_float4x4 {
//        let rotationMatrix = matrix_float4x4(rotationAngle: angle,
//                                             x: x, y: y, z: z)
//        return matrix_multiply(self, rotationMatrix)
//      }
//
//      init(projectionFov fov: Float, aspect: Float, nearZ: Float, farZ: Float) {
//        let y = 1 / tan(fov * 0.5)
//        let x = y / aspect
//        let z = farZ / (nearZ - farZ)
//        self.init()
//        columns = (
//          float4( x,  0,  0,  0),
//          float4( 0,  y,  0,  0),
//          float4( 0,  0,  z, -1),
//          float4( 0,  0,  z * nearZ,  0)
//        )
//      }
//
//      func upperLeft3x3() -> matrix_float3x3 {
//        return (matrix_float3x3(columns: (
//          float3(columns.0.x, columns.0.y, columns.0.z),
//          float3(columns.1.x, columns.1.y, columns.1.z),
//          float3(columns.2.x, columns.2.y, columns.2.z)
//        )))
//      }
//}
//
//extension matrix_float4x4: CustomReflectable {
//
//  public var customMirror: Mirror {
//    let c00 = String(format: "%  .4f", columns.0.x)
//    let c01 = String(format: "%  .4f", columns.0.y)
//    let c02 = String(format: "%  .4f", columns.0.z)
//    let c03 = String(format: "%  .4f", columns.0.w)
//
//    let c10 = String(format: "%  .4f", columns.1.x)
//    let c11 = String(format: "%  .4f", columns.1.y)
//    let c12 = String(format: "%  .4f", columns.1.z)
//    let c13 = String(format: "%  .4f", columns.1.w)
//
//    let c20 = String(format: "%  .4f", columns.2.x)
//    let c21 = String(format: "%  .4f", columns.2.y)
//    let c22 = String(format: "%  .4f", columns.2.z)
//    let c23 = String(format: "%  .4f", columns.2.w)
//
//    let c30 = String(format: "%  .4f", columns.3.x)
//    let c31 = String(format: "%  .4f", columns.3.y)
//    let c32 = String(format: "%  .4f", columns.3.z)
//    let c33 = String(format: "%  .4f", columns.3.w)
//
//
//    let children = DictionaryLiteral<String, Any>(dictionaryLiteral:
//      (" ", "\(c00) \(c01) \(c02) \(c03)"),
//      (" ", "\(c10) \(c11) \(c12) \(c13)"),
//      (" ", "\(c20) \(c21) \(c22) \(c23)"),
//      (" ", "\(c30) \(c31) \(c32) \(c33)")
//    )
//    return Mirror(matrix_float4x4.self, children: children)
//  }
//}
//
//extension float4: CustomReflectable {
//
//  public var customMirror: Mirror {
//    let sx = String(format: "%  .4f", x)
//    let sy = String(format: "%  .4f", y)
//    let sz = String(format: "%  .4f", z)
//    let sw = String(format: "%  .4f", w)
//
//    let children = DictionaryLiteral<String, Any>(dictionaryLiteral:
//      (" ", "\(sx) \(sy) \(sz) \(sw)")
//    )
//    return Mirror(float4.self, children: children)
//  }
//}
//
//extension float3x3 {
//    init(normalFrom4x4 matrix: float4x4) {
//        self.init()
//        columns = matrix.upperLeft3x3().inverse.transpose.columns
//    }
//
//    init(rotation angle: float3) {
//        self.init()
//        columns = (
//            float3(cos(angle.y), sin(angle.x) * sin(angle.y), -cos(angle.x) * sin(angle.y)),
//            float3(0, cos(angle.x), sin(angle.x)),
//            float3(sin(angle.y), -sin(angle.x) * cos(angle.y), cos(angle.x) * cos(angle.y))
//        )
//    }
//}

