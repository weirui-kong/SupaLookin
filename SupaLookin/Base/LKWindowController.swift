//
//  LKWindowController.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/4/18.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa

/// Menu commands that LKAppMenuManager forwards to the key window's controller.
enum LKAppMenuAction: CaseIterable {
    case reload
    case dimension
    case zoomIn
    case zoomOut
    case decreaseInterspace
    case increaseInterspace
    case expansion
    case filter
    case export
    case openInNewWindow
}

/// The Objective-C protocol's methods were optional, and a menu item was enabled when the key window's controller implemented
/// its method. Here a controller lists the actions it handles in `supportedAppMenuActions` and overrides the matching methods.
protocol LKAppMenuManagerDelegate: AnyObject {
    var supportedAppMenuActions: Set<LKAppMenuAction> { get }
    func appMenuManagerDidSelectReload()
    func appMenuManagerDidSelectDimension()
    func appMenuManagerDidSelectZoomIn()
    func appMenuManagerDidSelectZoomOut()
    func appMenuManagerDidSelectDecreaseInterspace()
    func appMenuManagerDidSelectIncreaseInterspace()
    func appMenuManagerDidSelectExpansionIndex(_ index: Int)
    func appMenuManagerDidSelectFilter()
    func appMenuManagerDidSelectExport()
    func appMenuManagerDidSelectOpenInNewWindow()
}

class LKWindowController: NSWindowController, LKAppMenuManagerDelegate {

    deinit {
        NSLog("%@ dealloc", String(describing: type(of: self)))
    }

    var supportedAppMenuActions: Set<LKAppMenuAction> {
        []
    }

    func appMenuManagerDidSelectReload() {}
    func appMenuManagerDidSelectDimension() {}
    func appMenuManagerDidSelectZoomIn() {}
    func appMenuManagerDidSelectZoomOut() {}
    func appMenuManagerDidSelectDecreaseInterspace() {}
    func appMenuManagerDidSelectIncreaseInterspace() {}
    func appMenuManagerDidSelectExpansionIndex(_ index: Int) {}
    func appMenuManagerDidSelectFilter() {}
    func appMenuManagerDidSelectExport() {}
    func appMenuManagerDidSelectOpenInNewWindow() {}
}
