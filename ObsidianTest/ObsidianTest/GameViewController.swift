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
    
    var demoScene: DemoScene?
    
    @IBAction func changeSkySettings(_ sender: UIButton) {
        if (sender.currentTitle! == "SunRise") {
            demoScene?.skybox?.skySettings = OBSDSkybox.SunRise
        } else if (sender.currentTitle! == "SunSet") {
            demoScene?.skybox?.skySettings = OBSDSkybox.SunSet
        } else if (sender.currentTitle! == "MidDay") {
            demoScene?.skybox?.skySettings = OBSDSkybox.MidDay
        } else if (sender.currentTitle! == "Planet") {
            demoScene?.skybox = OBSDSkybox(textureName: "sky")
        }
    }
    
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
//
//        let shadowScene = ShadowScene()
//        scene = shadowScene
//
//        let waterScene = WaterScene()
//        scene = waterScene

        demoScene = DemoScene()
        scene = demoScene!
 
        panEnabled = true
        verticalCameraAngleInterval = (-80, -5)
    }
}
