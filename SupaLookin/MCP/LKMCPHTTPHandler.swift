//
//  LKMCPHTTPHandler.swift
//  SupaLookin
//
//  Created by Weirui Kong on 2026/10/25.
//

import Foundation
import FlyingFox
import FlyingSocks
import MCP

// The HTTP side runs off the main actor: FlyingFox calls the route from its own tasks, and the SDK's server and transport are actors.
nonisolated enum LKMCPHTTPHandler {

    static func response(for request: FlyingFox.HTTPRequest, token: String, router: LKMCPSessionRouter) async -> FlyingFox.HTTPResponse {
        guard request.headers[.authorization] == "Bearer \(token)" else {
            let body = #"{"error":"Missing or wrong bearer token. Copy the command from Supa Lookin's Preferences."}"#
            return FlyingFox.HTTPResponse(statusCode: .unauthorized, headers: HTTPHeaders([.contentType: "application/json"]), body: Data(body.utf8))
        }

        var headers: [String: String] = [:]
        for (header, value) in request.headers {
            headers[header.rawValue] = value
        }
        let body = (try? await request.bodyData) ?? Data()
        let mcpRequest = MCP.HTTPRequest(method: request.method.rawValue, headers: headers, body: body.isEmpty ? nil : body, path: request.path)
        let mcpResponse = await router.handle(mcpRequest)

        var responseHeaders = HTTPHeaders()
        for (name, value) in mcpResponse.headers {
            responseHeaders[HTTPHeader(name)] = value
        }
        if case .stream(let stream, _) = mcpResponse {
            return FlyingFox.HTTPResponse(statusCode: .ok, headers: responseHeaders, body: HTTPBodySequence(from: LKMCPStreamBody(stream: stream)))
        }
        return FlyingFox.HTTPResponse(statusCode: HTTPStatusCode(mcpResponse.statusCode, phrase: ""), headers: responseHeaders, body: mcpResponse.bodyData ?? Data())
    }
}

// FlyingFox has no public way to stream an arbitrary async sequence as a body, which SSE needs
nonisolated struct LKMCPStreamBody: AsyncBufferedSequence {

    typealias Element = UInt8

    let stream: AsyncThrowingStream<Data, Error>

    func makeAsyncIterator() -> Iterator {
        Iterator(base: stream.makeAsyncIterator())
    }

    struct Iterator: AsyncBufferedIteratorProtocol {

        var base: AsyncThrowingStream<Data, Error>.AsyncIterator
        var pending = Data()

        mutating func next() async throws -> UInt8? {
            try await nextBuffer(suggested: 1)?.first
        }

        mutating func nextBuffer(suggested count: Int) async throws -> [UInt8]? {
            while pending.isEmpty {
                guard let chunk = try await base.next() else {
                    return nil
                }
                pending = chunk
            }
            let length = Swift.min(count, pending.count)
            let buffer = Array(pending.prefix(length))
            pending.removeFirst(length)
            return buffer
        }
    }
}

// Each StatefulHTTPServerTransport serves one session, so every initialize gets its own transport and server
actor LKMCPSessionRouter {

    static let maxSessions = 16

    private struct Session {
        let transport: StatefulHTTPServerTransport
        let server: Server
    }

    private var sessions: [String: Session] = [:]
    private var sessionOrder: [String] = []

    func handle(_ request: MCP.HTTPRequest) async -> MCP.HTTPResponse {
        if let sessionID = request.header("Mcp-Session-Id") {
            guard let session = sessions[sessionID] else {
                return .error(statusCode: 404, .invalidRequest("Session not found"))
            }
            let response = await session.transport.handleRequest(request)
            if request.method == "DELETE" {
                await remove(sessionID)
            }
            return response
        }

        let transport = StatefulHTTPServerTransport()
        let server = await LKMCPTools.makeServer()
        do {
            try await server.start(transport: transport)
        } catch {
            return .error(statusCode: 500, .internalError(String(describing: error)))
        }
        let response = await transport.handleRequest(request)
        guard let sessionID = response.headers.first(where: { $0.key.lowercased() == "mcp-session-id" })?.value else {
            await server.stop()
            return response
        }
        sessions[sessionID] = Session(transport: transport, server: server)
        sessionOrder.append(sessionID)
        if sessionOrder.count > LKMCPSessionRouter.maxSessions {
            await remove(sessionOrder[0])
        }
        return response
    }

    func closeAll() async {
        for sessionID in sessionOrder {
            await remove(sessionID)
        }
    }

    private func remove(_ sessionID: String) async {
        sessionOrder.removeAll { $0 == sessionID }
        if let session = sessions.removeValue(forKey: sessionID) {
            await session.server.stop()
        }
    }
}
