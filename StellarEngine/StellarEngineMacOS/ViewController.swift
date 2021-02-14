//
//  ViewController.swift
//  StellarEngineMacOS
//
//  Created by Gellert Li on 2/13/21.
//  Copyright © 2021 Gellert. All rights reserved.
//

import Cocoa
import StellarMacOS
import MetalKit

class HomeViewController: STLRViewControllerMacOS, NSSplitViewDelegate {
    var renderer: STLRRenderer?
        
    @IBOutlet weak var consoleSplitView: NSSplitView!
    @IBOutlet weak var navigationSplitView: NSSplitView!
    @IBOutlet weak var mtkView: MTKView!
    override func viewDidLoad() {
        metalView = mtkView
        super.viewDidLoad()
        //self.view.window?.setFrame(NSRect(x:0,y:0,width: 1280,height: 720), display: true)
        consoleSplitView.delegate = self
        navigationSplitView.delegate = self
        
        let testScene = TestScene()
        scene = testScene
        
        panEnabled = true
        verticalCameraAngleInterval = (-80, -5)
    }

}

