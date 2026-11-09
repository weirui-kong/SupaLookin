//
//  SPLKServerBootstrap.swift
//  SPLKServerSession
//
//  Created by Weirui Kong on 2026/11/10.
//

#if SHOULD_COMPILE_SPLK_SERVER

import Foundation
import UIKit
import SPLKProtocol
import SPLKModelBridge
import SPLKServer

// SPLKServerLoader finds this class by name once the app has finished launching.
@objc(SPLKServerBootstrap)
public final class SPLKServerBootstrap: NSObject {

    @objc public static func start() {
        MainActor.assumeIsolated {
            SPLKServerRuntime.shared.start()
        }
    }
}

@MainActor
final class SPLKServerRuntime {

    static let shared = SPLKServerRuntime()

    static let capabilities: Set<String> = [
        SPLKCapability.app, SPLKCapability.hierarchy, SPLKCapability.details,
        SPLKCapability.attrModify, SPLKCapability.attrCustom, SPLKCapability.attrGroups,
        SPLKCapability.object, SPLKCapability.objectInvoke, SPLKCapability.objectSelectors,
        SPLKCapability.image, SPLKCapability.gestureToggle,
        SPLKCapability.controlLease, SPLKCapability.events,
        SPLKCapability.actionSemantic, SPLKCapability.waitIdle, SPLKCapability.eventsHierarchy,
    ]

    let state = SPLKServerState()
    private var started = false
    private var host: SPLKHost?
    private var listener: SPLKListener?
    private var isBinding = false

    func start() {
        guard !started else { return }
        started = true
        let center = NotificationCenter.default
        center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { SPLKServerRuntime.shared.applicationDidBecomeActive() }
        }
        center.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { SPLKServerRuntime.shared.applicationWillResignActive() }
        }
        SPLKUIMonitor.shared.start(state: state)
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        center.addObserver(forName: UIDevice.orientationDidChangeNotification, object: nil, queue: .main) { _ in
            // The interface rotates after the device does.
            DispatchQueue.main.async {
                MainActor.assumeIsolated { SPLKServerRuntime.shared.state.setScreen(SPLKServerRuntime.screenInfo()) }
            }
        }
        host = SPLKHost(
            configuration: SPLKHost.Configuration(serverVersion: SPLK_SERVER_READABLE_VERSION, capabilities: Self.capabilities.union(SPLKServerInput.capabilities)),
            handler: SPLKServerRequestHandler(state: state),
            appSummary: { await SPLKServerRuntime.appSummary() }
        )
        if UIApplication.shared.applicationState == .active {
            applicationDidBecomeActive()
        }
    }

    private func applicationDidBecomeActive() {
        state.setActive(true)
        state.setScreen(Self.screenInfo())
        startListening()
    }

    private func applicationWillResignActive() {
        state.setActive(false)
        // v1 only kept its port while a client was connected.
        guard let host, let listener else { return }
        Task {
            if await host.currentSessionID == nil, self.listener === listener {
                listener.close()
                self.listener = nil
            }
        }
    }

    private func startListening() {
        guard listener == nil, !isBinding, let host else { return }
        isBinding = true
        NSLog("SPLKServer - Searching port to listen...")
        let ports = Self.ports
        Task {
            defer { isBinding = false }
            do {
                let listener = try await SPLKListener.bind(ports: ports)
                self.listener = listener
                await host.serve(listener)
                NSLog("SPLKServer - Connected successfully on 127.0.0.1:%d", Int32(listener.port))
            } catch {
                NSLog("SPLKServer - 127.0.0.1:%d-%d is unavailable(%@).", Int32(ports.lowerBound), Int32(ports.upperBound), String(describing: error))
            }
        }
    }

    private static var ports: ClosedRange<UInt16> {
        let simulator = UInt16(SPLKSimulatorIPv4PortNumberStart)...UInt16(SPLKSimulatorIPv4PortNumberEnd)
        let device = UInt16(SPLKUSBDeviceIPv4PortNumberStart)...UInt16(SPLKUSBDeviceIPv4PortNumberEnd)
        #if targetEnvironment(simulator) || targetEnvironment(macCatalyst)
        return simulator
        #else
        if #available(iOS 14.0, *), ProcessInfo.processInfo.isiOSAppOnMac {
            return simulator
        }
        return device
        #endif
    }

    // MARK: - Screen

    static func appSummary() -> SPLKV2AppSummary {
        let info = SPLKServerOperations.appInfo(withImages: false, localIdentifiers: [])
        return SPLKBridge.summary(info, screen: screenInfo())
    }

    static func screenInfo() -> SPLKV2ScreenInfo {
        var message = SPLKV2ScreenInfo()
        let window = keyWindow()
        let screen = window?.screen ?? UIScreen.main
        var size = SPLKV2Size()
        size.width = Double(screen.bounds.width)
        size.height = Double(screen.bounds.height)
        message.size = size
        message.scale = Double(screen.scale)
        switch window?.windowScene?.interfaceOrientation {
        case .portrait: message.orientation = .portrait
        case .portraitUpsideDown: message.orientation = .portraitUpsideDown
        case .landscapeLeft: message.orientation = .landscapeLeft
        case .landscapeRight: message.orientation = .landscapeRight
        default: message.orientation = .unspecified
        }
        if let insets = window?.safeAreaInsets {
            var safeArea = SPLKV2Insets()
            safeArea.top = Double(insets.top)
            safeArea.left = Double(insets.left)
            safeArea.bottom = Double(insets.bottom)
            safeArea.right = Double(insets.right)
            message.safeArea = safeArea
        }
        return message
    }

    static func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }
}

#endif
