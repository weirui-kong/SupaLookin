//
//  SPLKVideoSource.swift
//  SupaLookin
//
//  Created by Weirui Kong on 2026/11/10.
//

import Foundation
import Combine
import CoreImage
import CoreVideo
import SPLKProtocol

struct SPLKVideoFrame {
    let pixelBuffer: CVPixelBuffer
    let time: TimeInterval
}

enum SPLKVideoTarget: Equatable {
    case simulator(udid: String?)
    case usbDevice(serialNumber: String?)
}

nonisolated struct SPLKVideoError: LocalizedError {
    let errorDescription: String?
    let recoverySuggestion: String?

    init(_ description: String, _ suggestion: String? = nil) {
        errorDescription = description
        recoverySuggestion = suggestion
    }
}

// Subclasses capture; this class counts users so the window and agents can start and stop independently.
class SPLKVideoSource {

    let frames = CurrentValueSubject<SPLKVideoFrame?, Never>(nil)

    private var users = 0
    private var starting: Task<Void, Error>?
    private(set) var isRunning = false

    // How long snapshot() waits for the first frame.
    var firstFrameTimeout: TimeInterval { 5 }

    func start() async throws {
        users += 1
        if isRunning {
            return
        }
        let task: Task<Void, Error>
        if let starting {
            task = starting
        } else {
            task = Task { try await self.startCapture() }
            starting = task
        }
        do {
            try await task.value
        } catch {
            if starting == task {
                starting = nil
            }
            users -= 1
            throw error
        }
        if starting == task {
            starting = nil
            isRunning = true
        }
        // Everyone may have stopped while capture was starting.
        if users == 0, isRunning {
            isRunning = false
            stopCapture()
            frames.send(nil)
        }
    }

    func stop() {
        guard users > 0 else {
            return
        }
        users -= 1
        if users == 0, isRunning {
            isRunning = false
            stopCapture()
            frames.send(nil)
        }
    }

    func startCapture() async throws {
        fatalError("subclasses capture")
    }

    func stopCapture() {
        fatalError("subclasses capture")
    }

    func publish(_ pixelBuffer: CVPixelBuffer) {
        frames.send(SPLKVideoFrame(pixelBuffer: pixelBuffer, time: ProcessInfo.processInfo.systemUptime))
    }

    // MARK: - Snapshots

    func snapshot(screen: SPLKV2ScreenInfo) async throws -> CGImage {
        try await start()
        defer { stop() }
        let frame = try await firstFrame()
        guard let image = Self.image(of: frame.pixelBuffer, screen: screen) else {
            throw SPLKVideoError(NSLocalizedString("Failed to read the video frame.", comment: ""))
        }
        return image
    }

    private func firstFrame() async throws -> SPLKVideoFrame {
        if let frame = frames.value {
            return frame
        }
        var subscription: AnyCancellable?
        defer { subscription?.cancel() }
        let timeout = firstFrameTimeout
        return try await withCheckedThrowingContinuation { continuation in
            var resumed = false
            subscription = frames.compactMap { $0 }.first().sink { frame in
                guard !resumed else { return }
                resumed = true
                continuation.resume(returning: frame)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
                MainActor.assumeIsolated {
                    guard !resumed else { return }
                    resumed = true
                    continuation.resume(throwing: SPLKVideoError(NSLocalizedString("The video source sent no frame.", comment: "")))
                }
            }
        }
    }

    private static let context = CIContext(options: [.cacheIntermediates: false])

    static func image(of pixelBuffer: CVPixelBuffer, screen: SPLKV2ScreenInfo) -> CGImage? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        var image = CIImage(cvPixelBuffer: pixelBuffer)
        switch rotation(frameWidth: width, frameHeight: height, screen: screen) {
        case .none: break
        case .clockwise: image = image.oriented(.right)
        case .counterclockwise: image = image.oriented(.left)
        }
        return context.createCGImage(image, from: image.extent)
    }

    enum Rotation: Equatable {
        case none, clockwise, counterclockwise
    }

    // Input is normalized to the interface orientation, so frames are turned to it too.
    nonisolated static func rotation(frameWidth: Int, frameHeight: Int, screen: SPLKV2ScreenInfo) -> Rotation {
        let frameIsLandscape = frameWidth > frameHeight
        let screenIsLandscape = screen.size.width > screen.size.height
        guard frameIsLandscape != screenIsLandscape, screen.size.width > 0, screen.size.height > 0 else {
            return .none
        }
        switch screen.orientation {
        case .landscapeLeft: return frameIsLandscape ? .counterclockwise : .clockwise
        case .landscapeRight: return frameIsLandscape ? .clockwise : .counterclockwise
        default: return .none
        }
    }
}
