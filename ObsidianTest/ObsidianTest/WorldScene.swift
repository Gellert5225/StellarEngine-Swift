//
//  WorldScene.swift
//  ObsidianTest
//
//  Created by Jiahe Li on 17/03/2019.
//  Copyright © 2019 Gellert. All rights reserved.
//

import ObsidianEngine

class WorldScene: OBSDScene {
    var light: Light!
    
    override init() {
        super.init()
        setupScene()
    }
    
    func setupScene() {
        skybox = OBSDSkybox(textureName: nil)
        let landscape = OBSDModel(modelName: "Cartoon_lowpoly_landscape_scene_obj", fragmentFunctionName: "fragment_IBL")
        add(childNode: landscape)
        
        landscape.scale = [0.01, 0.01, 0.01]
        
        camera.position = float3(0, 0, 30)
        camera.rotate(x: 0, y: 0, z: 0)
        camera.fovDegrees = 60
        
        light = buildDefaultLight()
        
        light.position = float3(100, 200, -200)
        light.intensity = 0.5
        lights.append(light)
        lights.append(ambientLight)
    }
}

