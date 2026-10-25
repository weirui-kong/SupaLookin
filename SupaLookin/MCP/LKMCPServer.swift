//
//  LKMCPServer.swift
//  SupaLookin
//
//  Created by Weirui Kong on 2026/10/25.
//

import Cocoa
import Combine
import FlyingFox
import FlyingSocks

enum LKMCPServerStatus: Equatable {
    case stopped
    case starting
    case running(URL)
    case failed(String)
}

private let Key_Enabled = "mcpEnabled"
private let Key_Port = "mcpPort"
private let Key_Token = "mcpToken"

final class LKMCPServer {

    static let sharedInstance = LKMCPServer()

    static let defaultPort: UInt16 = 47200

    private let userDefaults: UserDefaults
    private var httpServer: HTTPServer?
    private var router: LKMCPSessionRouter?
    private var runTask: Task<Void, Never>?
    private var stopTask: Task<Void, Never>?

    private(set) var status: LKMCPServerStatus = .stopped {
        didSet {
            statusObservation.notify()
        }
    }

    private lazy var statusObservation = LKKVOSubject { [unowned self] in self.status }
    var statusPublisher: AnyPublisher<LKMCPServerStatus, Never> { statusObservation.publisher }

    let token: String

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if let token = userDefaults.string(forKey: Key_Token), !token.isEmpty {
            self.token = token
        } else {
            var bytes = [UInt8](repeating: 0, count: 32)
            if SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess {
                token = bytes.map { String(format: "%02x", $0) }.joined()
            } else {
                token = (UUID().uuidString + UUID().uuidString).replacingOccurrences(of: "-", with: "").lowercased()
            }
            userDefaults.set(token, forKey: Key_Token)
        }
    }

    var isEnabled: Bool {
        get {
            userDefaults.object(forKey: Key_Enabled) as? Bool ?? true
        }
        set {
            // Preferences reassigns the current value whenever it renders, which must not restart anything
            guard newValue != isEnabled else {
                return
            }
            userDefaults.set(newValue, forKey: Key_Enabled)
            if newValue {
                start()
            } else {
                stop()
            }
        }
    }

    var port: UInt16 {
        let value = userDefaults.integer(forKey: Key_Port)
        return (1...Int(UInt16.max)).contains(value) ? UInt16(value) : LKMCPServer.defaultPort
    }

    var url: URL {
        URL(string: "http://127.0.0.1:\(port)/mcp")!
    }

    var clientCommand: String {
        "claude mcp add --transport http supalookin \(url.absoluteString) --header \"Authorization: Bearer \(token)\""
    }

    func startIfEnabled() {
        if isEnabled {
            start()
        }
    }

    func start() {
        guard httpServer == nil else {
            return
        }
        let port = port
        let url = url
        let address: sockaddr_in
        do {
            address = try .inet(ip4: "127.0.0.1", port: port)
        } catch {
            status = .failed(String(describing: error))
            return
        }
        let server = HTTPServer(address: address)
        let router = LKMCPSessionRouter()
        let token = token
        // A server that is still shutting down holds the port until it's done
        let previousStop = stopTask
        httpServer = server
        self.router = router
        status = .starting

        runTask = Task { [weak self] in
            await previousStop?.value
            guard !Task.isCancelled else {
                return
            }
            await server.appendRoute("/mcp") { request in
                await LKMCPHTTPHandler.response(for: request, token: token, router: router)
            }
            let listening = Task { [weak self] in
                guard (try? await server.waitUntilListening()) != nil, let self, self.httpServer === server else {
                    return
                }
                self.status = .running(url)
            }
            do {
                // run() isn't running yet when stop() comes right after start(), so cancellation is what stops it
                try await withTaskCancellationHandler {
                    try await server.run()
                } onCancel: {
                    Task {
                        await server.stop()
                    }
                }
            } catch {
                listening.cancel()
                guard let self, self.httpServer === server else { return }
                self.httpServer = nil
                self.router = nil
                if case SocketError.failed(_, let errno, _) = error, errno == EADDRINUSE {
                    self.status = .failed(String(format: NSLocalizedString("Port %@ is unavailable.", comment: ""), "\(port)"))
                } else {
                    self.status = .failed(error.localizedDescription)
                }
            }
        }
    }

    func stop() {
        status = .stopped
        guard let server = httpServer else {
            return
        }
        let router = router
        let runTask = runTask
        httpServer = nil
        self.router = nil
        self.runTask = nil
        runTask?.cancel()
        // The next start() waits for this, so the port is free again by then
        stopTask = Task {
            await router?.closeAll()
            await server.stop()
            await runTask?.value
        }
    }
}
