//
//  STLRViewController.swift
//  StellarMacOS
//
//  Created by Gellert Li on 2/13/21.
//  Copyright © 2021 Gellert. All rights reserved.
//

import MetalKit

open class STLRViewControllerMacOS: NSViewController {
    open var scene: STLRScene {
        set {
            renderer.scene = newValue
            renderer.scene?.sceneSizeWillChange(to: self.view.bounds.size)
            print("new scene has been set")
        } get {
            return renderer.scene!
        }
    }
    open var panEnabled: Bool = false {
        didSet {
            if self.panEnabled {
                self.view.addGestureRecognizer(panGesture!)
            } else {
                self.view.removeGestureRecognizer(panGesture!)
            }
        }
    }
    
    open var panSensitivity: Float = 0.005
    
    open var verticalCameraAngleInterval: (min: Float, max: Float) = (-.greatestFiniteMagnitude, .greatestFiniteMagnitude)
    
    var renderer: STLRRenderer!
    var pipelineState: MTLRenderPipelineState!
    var commandQueue: MTLCommandQueue!
    var metalView: MTKView {
        return view as! MTKView
    }
    
    var panGesture: NSPanGestureRecognizer?
    
    override open func viewDidLoad() {
        super.viewDidLoad()

        //metalView.sampleCount = 4
        renderer = STLRRenderer(metalView: metalView)
        panGesture = NSPanGestureRecognizer(target: self, action: #selector(handlePan))
    }
    
    open func add(_ shape: STLRNode) {
        renderer.scene?.add(childNode: shape)
    }
        
    open override func scrollWheel(with event: NSEvent) {
        let sensitivity: Float = 0.1
        scene.camera.position.z += Float(event.deltaY) * sensitivity
    }
    
    @objc func handlePan(recognizer: NSPanGestureRecognizer) {
        let translation = float2(Float(recognizer.translation(in: recognizer.view).x),
                                 Float(recognizer.translation(in: recognizer.view).y))
        
        scene.camera.rotation.x += Float(translation.y) * panSensitivity
        scene.camera.rotation.y -= Float(translation.x) * panSensitivity
        
        recognizer.setTranslation(.zero, in: recognizer.view)
    }
}
