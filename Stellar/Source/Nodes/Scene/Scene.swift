//
//  STLRScene.swift
//  ObsidianEngine
//
//  Created by Gellert on 6/18/18.
//  Copyright © 2018 Gellert. All rights reserved.
//

import MetalKit

open class STLRScene {
    
    public static var delegate: STLRSceneDelegate?
    
    open var name: String = "Untitled Scene"
    open var camera = STLRArcballCamera()
    open var lights = [STLRLight]()
    open var skybox: STLRSkybox?
    open var terrains: [STLRTerrain] = []
    open var waters: [STLRWater] = []
    open var renderables: [Renderable] = []
    open var rootNode = STLRNode()
    
    open var sunLignt: STLRLight = {
        var light = STLRLight()
        light.position = [1, 2, -2]
        light.color = [1, 1, 1]
        light.specularColor = [1, 1, 1]
        light.intensity = 0.7
        light.type = Sunlight
        return light
    }()
    
    open lazy var ambientLight: STLRLight = {
        var light = buildDefaultLight()
        light.color = [0.7, 0.7, 0.7]
        light.specularColor = [0.7, 0.7, 0.7]
        light.intensity = 0.5
        light.type = Ambientlight
        return light
    }()
    
    var lightConstants = STLRLightConstants()
    var uniforms = STLRUniforms()
    var fragmentUniforms = STLRFragmentUniforms()
    var axis: STLRModel?
    
    var reflectionCamera = STLRArcballCamera()
    
    open var fps: Int {
        didSet {
            STLRScene.delegate?.updpateFPS()
        }
    }
    
    public init(name: String = "Untitled Scene") {
        self.name = name
        self.rootNode.name = name
        self.fps = 60
        
        //self.cameraType = cameraType
        add(node: camera, render: false)
        camera.transform.position = [10, 2, 35]
    }
    
    /// update the scene every deltaTime seconds
    open func updateScene(deltaTime: Float) {
        // override this to update your scene
    }
    
    open func add(terrain: STLRTerrain) {
        terrains.append(terrain)
        add(node: terrain)
    }
    
    open func add(water: STLRWater) {
        waters.append(water)
        add(node: water)
    }
    
    open func add(node: STLRNode, parent: STLRNode? = nil, render: Bool = true) {
        if let parent = parent {
            parent.add(childNode: node)
        } else {
            rootNode.add(childNode: node)
        }
        guard render == true,
              let renderable = node as? Renderable else {
                return
        }
        renderables.append(renderable)
    }
    
    open func remove(node: STLRNode) {
        if let parent = node.parent {
            parent.remove(childNode: node)
        } else {
            for child in node.children {
                child.parent = nil
            }
            node.children = []
        }
        guard node is Renderable,
              let index = (renderables.firstIndex {
                $0 as? STLRNode === node
              }) else { return }
        renderables.remove(at: index)
    }
    
    public func buildDefaultLight() -> STLRLight {
        var light = STLRLight()
        light.position = [0, 0, 0]
        light.color = [1, 1, 1]
        light.specularColor = [1, 1, 1]
        light.intensity = 1
        light.attenuation = float3(1, 0, 0)
        light.type = Sunlight
        return light
    }
    
    public func sceneSizeWillChange(to size: CGSize) {
        camera.aspect = Float(size.width / size.height)
    }
    
    final func update(deltaTime: Float) {
        uniforms.projectionMatrix = camera.projectionMatrix
        uniforms.cameraPosition = camera.transform.position
        uniforms.viewMatrix = camera.viewMatrix
        //    fragmentUniforms.cameraPosition = camera.position
        updateScene(deltaTime: deltaTime)
        update(nodes: rootNode.children, deltaTime: deltaTime)
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
}

public protocol STLRSceneDelegate {
    func updpateFPS()
}
