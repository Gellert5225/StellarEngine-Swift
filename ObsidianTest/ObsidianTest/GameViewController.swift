//
//  GameViewController.swift
//  ObsidianTest
//
//  Created by Gellert on 6/17/18.
//  Copyright © 2018 Gellert. All rights reserved.
//

import UIKit
import ObsidianEngine

class GameViewController: OBSDViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
//        let gameScene = GameScene()
//        scene = gameScene
        
        //let testScene = TestScene()
        //scene = testScene
        
//        let skyScene = SkyScene()
//        scene = skyScene
        
//        let rockScene = RocksScene()
//        scene = rockScene

//        let terrainScene = TerrainScene()
//        scene = terrainScene
        
//        let worldScene = WorldScene()
//        scene = worldScene
        
        let shadowScene = ShadowScene()
        scene = shadowScene
 
        panEnabled = true
        verticalCameraAngleInterval = (-80, -5)
    }
}
