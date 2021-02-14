//
//  Log.swift
//  Stellar
//
//  Created by Gellert Li on 2/14/21.
//  Copyright © 2021 Gellert. All rights reserved.
//

#if os(macOS)
import Foundation
import Cocoa

open class STLRLog {
    public static var delegate: STLRLogDelegate?
    public static var logBuffer = [NSAttributedString]() {
        didSet {
            delegate?.flushToConsole()
        }
    }
    
    public static func CORE_INFO(_ msg: String) {
        logBuffer.append(buildAttributedStringFrom(string: msg, color: NSColor.white))
    }
    
    public static func CORE_WARNING(_ msg: String) {
        logBuffer.append(buildAttributedStringFrom(string: msg, color: NSColor.yellow))
    }
    
    public static func CORE_ERROR(_ msg: String) {
        logBuffer.append(buildAttributedStringFrom(string: msg, color: NSColor.red))
    }
    
    fileprivate static func buildAttributedStringFrom(string: String, color: NSColor) -> NSMutableAttributedString {
        var cp = string
        cp.append("\n")
        
        let font = NSFont(name: "Menlo", size: 13)
        let prefixAttributes: [NSAttributedString.Key: Any] = [
            .font: font!,
            .foregroundColor: NSColor.white,
        ]
        
        let now = Date()
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let dateString = formatter.string(from: now)
    
        let prefix = NSMutableAttributedString(string: "[Stellar Engine - \(dateString)]: ", attributes: prefixAttributes)
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font!,
            .foregroundColor: color,
        ]
        let main = NSAttributedString(string: cp, attributes: attributes)
        prefix.append(main)
        
        return prefix
    }
}

public protocol STLRLogDelegate {
    func flushToConsole()
}

#endif
