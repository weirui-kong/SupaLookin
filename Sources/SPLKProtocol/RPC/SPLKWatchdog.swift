//
//  SPLKWatchdog.swift
//  SPLKProtocol
//
//  Created by Weirui Kong on 2026/11/10.
//

import Foundation

// Fires once unless touched within `timeout`. Dispatch timers instead of Task.sleep keep it usable on iOS 13.
final class SPLKWatchdog: @unchecked Sendable {

    private let lock = NSLock()
    private let timer: DispatchSourceTimer
    private let timeout: TimeInterval
    private var finished = false

    init(timeout: TimeInterval, onExpire: @escaping @Sendable () -> Void) {
        self.timeout = timeout
        timer = DispatchSource.makeTimerSource(queue: .global())
        timer.setEventHandler { [weak self] in
            guard let self, self.finish() else { return }
            onExpire()
        }
        timer.schedule(deadline: .now() + timeout)
        timer.resume()
    }

    func touch() {
        lock.lock()
        defer { lock.unlock() }
        if !finished {
            timer.schedule(deadline: .now() + timeout)
        }
    }

    func cancel() {
        _ = finish()
    }

    // Returns whether this call is the one that finished it.
    private func finish() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !finished else { return false }
        finished = true
        timer.cancel()
        return true
    }
}

public final class SPLKRequestIDAllocator: Sendable {

    private let next = SPLKLocked<UInt64>(1)

    public init() {}

    public func allocate() -> UInt64 {
        next.withLock { next in
            defer { next += 1 }
            return next
        }
    }
}
