//
//  ViewController.swift
//  StellarEngineMacOS
//
//  Created by Gellert Li on 2/13/21.
//  Copyright © 2021 Gellert. All rights reserved.
//

import Cocoa
import StellarMacOS

class HomeViewController: STLRViewControllerMacOS {
    var renderer: STLRRenderer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //self.view.window?.setFrame(NSRect(x:0,y:0,width: 1280,height: 720), display: true)
        
        let testScene = TestScene()
        scene = testScene
        
        panEnabled = true
        verticalCameraAngleInterval = (-80, -5)
        
    }

}

