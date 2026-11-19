//
//  SPLKModeTransition.swift
//  SupaLookin
//
//  Created by Weirui Kong on 2026/11/10.
//

import Cocoa
import SPLKServer

// Moves the window between Inspect and the video modes: the hierarchy collapses, the preview flattens, and the phone's screen becomes the live video.
final class SPLKModeTransition {

    static let collapseDuration: TimeInterval = 0.35
    static let flattenDuration: TimeInterval = 0.4
    static let handOffDuration: TimeInterval = 0.35
    static let fadeDuration: TimeInterval = 0.15

    private unowned let host: SPLKStaticViewController

    private(set) var displayedMode = SPLKWindowMode.inspect
    var isTransitioning: Bool { isRunning }
    var onModeChange: ((SPLKWindowMode) -> Void)?
    // Reloads the hierarchy as Reload does; returns the error, if any.
    var reloadHierarchy: (() async -> Error?)?

    private struct Request {
        let mode: SPLKWindowMode
        weak var session: SPLKDeviceSession?
        let animated: Bool
    }

    private struct SavedState {
        let expansion: [UInt: Bool]
        let expansionIndex: Int
        var dimension: SPLKPreviewDimension
    }

    private var request: Request?
    private var isRunning = false
    private var saved: SavedState?

    init(host: SPLKStaticViewController) {
        self.host = host
    }

    // Requests made while a transition runs wait for it; only the latest one is kept.
    func show(_ mode: SPLKWindowMode, session: SPLKDeviceSession?, animated: Bool) {
        request = Request(mode: mode, session: session, animated: animated)
        guard !isRunning else { return }
        isRunning = true
        Task {
            while let next = request {
                request = nil
                await apply(next)
            }
            isRunning = false
        }
    }

    private var reducesMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    private func apply(_ request: Request) async {
        let from = displayedMode
        switch (from.showsVideo, request.mode.showsVideo) {
        case (false, true):
            guard let session = request.session else { return }
            setDisplayed(request.mode)
            await enter(request.mode, session: session, animated: request.animated && !reducesMotion)
        case (true, true):
            host.liveController.mode = request.mode
            setDisplayed(request.mode)
        case (true, false):
            // A session that's gone can't reload; the app is being replaced or disconnected.
            await exit(animated: request.animated && !reducesMotion, reload: request.session != nil)
            setDisplayed(.inspect)
        case (false, false):
            break
        }
    }

    private func setDisplayed(_ mode: SPLKWindowMode) {
        displayedMode = mode
        onModeChange?(mode)
    }

    // MARK: - Into video

    private func enter(_ mode: SPLKWindowMode, session: SPLKDeviceSession, animated: Bool) async {
        let live = host.liveController
        let preview = host.viewsPreviewController!
        let dataSource = SPLKStaticHierarchyDataSource.sharedInstance
        live.mode = mode
        live.attach(session)

        let canMorph = animated && dataSource.rawHierarchyInfo != nil && preview.screenRect(in: host.transitionOverlay) != nil
        if canMorph {
            var expansion: [UInt: Bool] = [:]
            for item in dataSource.flatItems {
                expansion[item.layerObject?.oid ?? 0] = item.isExpanded
            }
            saved = SavedState(expansion: expansion, expansionIndex: dataSource.preferenceManager.expansionIndex, dimension: .dimension2D)
            dataSource.adjustExpansion(byIndex: 0, referenceDict: nil, remembersIndex: false)
            await sleep(Self.collapseDuration)
            saved?.dimension = preview.flattenForModeChange(duration: Self.flattenDuration)
            await sleep(Self.flattenDuration + 0.05)
        }

        host.installLiveView()
        let snapshot = canMorph ? preview.screenSnapshot() : nil
        guard animated, let snapshot, let fromRect = preview.screenRect(in: host.transitionOverlay) else {
            await fade(liveIn: true, animated: animated)
            focusVideo()
            return
        }

        let layer = host.transitionOverlay.showSnapshot(snapshot, frame: fromRect)
        let target = videoRect(fallbackAspect: fromRect.size)
        await animate(Self.handOffDuration) {
            layer.frame = target.rect
            layer.cornerRadius = target.radius
            self.host.liveController.view.animator().alphaValue = 1
            self.slidePanels(out: true)
        }
        await animate(Self.fadeDuration) {
            layer.opacity = 0
        }
        host.transitionOverlay.clear()
        host.finishPanelSlide(visible: false)
        focusVideo()
    }

    // MARK: - Back to Inspect

    private func exit(animated: Bool, reload: Bool) async {
        let live = host.liveController
        let preview = host.viewsPreviewController!
        live.videoView.cancelInput()

        let image = animated ? live.currentFrameImage() : nil
        let fromRect = live.videoView.hasFrame ? live.videoView.convert(live.videoView.videoRect, to: host.transitionOverlay) : .zero
        if animated, let image, fromRect.width > 0, let toRect = preview.screenRect(in: host.transitionOverlay) {
            let radius = min(fromRect.width, fromRect.height) * 0.06
            let layer = host.transitionOverlay.showSnapshot(image, frame: fromRect)
            layer.cornerRadius = radius
            host.preparePanelSlideIn()
            await animate(Self.handOffDuration) {
                layer.frame = toRect
                layer.cornerRadius = 0
                live.view.animator().alphaValue = 0
                self.slidePanels(out: false)
            }
            await animate(Self.fadeDuration) {
                layer.opacity = 0
            }
            host.transitionOverlay.clear()
        } else {
            host.preparePanelSlideIn()
            await fade(liveIn: false, animated: animated)
        }
        host.finishPanelSlide(visible: true)
        host.removeLiveView()
        live.detach()

        guard let saved else {
            if reload {
                _ = await reloadHierarchy?()
            }
            return
        }
        self.saved = nil
        if reload, await reloadHierarchy?() == nil {
            SPLKStaticHierarchyDataSource.sharedInstance.adjustExpansion(byIndex: saved.expansionIndex, referenceDict: saved.expansion)
        }
        host.viewsPreviewController.restoreDimension(saved.dimension)
    }

    // MARK: - Helpers

    private func focusVideo() {
        if displayedMode == .liveControl {
            host.view.window?.makeFirstResponder(host.liveController.videoView)
        }
    }

    // Where the video will appear: its own rect once a frame arrived, else the preview's screen fitted the same way.
    private func videoRect(fallbackAspect: CGSize) -> (rect: CGRect, radius: CGFloat) {
        let videoView = host.liveController.videoView
        host.liveController.view.layoutSubtreeIfNeeded()
        let local = videoView.hasFrame ? videoView.videoRect : videoView.fittedRect(for: fallbackAspect)
        let rect = videoView.convert(local, to: host.transitionOverlay)
        return (rect, min(rect.width, rect.height) * 0.06)
    }

    private func slidePanels(out: Bool) {
        host.slidePanels(out: out, duration: Self.handOffDuration)
    }

    private func fade(liveIn: Bool, animated: Bool) async {
        let live = host.liveController.view
        guard animated || liveIn else {
            live.alphaValue = 0
            host.setPanelsAlpha(1)
            return
        }
        guard animated else {
            live.alphaValue = 1
            host.setPanelsAlpha(0)
            return
        }
        await animate(Self.handOffDuration) {
            live.animator().alphaValue = liveIn ? 1 : 0
            self.host.setPanelsAlpha(liveIn ? 0 : 1, animated: true)
        }
    }

    private func animate(_ duration: TimeInterval, _ changes: @escaping () -> Void) async {
        await withCheckedContinuation { continuation in
            NSAnimationContext.runAnimationGroup { context in
                context.duration = duration
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                context.allowsImplicitAnimation = true
                CATransaction.begin()
                CATransaction.setAnimationDuration(duration)
                CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
                changes()
                CATransaction.commit()
            } completionHandler: {
                continuation.resume()
            }
        }
    }

    private func sleep(_ seconds: TimeInterval) async {
        try? await Task.sleep(for: .seconds(seconds))
    }
}

// Holds the snapshot that travels between the preview and the video, above everything else in the window.
final class SPLKTransitionOverlayView: NSView {

    private var snapshotLayer: CALayer?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    // frame is in this view's coordinates.
    func showSnapshot(_ image: CGImage, frame: CGRect) -> CALayer {
        clear()
        let layer = CALayer()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.contents = image
        layer.contentsGravity = .resize
        layer.masksToBounds = true
        layer.frame = frame
        self.layer?.addSublayer(layer)
        CATransaction.commit()
        snapshotLayer = layer
        return layer
    }

    func clear() {
        snapshotLayer?.removeFromSuperlayer()
        snapshotLayer = nil
    }
}
