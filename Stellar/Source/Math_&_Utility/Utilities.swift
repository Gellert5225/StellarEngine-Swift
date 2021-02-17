//
//  Types.swift
//  ObsidianEngine
//
//  Created by Gellert on 6/17/18.
//  Copyright © 2018 Gellert. All rights reserved.
//

import Foundation
import simd

func recursivePathsForResource(name: String, extensionName: String, in directoryPath: String) -> URL? {
    let enumerator = FileManager.default.enumerator(atPath: directoryPath)
    let fileExtension = URL(fileURLWithPath: name).pathExtension.isEmpty ? extensionName : ""
    let fullFileName = name + (fileExtension == "" ? "" : ".\(fileExtension)")
    
    while let filePath = enumerator?.nextObject() as? String {
        if URL(fileURLWithPath: filePath).lastPathComponent == fullFileName {
            return URL(fileURLWithPath: directoryPath + "/" + filePath)
        }
    }
    return nil
}

class FPSCounter {
    var updateInterval: Float = 0.5
    var accum: Float = 0.0
    var frames: Int = 0;
    var timeLeft: Float = 0;
    var previousTime: Float = 0;
    
    init(interval: Float) {
        self.updateInterval = interval
        self.timeLeft = interval
    }
    
    func getFPS(time: Float) -> Float {
        let deltaTime = time - previousTime
        previousTime = time
        
        timeLeft -= deltaTime
        accum += 1 / deltaTime
        frames += 1
        
        var fps: Float = 0
        if(timeLeft <= 0.0) {
            fps = accum / Float(frames)
            timeLeft = updateInterval
            accum = 0
            frames = 0
        }
        return fps
    }
}
