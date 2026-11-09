//
//  SPLKUIMonitor.swift
//  SPLKServerSession
//
//  Created by Weirui Kong on 2026/11/10.
//

#if SHOULD_COMPILE_SPLK_SERVER

import Foundation
import UIKit
import QuartzCore

// Tracks the UI generation and idleness. Only does work while someone needs it.
@MainActor
final class SPLKUIMonitor {

    static let shared = SPLKUIMonitor()

    private static let checkInterval: CFTimeInterval = 0.1
    private static let layerLimit = 20_000

    private(set) var generation: UInt64 = 1
    private var signature: Int?
    private var lastCheck: CFTimeInterval = 0
    private var lastChange: CFTimeInterval = 0
    private var stableChecks = 0
    private var wasIdle = false
    private var waiters = 0
    private var observer: CFRunLoopObserver?
    private var state: SPLKServerState?

    func start(state: SPLKServerState) {
        guard observer == nil else { return }
        self.state = state
        let observer = CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault, CFRunLoopActivity.beforeWaiting.rawValue, true, 0) { _, _ in
            MainActor.assumeIsolated { SPLKUIMonitor.shared.tick() }
        }
        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
        self.observer = observer
    }

    private func tick() {
        guard waiters > 0 || state?.wantsUIEvents == true else { return }
        guard CACurrentMediaTime() - lastCheck >= Self.checkInterval else { return }
        check()
    }

    @discardableResult
    private func check() -> Bool {
        let now = CACurrentMediaTime()
        lastCheck = now
        let (newSignature, animating) = Self.computeSignature()
        if newSignature != signature {
            if signature != nil {
                generation += 1
                state?.publishHierarchyChanged(generation)
            }
            signature = newSignature
            lastChange = now
            stableChecks = 0
        } else {
            stableChecks += 1
        }
        let idle = !animating && stableChecks >= 1 && now - lastChange >= Self.checkInterval
        if idle && !wasIdle {
            state?.publishIdle()
        }
        wasIdle = idle
        return idle
    }

    func currentGeneration() -> UInt64 {
        check()
        return generation
    }

    func waitForIdle(timeout: TimeInterval) async -> Bool {
        waiters += 1
        defer { waiters -= 1 }
        let deadline = CACurrentMediaTime() + timeout
        while true {
            if check() {
                return true
            }
            if CACurrentMediaTime() >= deadline {
                return false
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    private static func computeSignature() -> (Int, Bool) {
        var hasher = Hasher()
        var animating = false
        var count = 0
        var stack: [CALayer] = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .map(\.layer)
        while let layer = stack.popLast(), count < layerLimit {
            count += 1
            hasher.combine(ObjectIdentifier(layer))
            hasher.combine(layer.frame.origin.x)
            hasher.combine(layer.frame.origin.y)
            hasher.combine(layer.frame.size.width)
            hasher.combine(layer.frame.size.height)
            hasher.combine(layer.isHidden)
            hasher.combine(layer.opacity)
            let sublayers = layer.sublayers ?? []
            hasher.combine(sublayers.count)
            if !animating, let keys = layer.animationKeys() {
                // Endless animations, like a caret's blink or a spinner, never finish; their views coming and going still change the signature.
                animating = keys.contains { key in
                    guard let animation = layer.animation(forKey: key) else { return false }
                    return !animation.repeatCount.isInfinite && animation.repeatCount < .greatestFiniteMagnitude && !animation.repeatDuration.isInfinite
                }
            }
            stack.append(contentsOf: sublayers)
        }
        return (hasher.finalize(), animating)
    }
}

#endif
