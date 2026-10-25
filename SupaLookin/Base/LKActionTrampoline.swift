//
//  LKActionTrampoline.swift
//  SupaLookin
//
//  Created by Weirui Kong on 2026/10/25.
//

import Cocoa
import LookinShared

/// The one place that turns AppKit's selector-based target-action into closures, so the rest of the app needs no `@objc` handlers.
final class LKActionTrampoline<Sender: AnyObject>: NSObject {

    private let handler: (Sender) -> Void

    init(_ handler: @escaping (Sender) -> Void) {
        self.handler = handler
    }

    @objc func performAction(_ sender: Any?) {
        if let sender = sender as? Sender {
            handler(sender)
        }
    }
}

private let trampolineKey = "lk_actionTrampoline"

extension NSControl {

    func onAction(_ handler: @escaping (Self) -> Void) {
        let trampoline = LKActionTrampoline<Self>(handler)
        lookin_bindObject(trampoline, forKey: trampolineKey)
        target = trampoline
        action = #selector(LKActionTrampoline<Self>.performAction(_:))
    }
}

extension NSMenuItem {

    func onAction(_ handler: @escaping (NSMenuItem) -> Void) {
        let trampoline = LKActionTrampoline<NSMenuItem>(handler)
        lookin_bindObject(trampoline, forKey: trampolineKey)
        target = trampoline
        action = #selector(LKActionTrampoline<NSMenuItem>.performAction(_:))
    }

    convenience init(title: String, keyEquivalent: String = "", handler: @escaping (NSMenuItem) -> Void) {
        self.init(title: title, action: nil, keyEquivalent: keyEquivalent)
        onAction(handler)
    }
}

extension NSGestureRecognizer {

    func onAction(_ handler: @escaping (Self) -> Void) {
        let trampoline = LKActionTrampoline<Self>(handler)
        lookin_bindObject(trampoline, forKey: trampolineKey)
        target = trampoline
        action = #selector(LKActionTrampoline<Self>.performAction(_:))
    }
}

extension NSToolbarItem {

    /// A view-based item forwards its target-action to the view, so the sender is the item's control rather than the item.
    func onAction(_ handler: @escaping (AnyObject) -> Void) {
        let trampoline = LKActionTrampoline<AnyObject>(handler)
        lookin_bindObject(trampoline, forKey: trampolineKey)
        target = trampoline
        action = #selector(LKActionTrampoline<AnyObject>.performAction(_:))
    }
}
