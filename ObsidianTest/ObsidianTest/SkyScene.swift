//
//  SkyScene.swift
//  ObsidianEngine
//
//  Created by Jiahe Li on 06/03/2019.
//  Copyright © 2019 Gellert. All rights reserved.
//

import ObsidianEngine

class SkyScene: OBSDScene {
    let ground = OBSDModel(modelName: "large-plane", fragmentFunctionName: "fragment_PBR")
    let car = OBSDModel(modelName: "racing-car", fragmentFunctionName: "fragment_PBR")
    let chest = OBSDModel(modelName: "chest", fragmentFunctionName: "fragment_PBR")
    let train = OBSDModel(modelName: "train", fragmentFunctionName: "fragment_PBR")
    let cottage = OBSDModel(modelName: "cottage1", fragmentFunctionName: "fragment_PBR")
    var light: Light!
    
    override init() {
        super.init()
        setupScene()
    }
    
    func setupScene() {
        skybox = OBSDSkybox(textureName: "sky")
        ground.tiling = 16
        add(childNode: ground)
        add(childNode: car)
        add(childNode: cottage)
        add(childNode: train)
        add(childNode: chest)
        
        car.scale = [1.5, 1.5, 1.5]
        car.position = [7, 0, 0]
        
        train.scale = [4, 4, 4]
        train.position = [0, 0, 10]
        
        chest.position = [-7, 0, 0]
        
        camera.position = float3(0, 0, 30)
        camera.rotate(x: 0, y: 0, z: 0)
        camera.fovDegrees = 60
        
        light = buildDefaultLight()
        
        light.position = float3(100, 50, -50)
        light.intensity = 0.5
        ambientLight.color = [Float(255/255.0), Float(244/255.0), Float(229/255.0)]
        ambientLight.intensity = 0.5
        lights.append(light)
        lights.append(ambientLight)
    }
}
