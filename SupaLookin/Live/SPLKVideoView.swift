//
//  SPLKVideoView.swift
//  SupaLookin
//
//  Created by Weirui Kong on 2026/11/10.
//

import Cocoa
import QuartzCore
import SPLKProtocol

// Shows the phone's video and, when input is enabled, turns the user's mouse, trackpad and keyboard into input.
final class SPLKVideoView: NSView {

    static let margin: CGFloat = 24

    var onInput: (([SPLKV2InputEvent]) -> Void)?

    var isInputEnabled = false {
        didSet {
            guard oldValue != isInputEnabled else { return }
            if !isInputEnabled {
                send(mapper.cancel())
            }
            window?.invalidateCursorRects(for: self)
        }
    }

    var screen = SPLKV2ScreenInfo() {
        didSet { needsLayout = true }
    }

    // The rect the video fills, in this view's coordinates.
    var videoRect: CGRect { mapper.videoRect }

    private let shadowLayer = CALayer()
    private let clipLayer = CALayer()
    private let contentLayer = CALayer()
    private var frameSize: CGSize = .zero
    private var mapper = SPLKLiveInputMapper()
    private var displayLink: CADisplayLink?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        shadowLayer.shadowColor = NSColor.black.cgColor
        shadowLayer.shadowOpacity = 0.25
        shadowLayer.shadowRadius = 16
        shadowLayer.shadowOffset = CGSize(width: 0, height: -4)
        clipLayer.masksToBounds = true
        clipLayer.backgroundColor = NSColor.black.cgColor
        contentLayer.contentsGravity = .resize
        clipLayer.addSublayer(contentLayer)
        layer?.addSublayer(shadowLayer)
        layer?.addSublayer(clipLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Frames

    func display(_ frame: SPLKVideoFrame) {
        let width = CVPixelBufferGetWidth(frame.pixelBuffer), height = CVPixelBufferGetHeight(frame.pixelBuffer)
        let size = CGSize(width: width, height: height)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if let surface = CVPixelBufferGetIOSurface(frame.pixelBuffer)?.takeUnretainedValue() {
            if contentLayer.contents as AnyObject? === surface {
                // The simulator redraws one surface in place; the layer only notices when told (private API).
                let selector = NSSelectorFromString("setContentsChanged")
                if contentLayer.responds(to: selector) {
                    contentLayer.perform(selector)
                } else {
                    contentLayer.contents = nil
                    contentLayer.contents = surface
                }
            } else {
                contentLayer.contents = surface
            }
        }
        CATransaction.commit()
        if size != frameSize {
            frameSize = size
            needsLayout = true
        }
    }

    func clear() {
        contentLayer.contents = nil
        frameSize = .zero
        needsLayout = true
    }

    var hasFrame: Bool { frameSize != .zero }

    // The video rect this view would use for a frame of the given size.
    func fittedRect(for size: CGSize) -> CGRect {
        let rotation = SPLKVideoSource.rotation(frameWidth: Int(size.width), frameHeight: Int(size.height), screen: screen)
        let oriented = rotation == .none ? size : CGSize(width: size.height, height: size.width)
        let area = bounds.insetBy(dx: Self.margin, dy: Self.margin)
        guard oriented.width > 0, oriented.height > 0, area.width > 0, area.height > 0 else { return .zero }
        let scale = min(area.width / oriented.width, area.height / oriented.height)
        let fitted = CGSize(width: oriented.width * scale, height: oriented.height * scale)
        return CGRect(x: area.midX - fitted.width / 2, y: area.midY - fitted.height / 2, width: fitted.width, height: fitted.height).integral
    }

    override func layout() {
        super.layout()
        let rect = fittedRect(for: frameSize)
        mapper.videoRect = rect
        let rotation = SPLKVideoSource.rotation(frameWidth: Int(frameSize.width), frameHeight: Int(frameSize.height), screen: screen)
        let radius = min(rect.width, rect.height) * 0.06
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shadowLayer.frame = rect
        shadowLayer.shadowPath = CGPath(roundedRect: CGRect(origin: .zero, size: rect.size), cornerWidth: radius, cornerHeight: radius, transform: nil)
        clipLayer.frame = rect
        clipLayer.cornerRadius = radius
        // The content keeps the frame's own aspect and is turned into the interface orientation.
        contentLayer.bounds = CGRect(origin: .zero, size: rotation == .none ? rect.size : CGSize(width: rect.height, height: rect.width))
        contentLayer.position = CGPoint(x: rect.width / 2, y: rect.height / 2)
        switch rotation {
        case .none: contentLayer.setAffineTransform(.identity)
        case .clockwise: contentLayer.setAffineTransform(CGAffineTransform(rotationAngle: -.pi / 2))
        case .counterclockwise: contentLayer.setAffineTransform(CGAffineTransform(rotationAngle: .pi / 2))
        }
        CATransaction.commit()
        window?.invalidateCursorRects(for: self)
    }

    // MARK: - Input

    override var acceptsFirstResponder: Bool { isInputEnabled }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        guard mapper.videoRect.width > 0 else { return }
        addCursorRect(mapper.videoRect, cursor: isInputEnabled ? .pointingHand : .operationNotAllowed)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        displayLink?.invalidate()
        displayLink = nil
        if window != nil {
            let link = displayLink(target: self, selector: #selector(flushMoves))
            link.add(to: .main, forMode: .common)
            displayLink = link
        }
    }

    @objc private func flushMoves() {
        send(mapper.takePendingMoves())
    }

    private func location(of event: NSEvent) -> CGPoint {
        convert(event.locationInWindow, from: nil)
    }

    override func mouseDown(with event: NSEvent) {
        guard isInputEnabled else { return }
        window?.makeFirstResponder(self)
        send(mapper.mouseDown(at: location(of: event), mirrored: event.modifierFlags.contains(.option)))
    }

    override func mouseDragged(with event: NSEvent) {
        guard isInputEnabled else { return }
        mapper.mouseDragged(to: location(of: event))
    }

    override func mouseUp(with event: NSEvent) {
        guard isInputEnabled else { return }
        send(mapper.mouseUp(at: location(of: event)))
    }

    override func magnify(with event: NSEvent) {
        guard isInputEnabled else { return }
        gesture(event) { mapper, phase, point in mapper.pinch(phase, at: point, magnification: event.magnification) }
    }

    override func rotate(with event: NSEvent) {
        guard isInputEnabled else { return }
        gesture(event) { mapper, phase, point in mapper.pinch(phase, at: point, rotation: CGFloat(event.rotation)) }
    }

    private func gesture(_ event: NSEvent, _ body: (inout SPLKLiveInputMapper, SPLKLiveInputMapper.Phase, CGPoint) -> [SPLKV2InputEvent]) {
        let point = location(of: event)
        if event.phase.contains(.began) {
            send(body(&mapper, .began, point))
        } else if event.phase.contains(.changed) {
            send(body(&mapper, .changed, point))
        } else if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
            send(body(&mapper, .ended, point))
        }
    }

    override func scrollWheel(with event: NSEvent) {
        guard isInputEnabled, event.momentumPhase.isEmpty else { return }
        let point = location(of: event)
        if event.phase.isEmpty {
            send(mapper.wheel(at: point, lines: event.scrollingDeltaY, horizontalLines: event.scrollingDeltaX))
        } else if event.phase.contains(.began) {
            send(mapper.scroll(.began, at: point, deltaX: 0, deltaY: 0))
        } else if event.phase.contains(.changed) {
            send(mapper.scroll(.changed, at: point, deltaX: event.scrollingDeltaX, deltaY: event.scrollingDeltaY))
        } else if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
            send(mapper.scroll(.ended, at: point, deltaX: 0, deltaY: 0))
        }
    }

    override func keyDown(with event: NSEvent) {
        guard isInputEnabled else {
            super.keyDown(with: event)
            return
        }
        if event.modifierFlags.contains(.command) {
            super.keyDown(with: event)
            return
        }
        switch event.keyCode {
        case 51: send([SPLKLiveInputMapper.key(.delete)])
        case 36, 76: send([SPLKLiveInputMapper.key(.return)])
        case 48: send([SPLKLiveInputMapper.key(.tab)])
        case 53: send([SPLKLiveInputMapper.key(.escape)])
        case 123: send([SPLKLiveInputMapper.key(.left)])
        case 124: send([SPLKLiveInputMapper.key(.right)])
        case 125: send([SPLKLiveInputMapper.key(.down)])
        case 126: send([SPLKLiveInputMapper.key(.up)])
        default:
            if let text = event.characters, !text.isEmpty, !text.unicodeScalars.contains(where: { $0.properties.generalCategory == .control || (0xF700...0xF8FF).contains($0.value) }) {
                send([SPLKLiveInputMapper.text(text)])
            }
        }
    }

    func cancelInput() {
        send(mapper.cancel())
    }

    private func send(_ events: [SPLKV2InputEvent]) {
        guard !events.isEmpty else { return }
        onInput?(events)
    }
}
