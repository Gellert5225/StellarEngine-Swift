//
//  ResourceTree.swift
//  StellarEngineMacOS
//
//  Created by Gellert Li on 2/14/21.
//  Copyright © 2021 Gellert. All rights reserved.
//

import Foundation

class ResourceTree {
    var name: String
    var children = [ResourceTree]()
    var isDirectory: Bool
    
    init(name: String, isDirectory: Bool) {
        self.name = name
        self.isDirectory = isDirectory
    }
    
    func add(child: ResourceTree) {
        children.append(child)
    }
    
    func printTree(tree: ResourceTree) {
        for child in tree.children {
            printTree(tree: child)
        }
        print(tree.name)
        
    }
}
