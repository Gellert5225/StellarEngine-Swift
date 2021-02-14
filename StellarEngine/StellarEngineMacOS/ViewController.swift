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
    @IBOutlet weak var sceneOutlineView: NSOutlineView!
    @IBOutlet weak var resourceOutlineView: NSOutlineView!
    
    @IBOutlet var outputTextView: NSTextView!
    override func viewDidLoad() {
        metalView = mtkView
        super.viewDidLoad()
        
        STLRLog.delegate = self
        
        consoleSplitView.delegate = self
        navigationSplitView.delegate = self
        
        setupScene()
        
        sceneOutlineView.delegate = self
        sceneOutlineView.dataSource = self
    }
    
    func setupScene() {
        let testScene = TestScene()
        scene = testScene
        
        panEnabled = true
        verticalCameraAngleInterval = (-80, -5)
    }
}

extension HomeViewController: STLRLogDelegate {
    func flushToConsole() {
        outputTextView.textStorage?.append(STLRLog.logBuffer[STLRLog.logBuffer.count - 1])
    }
}

extension HomeViewController: NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let node = item as? STLRNode {
            return node.children.count
        }
        return 1
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let node = item as? STLRNode {
            return node.children[index]
        }
        return scene.rootNode
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let node = item as? STLRNode {
            return node.children.count > 0
        }
        return false
    }
}

extension HomeViewController: NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        let cellIdentifier = NSUserInterfaceItemIdentifier(rawValue: "sceneCell")
        guard let cell = outlineView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView else { return nil }
        if let node = item as? STLRNode {
            if let textField = cell.textField {
               textField.stringValue = node.name
               textField.sizeToFit()
            }
        }
        return cell
    }
}
