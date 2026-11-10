//
//  SPLKLiveInputMapper.swift
//  SupaLookin
//
//  Created by Weirui Kong on 2026/11/10.
//

import Foundation
import SPLKProtocol

// Turns events in the video view, in its unflipped coordinates, into InjectInput events normalized to the video rect.
struct SPLKLiveInputMapper {

    enum Phase {
        case began, changed, ended
    }

    static let primaryTouch: UInt32 = 1
    static let secondaryTouch: UInt32 = 2
    static let scrollTouch: UInt32 = 3

    // Half the distance between the two fingers when a pinch or rotation starts, in view points.
    static let pinchRadius: CGFloat = 50
    static let wheelStep: CGFloat = 40

    var videoRect: CGRect = .zero

    private enum Gesture {
        case none
        case touch
        case mirrored
        case pinch(center: CGPoint, radius: CGFloat, angle: CGFloat, magnification: CGFloat)
        case scroll(start: CGPoint, offset: CGSize)
    }

    private var gesture = Gesture.none
    private var pending: [SPLKV2InputEvent] = []
    // Cancelling keeps each finger where it was.
    private var lastLocations: [UInt32: CGPoint] = [:]

    var isActive: Bool {
        if case .none = gesture { return false }
        return true
    }

    // MARK: - Mouse

    mutating func mouseDown(at point: CGPoint, mirrored: Bool) -> [SPLKV2InputEvent] {
        guard contains(point) else { return [] }
        var events = cancel()
        if mirrored {
            gesture = .mirrored
            events += [touch(Self.primaryTouch, .began, point), touch(Self.secondaryTouch, .began, mirror(point))]
        } else {
            gesture = .touch
            events.append(touch(Self.primaryTouch, .began, point))
        }
        return events
    }

    // Moves wait in `pending` until the next display frame.
    mutating func mouseDragged(to point: CGPoint) {
        switch gesture {
        case .touch:
            pending = [touch(Self.primaryTouch, .moved, point)]
        case .mirrored:
            pending = [touch(Self.primaryTouch, .moved, point), touch(Self.secondaryTouch, .moved, mirror(point))]
        default:
            break
        }
    }

    mutating func mouseUp(at point: CGPoint) -> [SPLKV2InputEvent] {
        var events = takePendingMoves()
        switch gesture {
        case .touch:
            events.append(touch(Self.primaryTouch, .ended, point))
        case .mirrored:
            events += [touch(Self.primaryTouch, .ended, point), touch(Self.secondaryTouch, .ended, mirror(point))]
        default:
            return events
        }
        gesture = .none
        return events
    }

    // MARK: - Trackpad

    // magnification is NSEvent's per-event delta; rotation is its per-event delta in degrees, counterclockwise.
    mutating func pinch(_ phase: Phase, at point: CGPoint, magnification: CGFloat = 0, rotation: CGFloat = 0) -> [SPLKV2InputEvent] {
        switch phase {
        case .began:
            guard contains(point) else { return [] }
            var events = cancel()
            gesture = .pinch(center: point, radius: Self.pinchRadius, angle: 0, magnification: 0)
            let (first, second) = fingers(center: point, radius: Self.pinchRadius, angle: 0)
            events += [touch(Self.primaryTouch, .began, first), touch(Self.secondaryTouch, .began, second)]
            return events
        case .changed:
            guard case .pinch(let center, _, let angle, let total) = gesture else { return [] }
            let newTotal = total + magnification
            let radius = max(Self.pinchRadius * (1 + newTotal), 5)
            let newAngle = angle + rotation * .pi / 180
            gesture = .pinch(center: center, radius: radius, angle: newAngle, magnification: newTotal)
            let (first, second) = fingers(center: center, radius: radius, angle: newAngle)
            pending = [touch(Self.primaryTouch, .moved, first), touch(Self.secondaryTouch, .moved, second)]
            return []
        case .ended:
            guard case .pinch(let center, let radius, let angle, _) = gesture else { return [] }
            var events = takePendingMoves()
            let (first, second) = fingers(center: center, radius: radius, angle: angle)
            events += [touch(Self.primaryTouch, .ended, first), touch(Self.secondaryTouch, .ended, second)]
            gesture = .none
            return events
        }
    }

    // A scroll moves content the way a finger would: positive deltaY pulls content down.
    mutating func scroll(_ phase: Phase, at point: CGPoint, deltaX: CGFloat, deltaY: CGFloat) -> [SPLKV2InputEvent] {
        switch phase {
        case .began:
            guard contains(point) else { return [] }
            var events = cancel()
            gesture = .scroll(start: point, offset: .zero)
            events.append(touch(Self.scrollTouch, .began, point))
            return events
        case .changed:
            guard case .scroll(let start, let offset) = gesture else { return [] }
            let newOffset = CGSize(width: offset.width + deltaX, height: offset.height + deltaY)
            gesture = .scroll(start: start, offset: newOffset)
            pending = [touch(Self.scrollTouch, .moved, scrolled(start, newOffset))]
            return []
        case .ended:
            guard case .scroll(let start, let offset) = gesture else { return [] }
            var events = takePendingMoves()
            events.append(touch(Self.scrollTouch, .ended, scrolled(start, offset)))
            gesture = .none
            return events
        }
    }

    // A mouse wheel has no phases, so each notch becomes a short drag of its own.
    mutating func wheel(at point: CGPoint, lines: CGFloat, horizontalLines: CGFloat) -> [SPLKV2InputEvent] {
        guard !isActive else { return [] }
        let deltaX = horizontalLines.sign(Self.wheelStep), deltaY = lines.sign(Self.wheelStep)
        var events = scroll(.began, at: point, deltaX: 0, deltaY: 0)
        guard !events.isEmpty else { return [] }
        _ = scroll(.changed, at: point, deltaX: deltaX, deltaY: deltaY)
        events += scroll(.ended, at: point, deltaX: 0, deltaY: 0)
        return events
    }

    // MARK: - Delivery

    mutating func takePendingMoves() -> [SPLKV2InputEvent] {
        defer { pending = [] }
        return pending
    }

    // Ends whatever is in progress, for a mode change or a new gesture.
    mutating func cancel() -> [SPLKV2InputEvent] {
        pending = []
        var events: [SPLKV2InputEvent] = []
        switch gesture {
        case .none:
            return []
        case .touch:
            events.append(cancelled(Self.primaryTouch))
        case .mirrored, .pinch:
            events += [cancelled(Self.primaryTouch), cancelled(Self.secondaryTouch)]
        case .scroll:
            events.append(cancelled(Self.scrollTouch))
        }
        gesture = .none
        return events
    }

    static func text(_ text: String) -> SPLKV2InputEvent {
        var event = SPLKV2InputEvent()
        event.timestamp = ProcessInfo.processInfo.systemUptime
        event.text.text = text
        return event
    }

    static func key(_ code: SPLKV2Key.Code) -> SPLKV2InputEvent {
        var event = SPLKV2InputEvent()
        event.timestamp = ProcessInfo.processInfo.systemUptime
        event.key.code = code
        return event
    }

    static func shake() -> SPLKV2InputEvent {
        var event = SPLKV2InputEvent()
        event.timestamp = ProcessInfo.processInfo.systemUptime
        event.motion.kind = .shake
        return event
    }

    // MARK: - Geometry

    func contains(_ point: CGPoint) -> Bool {
        videoRect.width > 0 && videoRect.height > 0 && videoRect.contains(point)
    }

    // Origin at the top left, as the phone counts it.
    func normalized(_ point: CGPoint) -> CGPoint {
        guard videoRect.width > 0, videoRect.height > 0 else { return .zero }
        let x = (point.x - videoRect.minX) / videoRect.width
        let y = (videoRect.maxY - point.y) / videoRect.height
        return CGPoint(x: min(max(x, 0), 1), y: min(max(y, 0), 1))
    }

    private func mirror(_ point: CGPoint) -> CGPoint {
        CGPoint(x: videoRect.midX * 2 - point.x, y: videoRect.midY * 2 - point.y)
    }

    private func fingers(center: CGPoint, radius: CGFloat, angle: CGFloat) -> (CGPoint, CGPoint) {
        let dx = radius * cos(angle), dy = radius * sin(angle)
        return (CGPoint(x: center.x - dx, y: center.y - dy), CGPoint(x: center.x + dx, y: center.y + dy))
    }

    // View coordinates grow upward, so pulling content down lowers the finger's y.
    private func scrolled(_ start: CGPoint, _ offset: CGSize) -> CGPoint {
        CGPoint(x: start.x + offset.width, y: start.y - offset.height)
    }

    private mutating func touch(_ id: UInt32, _ phase: SPLKV2Touch.Phase, _ point: CGPoint) -> SPLKV2InputEvent {
        let location = normalized(point)
        lastLocations[id] = location
        return Self.touch(id, phase, location)
    }

    private mutating func cancelled(_ id: UInt32) -> SPLKV2InputEvent {
        Self.touch(id, .cancelled, lastLocations.removeValue(forKey: id) ?? .zero)
    }

    private static func touch(_ id: UInt32, _ phase: SPLKV2Touch.Phase, _ location: CGPoint) -> SPLKV2InputEvent {
        var event = SPLKV2InputEvent()
        event.timestamp = ProcessInfo.processInfo.systemUptime
        event.touch.touchID = id
        event.touch.phase = phase
        event.touch.location.x = location.x
        event.touch.location.y = location.y
        return event
    }
}

private extension CGFloat {
    // Step times the sign of self, or zero.
    func sign(_ step: CGFloat) -> CGFloat {
        self > 0 ? step : (self < 0 ? -step : 0)
    }
}
