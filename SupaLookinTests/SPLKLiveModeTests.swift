//
//  SPLKLiveModeTests.swift
//  SupaLookinTests
//
//  Created by Weirui Kong on 2026/11/10.
//

import Foundation
import Testing
import SPLKProtocol
@testable import SupaLookin

struct SPLKLiveInputMapperTests {

    // A 200×400 video letterboxed at (100, 50) in its view.
    private func mapper() -> SPLKLiveInputMapper {
        var mapper = SPLKLiveInputMapper()
        mapper.videoRect = CGRect(x: 100, y: 50, width: 200, height: 400)
        return mapper
    }

    private func location(_ event: SPLKV2InputEvent) -> CGPoint {
        CGPoint(x: event.touch.location.x, y: event.touch.location.y)
    }

    @Test func pointsAreNormalizedFromTheTopLeft() {
        let mapper = mapper()
        #expect(mapper.normalized(CGPoint(x: 100, y: 450)) == CGPoint(x: 0, y: 0))
        #expect(mapper.normalized(CGPoint(x: 300, y: 50)) == CGPoint(x: 1, y: 1))
        #expect(mapper.normalized(CGPoint(x: 150, y: 350)) == CGPoint(x: 0.25, y: 0.25))
        // Drags that leave the video stay on its edge.
        #expect(mapper.normalized(CGPoint(x: 0, y: 1000)) == CGPoint(x: 0, y: 0))
    }

    @Test func clicksOutsideTheVideoAreIgnored() {
        var mapper = mapper()
        #expect(mapper.mouseDown(at: CGPoint(x: 50, y: 200), mirrored: false).isEmpty)
        #expect(mapper.mouseUp(at: CGPoint(x: 50, y: 200)).isEmpty)
        #expect(!mapper.isActive)
    }

    @Test func aDragIsOneTouchWithMovesCoalesced() {
        var mapper = mapper()
        let began = mapper.mouseDown(at: CGPoint(x: 200, y: 250), mirrored: false)
        #expect(began.map(\.touch.phase) == [.began])
        #expect(began[0].touch.touchID == SPLKLiveInputMapper.primaryTouch)
        mapper.mouseDragged(to: CGPoint(x: 200, y: 300))
        mapper.mouseDragged(to: CGPoint(x: 200, y: 350))
        let moves = mapper.takePendingMoves()
        #expect(moves.count == 1)
        #expect(location(moves[0]) == CGPoint(x: 0.5, y: 0.25))
        #expect(mapper.takePendingMoves().isEmpty)
        mapper.mouseDragged(to: CGPoint(x: 200, y: 400))
        // An unsent move goes out before the touch ends.
        let ended = mapper.mouseUp(at: CGPoint(x: 200, y: 400))
        #expect(ended.map(\.touch.phase) == [.moved, .ended])
    }

    @Test func optionDragMirrorsAroundTheCenter() {
        var mapper = mapper()
        let began = mapper.mouseDown(at: CGPoint(x: 150, y: 350), mirrored: true)
        #expect(began.map(\.touch.touchID) == [SPLKLiveInputMapper.primaryTouch, SPLKLiveInputMapper.secondaryTouch])
        #expect(location(began[0]) == CGPoint(x: 0.25, y: 0.25))
        #expect(location(began[1]) == CGPoint(x: 0.75, y: 0.75))
        let ended = mapper.mouseUp(at: CGPoint(x: 150, y: 350))
        #expect(ended.map(\.touch.phase) == [.ended, .ended])
    }

    @Test func pinchSpreadsTwoFingers() {
        var mapper = mapper()
        let center = CGPoint(x: 200, y: 250)
        let began = mapper.pinch(.began, at: center)
        #expect(began.count == 2)
        let startDistance = abs(began[1].touch.location.x - began[0].touch.location.x)
        #expect(mapper.pinch(.changed, at: center, magnification: 0.5).isEmpty)
        let moved = mapper.takePendingMoves()
        let distance = abs(moved[1].touch.location.x - moved[0].touch.location.x)
        #expect(abs(distance - startDistance * 1.5) < 0.0001)
        // Rotating a quarter turn lines the fingers up vertically.
        _ = mapper.pinch(.changed, at: center, rotation: 90)
        let turned = mapper.takePendingMoves()
        #expect(abs(turned[0].touch.location.x - turned[1].touch.location.x) < 0.0001)
        #expect(mapper.pinch(.ended, at: center).map(\.touch.phase) == [.ended, .ended])
    }

    @Test func scrollingDragsContentLikeAFinger() {
        var mapper = mapper()
        let start = CGPoint(x: 200, y: 250)
        #expect(mapper.scroll(.began, at: start, deltaX: 0, deltaY: 0).map(\.touch.touchID) == [SPLKLiveInputMapper.scrollTouch])
        _ = mapper.scroll(.changed, at: start, deltaX: 0, deltaY: 40)
        _ = mapper.scroll(.changed, at: start, deltaX: 0, deltaY: 40)
        let ended = mapper.scroll(.ended, at: start, deltaX: 0, deltaY: 0)
        #expect(ended.map(\.touch.phase) == [.moved, .ended])
        // Pulling content down 80 points moves the finger down a fifth of the video's height.
        #expect(abs(ended[1].touch.location.y - 0.7) < 0.0001)
    }

    @Test func wheelNotchesAreShortDrags() {
        var mapper = mapper()
        let events = mapper.wheel(at: CGPoint(x: 200, y: 250), lines: -3, horizontalLines: 0)
        #expect(events.map(\.touch.phase) == [.began, .moved, .ended])
        #expect(abs(events[2].touch.location.y - 0.4) < 0.0001)
    }

    @Test func cancellingEndsTheGestureWhereItWas() {
        var mapper = mapper()
        _ = mapper.mouseDown(at: CGPoint(x: 200, y: 250), mirrored: true)
        let cancelled = mapper.cancel()
        #expect(cancelled.map(\.touch.phase) == [.cancelled, .cancelled])
        #expect(location(cancelled[0]) == CGPoint(x: 0.5, y: 0.5))
        #expect(!mapper.isActive)
        #expect(mapper.cancel().isEmpty)
    }
}

struct SPLKModeMenuTests {

    private func states(_ mode: SPLKWindowMode, hasApp: Bool = true) -> [String] {
        SPLKModeToolbarItem.entries(mode: mode, hasApp: hasApp).map { entry in
            "\(entry.choice) \(entry.isEnabled ? "on" : "off")\(entry.isChecked ? " checked" : "")"
        }
    }

    @Test func inspectOffersLiveControl() {
        #expect(states(.inspect) == ["inspect on checked", "liveControl on", "endTakeover off"])
    }

    @Test func liveControlOffersInspect() {
        #expect(states(.liveControl) == ["inspect on", "liveControl on checked", "endTakeover off"])
    }

    @Test func takeoverOnlyOffersEndingIt() {
        #expect(states(.takeover(label: "Claude Code")) == ["inspect off", "liveControl off", "endTakeover on"])
        let end = SPLKModeToolbarItem.entries(mode: .takeover(label: "Claude Code"), hasApp: true)[2]
        #expect(end.title.contains("Claude Code"))
    }

    @Test func takeoverCantBePicked() {
        let takeover = SPLKModeToolbarItem.entries(mode: .inspect, hasApp: true)[2]
        #expect(!takeover.isEnabled)
        #expect(takeover.toolTip != nil)
    }

    @Test func nothingWithoutAnApp() {
        #expect(states(.inspect, hasApp: false) == ["inspect off checked", "liveControl off", "endTakeover off"])
    }

    @Test func windowModesFollowTheArbiter() {
        #expect(SPLKWindowMode(.inspect) == .inspect)
        #expect(SPLKWindowMode(.liveControl) == .liveControl)
        #expect(SPLKWindowMode(.takeover(session: "a", label: "Agent")) == .takeover(label: "Agent"))
        #expect(!SPLKWindowMode.inspect.showsVideo)
        #expect(SPLKWindowMode.takeover(label: "Agent").showsVideo)
    }
}

struct SPLKDigitizerTranslatorTests {

    private func touch(_ id: UInt32, _ phase: SPLKV2Touch.Phase, _ x: Double, _ y: Double) -> SPLKV2InputEvent {
        var event = SPLKV2InputEvent()
        event.touch.touchID = id
        event.touch.phase = phase
        event.touch.location.x = x
        event.touch.location.y = y
        return event
    }

    private typealias Message = SPLKDigitizerTranslator.Message

    @Test func oneFingerStartsMovesAndEnds() {
        var translator = SPLKDigitizerTranslator()
        #expect(translator.translate([touch(1, .began, 0.1, 0.2)]) == [Message(eventType: 0, points: [CGPoint(x: 0.1, y: 0.2)])])
        #expect(translator.translate([touch(1, .moved, 0.3, 0.4)]) == [Message(eventType: 1, points: [CGPoint(x: 0.3, y: 0.4)])])
        // A batch with the last move and the lift sends both, in order.
        #expect(translator.translate([touch(1, .moved, 0.5, 0.5), touch(1, .ended, 0.5, 0.5)]) == [
            Message(eventType: 1, points: [CGPoint(x: 0.5, y: 0.5)]),
            Message(eventType: 2, points: [CGPoint(x: 0.5, y: 0.5)]),
        ])
    }

    @Test func twoFingersShareOneMessage() {
        var translator = SPLKDigitizerTranslator()
        let began = translator.translate([touch(1, .began, 0.4, 0.5), touch(2, .began, 0.6, 0.5)])
        #expect(began == [Message(eventType: 0, points: [CGPoint(x: 0.4, y: 0.5), CGPoint(x: 0.6, y: 0.5)])])
        let moved = translator.translate([touch(1, .moved, 0.3, 0.5), touch(2, .moved, 0.7, 0.5)])
        #expect(moved == [Message(eventType: 1, points: [CGPoint(x: 0.3, y: 0.5), CGPoint(x: 0.7, y: 0.5)])])
        let ended = translator.translate([touch(1, .ended, 0.3, 0.5), touch(2, .ended, 0.7, 0.5)])
        #expect(ended == [Message(eventType: 2, points: [CGPoint(x: 0.3, y: 0.5), CGPoint(x: 0.7, y: 0.5)])])
    }

    @Test func liftingOneOfTwoFingersKeepsTheOther() {
        var translator = SPLKDigitizerTranslator()
        _ = translator.translate([touch(1, .began, 0.4, 0.5), touch(2, .began, 0.6, 0.5)])
        #expect(translator.translate([touch(2, .ended, 0.6, 0.5)]) == [Message(eventType: 1, points: [CGPoint(x: 0.4, y: 0.5)])])
        #expect(translator.translate([touch(1, .ended, 0.4, 0.5)]) == [Message(eventType: 2, points: [CGPoint(x: 0.4, y: 0.5)])])
    }

    @Test func cancelEndsAndUnknownFingersAreIgnored() {
        var translator = SPLKDigitizerTranslator()
        #expect(translator.translate([touch(9, .moved, 0.5, 0.5), touch(9, .ended, 0.5, 0.5)]).isEmpty)
        _ = translator.translate([touch(1, .began, 0.2, 0.2)])
        #expect(translator.translate([touch(1, .cancelled, 0.2, 0.2)]) == [Message(eventType: 2, points: [CGPoint(x: 0.2, y: 0.2)])])
        var text = SPLKV2InputEvent()
        text.text.text = "a"
        #expect(translator.translate([text]).isEmpty)
    }

    @Test func pointsTurnToThePortraitDigitizer() {
        let point = CGPoint(x: 0.25, y: 0.1)
        #expect(SPLKDigitizerTranslator.nativePoint(point, orientation: .portrait) == point)
        #expect(SPLKDigitizerTranslator.nativePoint(point, orientation: .landscapeLeft) == CGPoint(x: 0.1, y: 0.75))
        #expect(SPLKDigitizerTranslator.nativePoint(point, orientation: .landscapeRight) == CGPoint(x: 0.9, y: 0.25))
        #expect(SPLKDigitizerTranslator.nativePoint(point, orientation: .portraitUpsideDown) == CGPoint(x: 0.75, y: 0.9))
    }

    @Test func dtuhiddNeedsCoreSimulator1155_4() {
        #expect(!SPLKSimulatorHIDInput.isSupported(version: "1051.17.7"))
        #expect(!SPLKSimulatorHIDInput.isSupported(version: "1155.3.9"))
        #expect(SPLKSimulatorHIDInput.isSupported(version: "1155.4"))
        #expect(SPLKSimulatorHIDInput.isSupported(version: "1174.21"))
    }
}
