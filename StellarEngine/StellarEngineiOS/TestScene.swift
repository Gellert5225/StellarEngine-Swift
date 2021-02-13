//
//  TestScene.swift
//  ObsidianTest
//
//  Created by Gellert on 6/18/18.
//  Copyright © 2018 Gellert. All rights reserved.
//

import StellariOS

class TestScene: STLRScene {
    
    var light: Light!
    
    override init() {
        super.init()
        
        let cottage = STLRModel(modelName: "racing-car")
        
        cottage.scale = [2, 2, 2]
        cottage.rotate(x: 0, y: 90, z: 0)
        
        
//        cottage.shininess = 2.0
//        cottage.specularIntensity = 0.2
        
        add(childNode: cottage)
        
        camera.position = float3(0, 0, -30)
        camera.rotate(x: 0, y: 0, z: 0)
        camera.fovDegrees = 30
        
        light = buildDefaultLight()
                
        light.position = float3(50, 100, 10)
        light.intensity = 0.5
        lights.append(light)
        lights.append(ambientLight)
    }
    
}
