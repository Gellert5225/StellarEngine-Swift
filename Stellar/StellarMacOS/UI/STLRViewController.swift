//
//  STLRViewController.swift
//  StellarMacOS
//
//  Created by Gellert Li on 2/13/21.
//  Copyright © 2021 Gellert. All rights reserved.
//

import MetalKit

open class STLRViewControllerMacOS: NSViewController, NSGestureRecognizerDelegate {
    open var scene: STLRScene {
        set {
            renderer.scene = newValue
            renderer.scene?.sceneSizeWillChange(to: self.view.bounds.size)
            STLRLog.CORE_INFO("New scene has been set")
        } get {
            return renderer.scene!
        }
    }
    open var panEnabled: Bool = false {
        didSet {
            if self.panEnabled {
                panGesture?.delegate = self
                self.metalView.addGestureRecognizer(panGesture!)
            } else {
                self.metalView.removeGestureRecognizer(panGesture!)
            }
        }
    }
    
    open var panSensitivity: Float = 0.005
    
    open var verticalCameraAngleInterval: (min: Float, max: Float) = (-.greatestFiniteMagnitude, .greatestFiniteMagnitude)
    
    var renderer: STLRRenderer!
    var pipelineState: MTLRenderPipelineState!
    var commandQueue: MTLCommandQueue!
    open var metalView: MTKView!
    
    var panGesture: NSPanGestureRecognizer?
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        STLRLog.delegate = self
        //metalView.sampleCount = 4
        renderer = STLRRenderer(metalView: metalView)
        panGesture = NSPanGestureRecognizer(target: self, action: #selector(handlePan))
    }
        
    open override func scrollWheel(with event: NSEvent) {
        //let sensitivity: Float = 0.1
        scene.camera.zoom(delta: Float(event.deltaY))
    }
    
    @objc func handlePan(recognizer: NSPanGestureRecognizer) {
        let translation = recognizer.translation(in: recognizer.view)
        let delta = float2(Float(translation.x), Float(translation.y))
        
        scene.camera.rotate(delta: delta)
        recognizer.setTranslation(.zero, in: recognizer.view)
    }
    
    public func gestureRecognizer(_ gestureRecognizer: NSGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: NSGestureRecognizer) -> Bool {
        return true
    }
    
    public func gestureRecognizer(_ gestureRecognizer: NSGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: NSGestureRecognizer) -> Bool {
        return true
    }
}

extension STLRViewControllerMacOS: STLRLogDelegate {
    @objc open func flushToConsole() {
        
    }
}
