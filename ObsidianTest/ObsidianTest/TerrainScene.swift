//
//  TerrainScene.swift
//  ObsidianTest
//
//  Created by Jiahe Li on 16/03/2019.
//  Copyright © 2019 Gellert. All rights reserved.
//

import ObsidianEngine

class TerrainScene: OBSDScene {
    var light: Light!
    
    override init() {
        super.init()
        setupScene()
    }
    
    func setupScene() {
        skybox = OBSDSkybox(textureName: nil)
        
        let terrain = OBSDTerrain(withSize: [8, 8], heightScale: 1, heightTexture: "mountain", cliffTexture: "cliff-color", snowTexture: "snow-color", grassTexture: "grass-color")
        
        terrains.append(terrain)
        add(childNode: terrain)
        
        camera.position = float3(0, 0, 4)
        camera.rotate(x: 0, y: 0, z: 0)
        camera.fovDegrees = 60
        
        light = buildDefaultLight()
        
        light.position = float3(100, 50, -50)
        light.intensity = 0.5
        lights.append(light)
        lights.append(ambientLight)
    }
}
