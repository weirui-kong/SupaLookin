//
//  LKWindow.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/5/14.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa

class LKWindow: NSWindow {

    static func panelWindow(width: CGFloat, height: CGFloat, contentView: LKPanelContentView) -> LKWindow {
        let window = LKWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: height), styleMask: .titled, backing: .buffered, defer: true)
        window.contentView = contentView
        return window
    }

    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        registerForDraggedTypes([.fileURL])
    }

    func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        .copy
    }

    func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        let path = NSURL(from: sender.draggingPasteboard)?.path
        do {
            try LKNavigationManager.sharedInstance.showReader(withFilePath: path)
            return true
        } catch {
            LKHelper.alertError(error, window: self)
            return false
        }
    }
}
