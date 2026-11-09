//
//  NSView+SPLKClient.swift
//  SupaLookin
//
//  Created by Li Kai on 2018/11/24.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa
import SPLKServer

extension NSView {

    /// SPLKBaseView keeps its own, stricter definition (it also needs a superview), as its Objective-C override did.
    var isVisible: Bool {
        if self is SPLKBaseView {
            return superview != nil && !isHidden && alphaValue >= 0.01
        }
        return !isHidden && alphaValue > 0
    }

    var backgroundColorName: String? {
        get {
            splk_getBindObject(forKey: "lk_backgroundColorName") as? String
        }
        set {
            splk_bindObject(newValue, forKey: "lk_backgroundColorName")
            if let newValue {
                layer?.backgroundColor = NSColor(named: newValue)?.cgColor
            } else {
                layer?.backgroundColor = nil
            }
        }
    }

    func showDebugBorder() {
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.cgColor
    }

    /// 将一个 view 作为自己的 subview 并且放到最底部
    func insertSubviewAtBottom(_ view: NSView) {
        if let first = subviews.first {
            addSubview(view, positioned: .below, relativeTo: first)
        } else {
            addSubview(view)
        }
    }
}
