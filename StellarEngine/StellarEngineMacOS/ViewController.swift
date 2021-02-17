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
    var resourceTree = ResourceTree(name: "Documents", isDirectory: true)
    
    @IBOutlet weak var consoleSplitView: NSSplitView!
    @IBOutlet weak var navigationSplitView: NSSplitView!
    @IBOutlet weak var mtkView: MTKView!
    @IBOutlet weak var sceneOutlineView: NSOutlineView!
    @IBOutlet weak var resourceOutlineView: NSOutlineView!
    
    @IBOutlet var outputTextView: NSTextView!
    override func viewDidLoad() {
        metalView = mtkView
        super.viewDidLoad()
        
        consoleSplitView.delegate = self
        navigationSplitView.delegate = self
        
        setupScene()
        let docsPath = Bundle.main.resourcePath! + "/Assets.bundle"
//        let fileManager = FileManager.default
//        let documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("/Assets")
        loadResourceTree(at: URL(string: docsPath)!, resourceTree: resourceTree)
        
        sceneOutlineView.delegate = self
        sceneOutlineView.dataSource = self
        resourceOutlineView.delegate = self
        resourceOutlineView.dataSource = self
        
        resourceOutlineView.reloadData()
    }
    
    func loadResourceTree(at path: URL, resourceTree tree: ResourceTree) {
        do {
            let directoryContents = try FileManager.default.contentsOfDirectory(at: path, includingPropertiesForKeys: nil)
            for path in directoryContents {
                let isDirectory = (try? path.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                if isDirectory {
                    let child = ResourceTree(name: path.lastPathComponent, isDirectory: isDirectory)
                    tree.add(child: child)
                    loadResourceTree(at: path, resourceTree: child)
                } else {
                    if (path.lastPathComponent != ".DS_Store") {
                        let child = ResourceTree(name: path.lastPathComponent, isDirectory: false)
                        tree.add(child: child)
                    }
                }
            }
        } catch {
            print(error)
        }
        
    }
    
    func setupScene() {
        let testScene = TestScene(name: "Test Scene")
        scene = testScene
        
        panEnabled = true
        verticalCameraAngleInterval = (-80, -5)
    }
    
    override func flushToConsole() {
        outputTextView.textStorage?.append(STLRLog.logBuffer[STLRLog.logBuffer.count - 1])
    }
}

extension HomeViewController: NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if (outlineView == sceneOutlineView) {
            if let node = item as? STLRNode {
                return node.children.count
            }
            return 1
        } else {
            if let node = item as? ResourceTree {
                return node.children.count
            }
            return resourceTree.children.count
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if (outlineView == sceneOutlineView) {
            if let node = item as? STLRNode {
                return node.children[index]
            }
            return scene.rootNode
        } else {
            if let node = item as? ResourceTree {
                return node.children[index]
            }
            return resourceTree.children[index]
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if (outlineView == sceneOutlineView) {
            if let node = item as? STLRNode {
                return node.children.count > 0
            }
            return false
        } else {
            if let node = item as? ResourceTree {
                return node.isDirectory
            }
            return false
        }
    }
}

extension HomeViewController: NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        if (outlineView == sceneOutlineView) {
            let cellIdentifier = NSUserInterfaceItemIdentifier(rawValue: "sceneCell")
            guard let cell = outlineView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView else { return nil }
            if let node = item as? STLRNode {
                if let textField = cell.textField {
                   textField.stringValue = node.name
                   textField.sizeToFit()
                }
            }
            return cell
        } else {
            let cellIdentifier = NSUserInterfaceItemIdentifier(rawValue: "resourceCell")
            guard let cell = outlineView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView else { return nil }
            if let node = item as? ResourceTree {
                if let textField = cell.textField {
                   textField.stringValue = node.name
                   textField.sizeToFit()
                }
            }
            return cell
        }
    }
}
