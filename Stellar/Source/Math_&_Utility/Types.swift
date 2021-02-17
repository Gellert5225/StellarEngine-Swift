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
