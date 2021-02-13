//
//  HouseScene.swift
//  ObsidianTest
//
//  Created by Jiahe Li on 16/03/2019.
//  Copyright © 2019 Gellert. All rights reserved.
//

import StellariOS

class HouseScene: STLRScene {
    let ground = STLRModel(modelName: "large-plane")
    var light: Light!
    
    override init() {
        super.init()
        setupScene()
    }
    
    func setupScene() {
        skybox = STLRSkybox(textureName: nil)
        ground.tiling = 16
        add(childNode: ground)
        
        
        
        camera.position = float3(0, 0, 30)
        camera.rotate(x: 0, y: 0, z: 0)
        camera.fovDegrees = 60
        
        light = buildDefaultLight()
        
        light.position = float3(100, 50, -50)
        light.intensity = 0.5
        lights.append(light)
        lights.append(ambientLight)
    }
}
