//
//  LookinShared+Swift.swift
//  SupaLookin
//
//  Created by Weirui Kong on 2026/10/25.
//

import Cocoa
import LookinShared

// Swift counterparts of LookinShared's function-like macros, which the Clang importer can't bring over.

nonisolated enum LookinError {

    static var objNotFound: NSError {
        NSError(domain: LookinErrorDomain, code: LookinErrCode_ObjectNotFound, userInfo: [
            NSLocalizedDescriptionKey: NSLocalizedString("Failed to get target object in iOS app", comment: ""),
            NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString("Perhaps the related object was deallocated. You can reload Lookin to get newest data.", comment: ""),
        ])
    }

    static var noConnect: NSError {
        NSError(domain: LookinErrorDomain, code: LookinErrCode_NoConnect, userInfo: [
            NSLocalizedDescriptionKey: NSLocalizedString("The operation failed due to disconnection with the iOS app.", comment: ""),
        ])
    }

    static var inner: NSError {
        NSError(domain: LookinErrorDomain, code: LookinErrCode_Inner, userInfo: [
            NSLocalizedDescriptionKey: NSLocalizedString("The operation failed due to an inner error.", comment: ""),
        ])
    }

    static func make(_ title: String, _ detail: String) -> NSError {
        NSError(domain: LookinErrorDomain, code: LookinErrCode_Default, userInfo: [
            NSLocalizedDescriptionKey: title,
            NSLocalizedRecoverySuggestionErrorKey: detail,
        ])
    }

    static var timeoutText: String {
        NSLocalizedString("Perhaps your iOS app is paused with breakpoint in Xcode, blocked by other tasks in main thread, or moved to background state.", comment: "")
    }
}

extension NSColor {

    nonisolated convenience init(lookinRed red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat = 1) {
        self.init(red: red / 255.0, green: green / 255.0, blue: blue / 255.0, alpha: alpha)
    }
}
