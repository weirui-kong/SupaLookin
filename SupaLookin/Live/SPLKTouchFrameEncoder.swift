//
//  SPLKTouchFrameEncoder.swift
//  SupaLookin
//
//  Created by Weirui Kong on 2026/11/18.
//

import Foundation
import SPLKProtocol

// Turns InjectInput touches into splkhidd's touch frames: every frame carries every finger still down, plus each finger
// lifting in it, with identities the helper keeps from touch-down to lift.
nonisolated struct SPLKTouchFrameEncoder {

    static let maxFingers = 10

    struct Finger: Equatable {
        let identity: Int
        let point: CGPoint
        let isDown: Bool
    }

    private struct Live {
        let identity: Int
        var point: CGPoint
    }

    private var live: [UInt32: Live] = [:]

    private enum Kind {
        case began, moved, ended
    }

    // Points are already in the digitizer's frame.
    mutating func frames(for events: [SPLKV2InputEvent], transform: (CGPoint) -> CGPoint = { $0 }) -> [[Finger]] {
        var frames: [[Finger]] = []
        var group: [(UInt32, Kind, CGPoint)] = []
        for event in events {
            guard case .touch(let touch) = event.kind else { continue }
            let kind: Kind
            switch touch.phase {
            case .began: kind = .began
            case .moved, .stationary: kind = .moved
            case .ended, .cancelled: kind = .ended
            default: continue
            }
            let point = transform(CGPoint(x: touch.location.x, y: touch.location.y))
            // A run of one phase is one frame; a repeated finger starts the next.
            if let last = group.last, last.1 != kind || group.contains(where: { $0.0 == touch.touchID }) {
                frames += frame(for: group)
                group = []
            }
            group.append((touch.touchID, kind, point))
        }
        frames += frame(for: group)
        return frames
    }

    private mutating func frame(for group: [(UInt32, Kind, CGPoint)]) -> [[Finger]] {
        guard let kind = group.first?.1 else { return [] }
        var lifting: [Finger] = []
        for (id, _, point) in group {
            switch kind {
            case .began:
                guard live[id] == nil, let identity = freeIdentity() else { continue }
                live[id] = Live(identity: identity, point: point)
            case .moved:
                live[id]?.point = point
            case .ended:
                guard let finger = live.removeValue(forKey: id) else { continue }
                lifting.append(Finger(identity: finger.identity, point: point, isDown: false))
            }
        }
        let down = live.values.map { Finger(identity: $0.identity, point: $0.point, isDown: true) }
        let fingers = (down + lifting).sorted { $0.identity < $1.identity }
        return fingers.isEmpty || (kind == .moved && down.isEmpty) ? [] : [fingers]
    }

    private func freeIdentity() -> Int? {
        let used = Set(live.values.map(\.identity))
        return (0..<Self.maxFingers).first { !used.contains($0) }
    }

    // Fingers still down, lifted, for a session that's ending.
    mutating func liftAll() -> [Finger] {
        defer { live = [:] }
        return live.values.map { Finger(identity: $0.identity, point: $0.point, isDown: false) }.sorted { $0.identity < $1.identity }
    }

    static func line(for frame: [Finger]) -> String {
        "T " + frame.map { finger in
            "\(finger.identity):\(format(finger.point.x)):\(format(finger.point.y)):\(finger.isDown ? 1 : 0)"
        }.joined(separator: " ")
    }

    static func buttonLine(page: UInt32, usage: UInt32, holdMilliseconds: Int) -> String {
        "B \(String(page, radix: 16)) \(String(usage, radix: 16)) \(holdMilliseconds)"
    }

    private static func format(_ value: CGFloat) -> String {
        String(format: "%.5f", min(max(value, 0), 1))
    }
}
