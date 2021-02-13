//
//  SkyScene.swift
//  ObsidianEngine
//
//  Created by Jiahe Li on 06/03/2019.
//  Copyright © 2019 Gellert. All rights reserved.
//

import StellariOS

class SkyScene: STLRScene {
    let ground = STLRModel(modelName: "large-plane", fragmentFunctionName: "gBufferFragment")
    let car = STLRModel(modelName: "racing-car", fragmentFunctionName: "gBufferFragment")
    let chest = STLRModel(modelName: "chest", fragmentFunctionName: "gBufferFragment")
    let train = STLRModel(modelName: "train", fragmentFunctionName: "gBufferFragment")
    let cottage = STLRModel(modelName: "cottage1", fragmentFunctionName: "gBufferFragment")
    let mouse = STLRModel(modelName: "MagicMouse", fragmentFunctionName: "gBufferFragment_IBL")
    var light: Light!
    
    override init() {
        super.init()
        setupScene()
    }
    
    func setupScene() {
        skybox = STLRSkybox(textureName: "sky")
        ground.tiling = 16
        add(childNode: ground)
        add(childNode: car)
        add(childNode: cottage)
        add(childNode: train)
        add(childNode: chest)
        add(childNode: mouse)
        
        mouse.scale = [0.1, 0.1, 0.1]
        mouse.position = [0, 0, -10]
        
        car.scale = [1.5, 1.5, 1.5]
        car.position = [7, 0, 0]
        
        train.scale = [4, 4, 4]
        train.position = [0, 0, 10]
        
        chest.position = [-7, 0, 0]
        
        camera.position = float3(0, 0, 30)
        camera.rotate(x: 0, y: 0, z: 0)
        camera.fovDegrees = 60
        
        light = buildDefaultLight()
        
        sunLignt.position = float3(100, 50, -50)
        sunLignt.intensity = 0.7
        ambientLight.color = [Float(255/255.0), Float(244/255.0), Float(229/255.0)]
        ambientLight.intensity = 0.5
        lights.append(sunLignt)
        lights.append(ambientLight)
    }
}
