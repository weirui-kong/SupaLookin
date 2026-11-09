//
//  SPLKServerInput.swift
//  SPLKServerSession
//
//  Created by Weirui Kong on 2026/11/10.
//

#if SHOULD_COMPILE_SPLK_SERVER

import Foundation
import SPLKProtocol
import SPLKModelBridge
import SPLKServer

enum SPLKServerInput {

    @MainActor static var capabilities: Set<String> {
        var capabilities: Set<String> = [SPLKCapability.inputMotion, SPLKCapability.inputText]
        if SPLKTouchInjector.isTouchAvailable() {
            capabilities.insert(SPLKCapability.inputTouch)
        }
        return capabilities
    }

    // Replays events in order, one per main run loop turn, dropping a MOVED that a later MOVED of the same touch supersedes.
    static func replay(_ events: [SPLKV2InputEvent]) async throws {
        for (index, event) in events.enumerated() where !isSuperseded(index, in: events) {
            try await MainActor.run { try deliver(event) }
            await Self.nextRunLoopTurn()
        }
    }

    private static func isSuperseded(_ index: Int, in events: [SPLKV2InputEvent]) -> Bool {
        guard case .touch(let touch) = events[index].kind, touch.phase == .moved else { return false }
        for later in events[(index + 1)...] {
            guard case .touch(let other) = later.kind, other.touchID == touch.touchID else { continue }
            return other.phase == .moved
        }
        return false
    }

    @MainActor private static func deliver(_ event: SPLKV2InputEvent) throws {
        do {
            switch event.kind {
            case .touch(let touch):
                let phase = SPLKTouchInjectorPhase(rawValue: touch.phase.rawValue) ?? .cancelled
                try SPLKTouchInjector.injectTouch(UInt(touch.touchID), phase: phase, location: CGPoint(x: touch.location.x, y: touch.location.y))
            case .motion(let motion):
                guard motion.kind == .shake else { return }
                try SPLKTouchInjector.shake()
            case .text(let text):
                try SPLKTouchInjector.insertText(text.text)
            case .key(let key):
                switch key.code {
                case .delete: try SPLKTouchInjector.deleteBackward()
                case .return: try SPLKTouchInjector.insertText("\n")
                default: break
                }
            case nil:
                break
            }
        } catch let error as NSError {
            throw SPLKStatusError(.invalidArgument, reason: "input_undeliverable", title: error.localizedDescription)
        }
    }

    private static func nextRunLoopTurn() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
    }
}

#endif
