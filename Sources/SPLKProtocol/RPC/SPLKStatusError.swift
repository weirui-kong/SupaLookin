//
//  SPLKStatusError.swift
//  SPLKProtocol
//
//  Created by Weirui Kong on 2026/11/10.
//

import Foundation

public struct SPLKStatusError: Error, Sendable, Equatable {

    public enum Code: Sendable, Equatable {
        case cancelled
        case invalidArgument
        case notFound
        case deadlineExceeded
        case unimplemented
        case failedPrecondition
        case permissionDenied
        case resourceExhausted
        case `internal`
        // Local only: the connection closed before an answer came. Never sent.
        case unavailable
    }

    public var code: Code
    public var reason: String
    public var title: String
    public var detail: String

    public init(_ code: Code, reason: String = "", title: String = "", detail: String = "") {
        self.code = code
        self.reason = reason
        self.title = title
        self.detail = detail
    }

    // nil for OK.
    public init?(status: SPLKV2Status) {
        let code: Code
        switch status.code {
        case .ok: return nil
        case .cancelled: code = .cancelled
        case .invalidArgument: code = .invalidArgument
        case .notFound: code = .notFound
        case .deadlineExceeded: code = .deadlineExceeded
        case .unimplemented: code = .unimplemented
        case .failedPrecondition: code = .failedPrecondition
        case .permissionDenied: code = .permissionDenied
        case .resourceExhausted: code = .resourceExhausted
        case .internal, .UNRECOGNIZED: code = .internal
        }
        self.init(code, reason: status.reason, title: status.title, detail: status.detail)
    }

    public var status: SPLKV2Status {
        var status = SPLKV2Status()
        switch code {
        case .cancelled: status.code = .cancelled
        case .invalidArgument: status.code = .invalidArgument
        case .notFound: status.code = .notFound
        case .deadlineExceeded: status.code = .deadlineExceeded
        case .unimplemented: status.code = .unimplemented
        case .failedPrecondition: status.code = .failedPrecondition
        case .permissionDenied: status.code = .permissionDenied
        case .resourceExhausted: status.code = .resourceExhausted
        case .internal, .unavailable: status.code = .internal
        }
        status.reason = reason
        status.title = title
        status.detail = detail
        return status
    }

    static func from(_ error: Error) -> SPLKStatusError {
        if let error = error as? SPLKStatusError {
            return error
        }
        if error is CancellationError {
            return SPLKStatusError(.cancelled)
        }
        return SPLKStatusError(.internal, detail: String(describing: error))
    }
}

extension SPLKV2Status {
    static let ok = SPLKV2Status()
}
