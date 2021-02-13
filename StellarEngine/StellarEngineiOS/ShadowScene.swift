//
//  ShadowScene.swift
//  ObsidianTest
//
//  Created by Jiahe Li on 17/03/2019.
//  Copyright © 2019 Gellert. All rights reserved.
//

import StellariOS

class ShadowScene: STLRScene {
    override init() {
        super.init()
        setupScene()
    }
    
    func setupScene() {
        skybox = STLRSkybox(textureName: "sky")
        let ground = STLRModel(modelName: "plane", fragmentFunctionName: "gBufferFragment")
        ground.scale = [10, 10, 10]
        add(childNode: ground)
        
        let train = STLRModel(modelName: "train", fragmentFunctionName: "gBufferFragment")
        add(childNode: train)
        train.scale = [2, 2, 2]
        train.position = [0, 0, 5]
        
        let chest = STLRModel(modelName: "chest", fragmentFunctionName: "gBufferFragment")
        add(childNode: chest)
        chest.position = [0, 0, -5]
        chest.scale = [2, 2, 2]
        
        let mouse = STLRModel(modelName: "MagicMouse", fragmentFunctionName: "gBufferFragment_IBL")
        add(childNode: mouse)
        mouse.scale = [0.05, 0.05, 0.05]
        mouse.position = [-6, 0, 0]
        
        let car = STLRModel(modelName: "racing-car", fragmentFunctionName: "gBufferFragment")
        car.scale = [1.5, 1.5, 1.5]
        car.position = [6, 0, 0]
        add(childNode: car)
        
        camera.position = float3(0, -2, 30)
        camera.rotate(x: -50, y: 0, z: 0)
        camera.fovDegrees = 60
        
        sunLignt.position = float3(100, 50, 50)
        ambientLight.color = [Float(255/255.0), Float(244/255.0), Float(229/255.0)]
        ambientLight.intensity = 0.1
        
        lights.append(sunLignt)
        createPointLights(count: 40, min: [-8, 0.5, -8], max: [8, 4, 8])
        lights.append(ambientLight)
    }
    
    override func updateScene(deltaTime: Float) {
        for (index, child) in children.enumerated() {
            if (index != 0) { child.rotation.y += 0.01 }
        }
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
        let newMin: float3 = [min.x*100, min.y*100, min.z*100]
        let newMax: float3 = [max.x*100, max.y*100, max.z*100]
        for _ in 0..<count {
            var light = buildDefaultLight()
            light.type = Pointlight
            let x = Float(random(range: Int(newMin.x)...Int(newMax.x))) * 0.01
            let y = Float(random(range: Int(newMin.y)...Int(newMax.y))) * 0.01
            let z = Float(random(range: Int(newMin.z)...Int(newMax.z))) * 0.01
            light.position = [x, y, z]
            light.color = colors[random(range: 0...colors.count)]
            light.intensity = 5.0
            light.attenuation = float3(0.4, 0.4, 0.4)
            lights.append(light)
        }
    }
}
