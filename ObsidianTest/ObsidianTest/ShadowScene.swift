//
//  ShadowScene.swift
//  ObsidianTest
//
//  Created by Jiahe Li on 17/03/2019.
//  Copyright © 2019 Gellert. All rights reserved.
//

import ObsidianEngine

class ShadowScene: OBSDScene {
    override init() {
        super.init()
        setupScene()
    }
    
    func setupScene() {
        skybox = OBSDSkybox(textureName: nil)
        let ground = OBSDModel(modelName: "plane", fragmentFunctionName: "lit_textured_fragment")
        ground.scale = [10, 10, 10]
        add(childNode: ground)
        
        let train = OBSDModel(modelName: "train", fragmentFunctionName: "fragment_PBR")
        add(childNode: train)
        train.scale = [2, 2, 2]
        
        let car = OBSDModel(modelName: "racing-car", fragmentFunctionName: "fragment_PBR")
        car.scale = [1.5, 1.5, 1.5]
        car.position = [7, 0, 0]
        add(childNode: car)
        
        camera.position = float3(0, 0, 30)
        camera.rotate(x: 0, y: 0, z: 0)
        camera.fovDegrees = 60
        
        sunLignt.position = float3(10, 15, -5)
        ambientLight.color = [Float(255/255.0), Float(244/255.0), Float(229/255.0)]
        ambientLight.intensity = 0.5
        
        lights.append(sunLignt)
        createPointLights(count: 40, min: [-15, 1.5, -15], max: [5, 2, 10])
        lights.append(ambientLight)
    }
    
    func random(range: CountableClosedRange<Int>) -> Int {
        var offset = 0
        if range.lowerBound < 0 {
            offset = abs(range.lowerBound)
        }
        let min = UInt32(range.lowerBound + offset)
        let max = UInt32(range.upperBound + offset)
        return Int(min + arc4random_uniform(max-min)) - offset
    }
    
    func createPointLights(count: Int, min: float3, max: float3) {
        let colors: [float3] = [
            float3(1, 0, 0),
            float3(1, 1, 0),
            float3(1, 1, 1),
            float3(0, 1, 0),
            float3(0, 1, 1),
            float3(0, 0, 1),
            float3(0, 1, 1),
            float3(1, 0, 1) ]
        var newMin: float3 = [min.x*100, min.y*100, min.z*100]
        var newMax: float3 = [max.x*100, max.y*100, max.z*100]
        for _ in 0..<count {
            var light = buildDefaultLight()
            light.type = Pointlight
            let x = Float(random(range: Int(newMin.x)...Int(newMax.x))) * 0.01
            let y = Float(random(range: Int(newMin.y)...Int(newMax.y))) * 0.01
            let z = Float(random(range: Int(newMin.z)...Int(newMax.z))) * 0.01
            light.position = [x, y, z]
            light.color = colors[random(range: 0...colors.count)]
            light.intensity = 0.6
            light.attenuation = float3(1.5, 1, 1)
            lights.append(light)
        }
    }
}
