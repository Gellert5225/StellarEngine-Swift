//
//  WaterScene.swift
//  ObsidianTest
//
//  Created by Jiahe Li on 23/03/2019.
//  Copyright © 2019 Gellert. All rights reserved.
//

import ObsidianEngine

class WaterScene: OBSDScene {
    override init() {
        super.init()
        setupScene()
    }
    
    func setupScene() {
        skybox = OBSDSkybox(textureName: "sky")
        let water = OBSDWater()
        add(water: water)
        
        let train = OBSDModel(modelName: "train", fragmentFunctionName: "gBufferFragment")
        add(childNode: train)
        train.scale = [2, 2, 2]
        train.position = [0, 0, 5]
        
        camera.position = float3(0, -2, 30)
        camera.rotate(x: -20, y: 0, z: 0)
        camera.fovDegrees = 60
        
        sunLignt.position = float3(100, 50, 50)
        ambientLight.color = [Float(255/255.0), Float(244/255.0), Float(229/255.0)]
        ambientLight.intensity = 0.1
        
        lights.append(sunLignt)
        lights.append(ambientLight)
    }
}
