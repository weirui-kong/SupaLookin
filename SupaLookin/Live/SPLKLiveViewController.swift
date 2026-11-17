//
//  SPLKLiveViewController.swift
//  SupaLookin
//
//  Created by Weirui Kong on 2026/11/10.
//

import Cocoa
import Combine
import SPLKProtocol

enum SPLKWindowMode: Equatable {
    case inspect
    case liveControl
    case takeover(label: String)

    init(_ mode: SPLKControlArbiter.Mode) {
        switch mode {
        case .inspect: self = .inspect
        case .liveControl: self = .liveControl
        case .takeover(_, let label): self = .takeover(label: label)
        }
    }

    var showsVideo: Bool { self != .inspect }
}

// The window's content in Live Control and Takeover: the phone's live video and nothing else.
final class SPLKLiveViewController: NSViewController {

    let videoView = SPLKVideoView()

    private(set) weak var session: SPLKDeviceSession?

    var mode = SPLKWindowMode.liveControl {
        didSet { updateMode() }
    }

    private let pill = NSTextField(labelWithString: "")
    private let pillBackground = NSView()
    private let errorLabel = NSTextField(wrappingLabelWithString: "")
    private let note = NSTextField(wrappingLabelWithString: "")
    private let helpButton = NSButton()
    private var availability = SPLKDeviceSession.InputAvailability.unknown
    private var availabilitySubscription: AnyCancellable?
    private var lockRetryTask: Task<Void, Never>?
    private let retryButton = NSButton(title: NSLocalizedString("Try Again", comment: ""), target: nil, action: nil)
    private var frameSubscription: AnyCancellable?
    private var screenTask: Task<Void, Never>?
    private var inputTask: Task<Void, Never>?
    private var input: AsyncStream<[SPLKV2InputEvent]>.Continuation?
    private var attachment = UUID()
    private var isVideoStarted = false

    // The stage color of the 3D preview, so the hand-off between them has no seam.
    static let backgroundColor = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .black : .white
    }

    override func loadView() {
        let view = SPLKLiveBackgroundView()
        view.wantsLayer = true
        self.view = view

        view.addSubview(videoView)

        note.font = .systemFont(ofSize: 11)
        note.textColor = .secondaryLabelColor
        note.isHidden = true
        view.addSubview(note)

        helpButton.attributedTitle = NSAttributedString(string: NSLocalizedString("Need help?", comment: ""), attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.linkColor,
        ])
        helpButton.isBordered = false
        helpButton.setButtonType(.momentaryChange)
        helpButton.toolTip = NSLocalizedString("Operating Devices", comment: "")
        helpButton.target = self
        helpButton.action = #selector(showHelp)
        view.addSubview(helpButton)

        pillBackground.wantsLayer = true
        pillBackground.layer?.cornerRadius = 11
        pillBackground.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        pill.font = .systemFont(ofSize: 12, weight: .medium)
        pill.textColor = .secondaryLabelColor
        pill.alignment = .center
        pillBackground.addSubview(pill)
        view.addSubview(pillBackground)

        errorLabel.alignment = .center
        errorLabel.textColor = .secondaryLabelColor
        errorLabel.isHidden = true
        view.addSubview(errorLabel)

        retryButton.bezelStyle = .rounded
        retryButton.target = self
        retryButton.action = #selector(retry)
        retryButton.isHidden = true
        view.addSubview(retryButton)

        videoView.onInput = { [weak self] events in
            self?.input?.yield(events)
        }
        updateMode()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        let top = SPLKNavigationManager.sharedInstance.windowTitleBarHeight + 28
        videoView.frame = NSRect(x: 0, y: 0, width: view.bounds.width, height: max(view.bounds.height - top, 0))
        videoView.layoutSubtreeIfNeeded()

        pill.sizeToFit()
        let pillSize = NSSize(width: pill.frame.width + 20, height: 22)
        let midX = videoView.hasFrame ? videoView.videoRect.midX : view.bounds.midX
        let pillY = videoView.hasFrame ? videoView.videoRect.maxY + 6 : view.bounds.height - top + 6
        pillBackground.frame = NSRect(x: midX - pillSize.width / 2, y: pillY, width: pillSize.width, height: pillSize.height).integral
        pill.frame = NSRect(x: 10, y: (pillSize.height - pill.frame.height) / 2, width: pill.frame.width, height: pill.frame.height)

        helpButton.sizeToFit()
        helpButton.setFrameOrigin(NSPoint(x: 16, y: 9))
        let noteX: CGFloat = helpButton.isHidden ? 16 : helpButton.frame.maxX + 12
        let noteWidth = min(view.bounds.width - noteX - 16, 520)
        let noteSize = note.sizeThatFits(NSSize(width: noteWidth, height: .greatestFiniteMagnitude))
        note.frame = NSRect(x: noteX, y: 12, width: noteWidth, height: noteSize.height)

        let errorWidth = min(view.bounds.width - 80, 420)
        let errorSize = errorLabel.sizeThatFits(NSSize(width: errorWidth, height: .greatestFiniteMagnitude))
        errorLabel.frame = NSRect(x: (view.bounds.width - errorWidth) / 2, y: view.bounds.midY, width: errorWidth, height: errorSize.height)
        retryButton.sizeToFit()
        retryButton.setFrameOrigin(NSPoint(x: (view.bounds.width - retryButton.frame.width) / 2, y: view.bounds.midY - retryButton.frame.height - 12))
    }

    private func updateMode() {
        switch mode {
        case .inspect, .liveControl:
            pill.stringValue = NSLocalizedString("Live Control", comment: "")
            videoView.isInputEnabled = mode == .liveControl && availability.acceptsInput
        case .takeover(let label):
            pill.stringValue = String(format: NSLocalizedString("%@ is controlling the app", comment: ""), label)
            videoView.isInputEnabled = false
        }
        helpButton.isHidden = mode != .liveControl
        if mode == .liveControl {
            view.window?.makeFirstResponder(videoView)
        }
        view.needsLayout = true
    }

    // MARK: - Session

    func attach(_ session: SPLKDeviceSession) {
        guard self.session !== session else { return }
        detach()
        self.session = session
        let attachment = UUID()
        self.attachment = attachment
        videoView.screen = session.client.serverHello.app.screen

        frameSubscription = session.video.frames.sink { [weak self] frame in
            guard let self, let frame else { return }
            let hadFrame = self.videoView.hasFrame
            self.videoView.display(frame)
            if !hadFrame {
                self.view.needsLayout = true
            }
        }
        startVideo(session, attachment: attachment)

        screenTask = Task { [weak self] in
            guard let events = try? await session.events(topics: ["screen"]) else { return }
            do {
                for try await item in events {
                    if case .screen(let screen) = item.event.kind {
                        self?.videoView.screen = screen
                        self?.view.needsLayout = true
                    }
                }
            } catch {}
        }

        // Settles what input the session takes now, so the first touch doesn't wait for it.
        availabilitySubscription = session.inputAvailability.removeDuplicates().sink { [weak self] availability in
            self?.availabilityDidChange(availability)
        }
        Task { await session.refreshInputAvailability() }

        // One consumer keeps input in the order the user made it.
        let (stream, continuation) = AsyncStream.makeStream(of: [SPLKV2InputEvent].self)
        input = continuation
        inputTask = Task { [weak session, weak self] in
            for await events in stream {
                guard let session else { return }
                let screen = self?.videoView.screen ?? session.client.serverHello.app.screen
                do {
                    try await session.deliverInput(events, screen: screen)
                } catch {
                    NSLog("SupaLookin - input failed: %@", String(describing: error))
                }
            }
        }
    }

    func detach() {
        videoView.cancelInput()
        attachment = UUID()
        if isVideoStarted {
            session?.video.stop()
            isVideoStarted = false
        }
        frameSubscription = nil
        screenTask?.cancel()
        screenTask = nil
        input?.finish()
        input = nil
        inputTask = nil
        videoView.clear()
        showError(nil)
        availabilitySubscription = nil
        lockRetryTask?.cancel()
        lockRetryTask = nil
        availability = .unknown
        note.isHidden = true
        session = nil
    }

    private func startVideo(_ session: SPLKDeviceSession, attachment: UUID) {
        showError(nil)
        Task { [weak self] in
            do {
                try await session.video.start()
                guard let self, self.attachment == attachment else {
                    session.video.stop()
                    return
                }
                self.isVideoStarted = true
            } catch {
                guard let self, self.attachment == attachment else { return }
                self.showError(error)
            }
        }
    }

    @objc private func retry() {
        guard let session, !isVideoStarted else { return }
        startVideo(session, attachment: attachment)
    }

    private func showError(_ error: Error?) {
        if let error {
            let suggestion = (error as? LocalizedError)?.recoverySuggestion
            errorLabel.stringValue = [error.localizedDescription, suggestion].compactMap { $0 }.joined(separator: "\n")
        }
        errorLabel.isHidden = error == nil
        retryButton.isHidden = error == nil
        view.needsLayout = true
    }

    func shake() {
        guard mode == .liveControl, availability.acceptsInput else { return }
        input?.yield([SPLKLiveInputMapper.shake()])
    }

    private func availabilityDidChange(_ availability: SPLKDeviceSession.InputAvailability) {
        self.availability = availability
        updateMode()
        if case .watchOnly(let reason) = availability {
            note.stringValue = Self.note(for: reason)
            note.isHidden = false
        } else {
            note.isHidden = true
        }
        // The helper can't announce an unlock to a client it refused, so a locked device is asked again.
        lockRetryTask?.cancel()
        lockRetryTask = nil
        if availability == .watchOnly(.locked), let session {
            lockRetryTask = Task { [weak session] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(3))
                    guard !Task.isCancelled, let session, session.inputAvailability.value == .watchOnly(.locked) else { return }
                    await session.refreshInputAvailability()
                }
            }
        }
        view.needsLayout = true
    }

    @objc private func showHelp() {
        presentAsSheet(SPLKControlHelpViewController(session: session))
    }

    static func note(for reason: SPLKDeviceSession.WatchOnlyReason) -> String {
        switch reason {
        case .comingSoon:
            return NSLocalizedString("Operating devices on iOS 27 or later is coming soon. This device can only be watched.", comment: "")
        case .needsJailbreak:
            return NSLocalizedString("Operating this device needs a jailbreak and the SupaLookin helper. This device can only be watched.", comment: "")
        case .locked:
            return NSLocalizedString("Unlock the device to operate it.", comment: "")
        }
    }

    func press(_ button: SPLKHostButton) {
        guard mode == .liveControl, let session else { return }
        Task { [weak self] in
            do {
                try await session.press(button)
            } catch {
                SPLKHelper.alertError(error, window: self?.view.window)
            }
        }
    }

    // The frame on screen now, turned as the video shows it.
    func currentFrameImage() -> CGImage? {
        guard let frame = session?.video.frames.value else { return nil }
        return SPLKVideoSource.image(of: frame.pixelBuffer, screen: videoView.screen)
    }

    var pillView: NSView { pillBackground }
}

private final class SPLKLiveBackgroundView: NSView {

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        layer?.backgroundColor = SPLKLiveViewController.backgroundColor.cgColor
    }
}
