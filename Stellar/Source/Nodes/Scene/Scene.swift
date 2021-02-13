//
//  STLRScene.swift
//  ObsidianEngine
//
//  Created by Gellert on 6/18/18.
//  Copyright © 2018 Gellert. All rights reserved.
//

import MetalKit

open class STLRScene: STLRNode {
    
    open var camera = STLRCamera()
    open var lights = [Light]()
    open var skybox: STLRSkybox?
    open var terrains: [STLRTerrain] = []
    open var waters: [STLRWater] = []
    open var sunLignt: Light = {
        var light = Light()
        light.position = [1, 2, -2]
        light.color = [1, 1, 1]
        light.specularColor = [1, 1, 1]
        light.intensity = 0.7
        light.type = Sunlight
        return light
    }()
    public let rootNode = STLRNode()
    
    var lightConstants = STLRLightConstants()
    var uniforms = STLRUniforms()
    var fragmentUniforms = STLRFragmentUniforms()
    
    var reflectionCamera = STLRCamera()
    
    var fps: Int?
    
    open lazy var ambientLight: Light = {
        var light = buildDefaultLight()
        light.color = [0.7, 0.7, 0.7]
        light.specularColor = [0.7, 0.7, 0.7]
        light.intensity = 0.5
        light.type = Ambientlight
        return light
    }()
    
    public override init() {
        camera.currentPosition = camera.position
    }
    
    public func buildDefaultLight() -> Light {
        var light = Light()
        light.position = [0, 0, 0]
        light.color = [1, 1, 1]
        light.specularColor = [1, 1, 1]
        light.intensity = 1
        light.attenuation = float3(1, 0, 0)
        light.type = Sunlight
        return light
    }
    
    final func update(deltaTime: Float) {
        uniforms.projectionMatrix = camera.projectionMatrix
        uniforms.viewMatrix = camera.viewMatrix
        //    fragmentUniforms.cameraPosition = camera.position
        updateScene(deltaTime: deltaTime)
        update(nodes: children, deltaTime: deltaTime)
        // precompute terrain tessellation
        for terrain in terrains {
            terrain.update(viewMatrix: uniforms.viewMatrix)
        }
    }
    
    private func update(nodes: [STLRNode], deltaTime: Float) {
        nodes.forEach { node in
            update(nodes: node.children, deltaTime: deltaTime)
        }
    }
    
    open func updateScene(deltaTime: Float) {
        // override this to update your scene
    }
    
    open func add(terrain: STLRTerrain) {
        terrains.append(terrain)
        add(childNode: terrain)
    }
    
    open func add(water: STLRWater) {
        waters.append(water)
        add(childNode: water)
    }
}
