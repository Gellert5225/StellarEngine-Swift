//
//  RightPanelView.swift
//  StellarEngineMacOS
//
//  Created by Gellert Li on 2/14/21.
//  Copyright © 2021 Gellert. All rights reserved.
//

import Cocoa

class RightPanelView: NSView {

    @IBOutlet var contentView: NSView!
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        Bundle.main.loadNibNamed("RightPanelView", owner: self, topLevelObjects: nil)
        addSubview(contentView)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.width, .height]
    }
}
