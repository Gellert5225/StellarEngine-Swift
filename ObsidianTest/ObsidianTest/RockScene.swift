//
//  RockScene.swift
//  ObsidianTest
//
//  Created by Jiahe Li on 15/03/2019.
//  Copyright © 2019 Gellert. All rights reserved.
//

import ObsidianEngine

class RocksScene: OBSDScene {
    let ground = OBSDModel(modelName: "large-plane")
    var light: Light!
    
    override init() {
        super.init()
        setupScene()
    }
    
    func setupScene() {
        skybox = OBSDSkybox(textureName: nil)
        ground.tiling = 16
        add(childNode: ground)

        setUpRocks()
        setUpGrass()
        setUpTree()
        //setUpCar()
        
        setUpCameraAndLights()
    }
    
    func setUpCameraAndLights() {
        camera.position = float3(0, 0, 30)
        camera.rotate(x: 0, y: 0, z: 0)
        camera.fovDegrees = 30
        
        light = buildDefaultLight()
        
        light.position = float3(100, 50, -50)
        light.intensity = 0.5
        lights.append(light)
        lights.append(ambientLight)
    }
    
    func setUpCar() {
        let car = OBSDModel(modelName: "racing-car", fragmentFunctionName: "fragment_IBL")
        car.scale = [1.5, 1.5, 1.5]
        car.position = [7, 0, 0]
        
        add(childNode: car)
    }
    
    func setUpRocks() {
        let rockInstanceCount = 25
        let textureNames = ["rock1-color", "rock2-color", "rock3-color"]
        let morphTargetNames = ["rock1", "rock2", "rock3"]
        let rocks = OBSDMorph(name: "Rocks", instanceCount: rockInstanceCount,
                              textureNames: textureNames,
                              morphTargetNames: morphTargetNames)
        add(childNode: rocks)
        for i in 0..<rockInstanceCount {
            var transform = Transform()
            transform.position.x = .random(in: -10..<10)
            transform.position.z = .random(in: 0..<5)
            transform.rotation.y = .random(in: -Float.pi..<Float.pi)
            let textureID = Int.random(in: 0..<textureNames.count)
            let morphTargetID = Int.random(in: 0..<morphTargetNames.count)
            rocks.updateBuffer(instance: i, transform: transform, textureID: textureID, morphtargetID: morphTargetID)
        }
    }
    
    func setUpGrass() {
        let grassInstanceCount = 400000
        var textureNames: [String] = []
        for i in 1...7 {
            textureNames.append("grass" + String(format: "%02d", i))
        }
        let morphCount = 4
        var morphTargetNames: [String] = []
        for i in 1...morphCount {
            morphTargetNames.append("grass" + String(format: "%02d", i))
        }
        
        let grass = OBSDMorph(name: "grass", instanceCount: grassInstanceCount, textureNames: textureNames, morphTargetNames: morphTargetNames)
        add(childNode: grass)
        for i in 0..<grassInstanceCount {
            var transform = Transform()
            transform.position.x = .random(in: -40..<40)
            transform.position.z = .random(in: -40..<40)
            transform.rotation.y = .random(in: -Float.pi..<Float.pi)
            let textureID = Int.random(in: 0..<textureNames.count)
            let morphTargetID = Int.random(in: 0..<morphTargetNames.count)
            grass.updateBuffer(instance: i, transform: transform, textureID: textureID, morphtargetID: morphTargetID)
        }
    }
    
    func setUpTree() {
        let tree = OBSDModel(modelName: "tree", instanceCount: 25)
        add(childNode: tree)
        
        for i in 0..<25 {
            var transform = Transform()
            transform.position.x = .random(in: -10..<10)
            transform.position.z = .random(in: -10..<10)
            transform.rotation.y = .random(in: -Float.pi..<Float.pi)
            tree.updateBuffer(instance: i, transform: transform)
        }
    }
}
