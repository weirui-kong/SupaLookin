//
//  LKActionTrampoline.swift
//  SupaLookin
//
//  Created by Weirui Kong on 2026/10/25.
//

import Cocoa
import LookinShared

/// The one place that turns AppKit's selector-based target-action into closures, so the rest of the app needs no `@objc` handlers.
// Not generic: Swift 6.3 crashes inlining the deinit of a generic NSObject subclass in optimized builds.
final class LKActionTrampoline: NSObject {

    private let handler: (Any?) -> Void

    init(_ handler: @escaping (Any?) -> Void) {
        self.handler = handler
    }

    @objc func performAction(_ sender: Any?) {
        handler(sender)
    }
}

private let trampolineKey = "lk_actionTrampoline"

extension NSObject {

    fileprivate func bindTrampoline(_ handler: @escaping (Any?) -> Void) -> LKActionTrampoline {
        let trampoline = LKActionTrampoline(handler)
        lookin_bindObject(trampoline, forKey: trampolineKey)
        return trampoline
    }
}

extension NSControl {

    func onAction(_ handler: @escaping (Self) -> Void) {
        target = bindTrampoline { sender in
            if let sender = sender as? Self {
                handler(sender)
            }
        }
        action = #selector(LKActionTrampoline.performAction(_:))
    }
}

extension NSMenuItem {

    func onAction(_ handler: @escaping (NSMenuItem) -> Void) {
        target = bindTrampoline { sender in
            if let sender = sender as? NSMenuItem {
                handler(sender)
            }
        }
        action = #selector(LKActionTrampoline.performAction(_:))
    }

    convenience init(title: String, keyEquivalent: String = "", handler: @escaping (NSMenuItem) -> Void) {
        self.init(title: title, action: nil, keyEquivalent: keyEquivalent)
        onAction(handler)
    }
}

extension NSGestureRecognizer {

    func onAction(_ handler: @escaping (Self) -> Void) {
        target = bindTrampoline { sender in
            if let sender = sender as? Self {
                handler(sender)
            }
        }
        action = #selector(LKActionTrampoline.performAction(_:))
    }
}

extension NSToolbarItem {

    /// A view-based item forwards its target-action to the view, so the sender is the item's control rather than the item.
    func onAction(_ handler: @escaping (AnyObject) -> Void) {
        target = bindTrampoline { sender in
            if let sender = sender as AnyObject? {
                handler(sender)
            }
        }
        action = #selector(LKActionTrampoline.performAction(_:))
    }
}
