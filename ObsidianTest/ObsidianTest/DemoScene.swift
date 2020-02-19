//
//  DemoScene.swift
//  ObsidianTest
//
//  Created by Jiahe Li on 24/03/2019.
//  Copyright © 2019 Gellert. All rights reserved.
//

import ObsidianEngine

class DemoScene: OBSDScene {
    override init() {
        super.init()
        setupScene()
    }
    
    func setupScene() {
        skybox = OBSDSkybox(textureName: nil)
        //skybox?.skySettings = OBSDSkybox.MidDay
        
        let water = OBSDWater()
        add(water: water)
        
        let ground = OBSDModel(modelName: "plane", fragmentFunctionName: "gBufferFragment")
        ground.scale = [10, 10, 10]
        ground.position.y = 1;
        //add(childNode: ground)
        
        let train = OBSDModel(modelName: "train", fragmentFunctionName: "gBufferFragment")
        add(childNode: train)
        train.scale = [2, 2, 2]
        train.position = [0, 1, 5]
        
        let oil = OBSDModel(modelName: "Oil", fragmentFunctionName: "gBufferFragment")
        add(childNode: oil)
        oil.position = [0, 3.2, -5]
        
        let mouse = OBSDModel(modelName: "MagicMouse", fragmentFunctionName: "gBufferFragment_IBL")
        add(childNode: mouse)
        mouse.scale = [0.05, 0.05, 0.05]
        mouse.position = [-6, 1, 0]
        
        let car = OBSDModel(modelName: "racing-car", fragmentFunctionName: "gBufferFragment")
        car.scale = [1.5, 1.5, 1.5]
        car.position = [6, 1, 0]
        add(childNode: car)
        
        camera.position = float3(0, -2, 20)
        camera.rotate(x: -20, y: 0, z: 0)
        camera.fovDegrees = 80
        
        sunLignt.position = float3(-10, 30, -10)
        sunLignt.intensity = 1.0
        ambientLight.color = [Float(255/255.0), Float(244/255.0), Float(229/255.0)]
        ambientLight.intensity = 0.01
        //createPointLights(count: 40, min: [-8, 0.5, -8], max: [8, 4, 8])
        
        lights.append(sunLignt)
        lights.append(ambientLight)
    }
    
    override func updateScene(deltaTime: Float) {
        for (index, child) in children.enumerated() {
            if (index != 0 ) { child.rotation.y += 0.01 }
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
            light.intensity = 1.0
            light.attenuation = float3(0.4, 0.4, 0.4)
            lights.append(light)
        }
    }
    
}
