//
//  SPLKHostInput.swift
//  SupaLookin
//
//  Created by Weirui Kong on 2026/11/18.
//

import Foundation
import SPLKProtocol

// Input that reaches the whole simulator or device rather than just the inspected app: through dtuhidd into a
// simulator (M9), or through splkhidd on a jailbroken device (M12).
nonisolated protocol SPLKHostInput: AnyObject, Sendable {
    func connect() async throws
    // Touch events only; anything else in `events` is ignored.
    func send(_ events: [SPLKV2InputEvent], orientation: SPLKV2ScreenInfo.Orientation) async throws
    func press(_ button: SPLKHostButton) async throws
}

nonisolated enum SPLKHostButton: Sendable {
    case home, lock

    // Consumer page usages, as the device's own buttons report them.
    var usagePage: UInt32 { 0x0C }

    var usage: UInt32 {
        switch self {
        case .home: return 0x40
        case .lock: return 0x30
        }
    }

    // A short press: holding the side button calls up Siri.
    var holdMilliseconds: Int {
        switch self {
        case .home: return 80
        case .lock: return 100
        }
    }
}
