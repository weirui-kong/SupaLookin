//
//  SPLKInspectableApp.swift
//  SupaLookin
//
//  Created by Li Kai on 2018/11/3.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Foundation
import SPLKProtocol
import SPLKModelBridge
import SPLKServer

final class SPLKInspectableApp {

    var serverVersionError: NSError?
    var appInfo: SPLKAppInfo?
    var session: SPLKDeviceSession?

    func fetchHierarchyData() async throws -> SPLKHierarchyInfo? {
        let info = try await requestSingle(.hierarchy) { try await $0.hierarchy() }
        // v2 hierarchies carry no app icon; v1's did, and the toolbar and exported documents show it.
        if let info, info.appInfo?.appIcon == nil {
            info.appInfo?.appIcon = appInfo?.appIcon
        }
        return info
    }

    func submitInbuiltModification(_ modification: SPLKAttributeModification) async throws -> Any? {
        try await requestSingle(.inbuiltModification) { try await $0.modify(modification) }
    }

    func submitCustomModification(_ modification: SPLKCustomAttrModification) async throws -> Any? {
        try await requestSingle(.customModification) { session -> Any? in
            try await session.modifyCustom(modification)
            return nil
        }
    }

    /// 每收到一批 detail 就调用一次 next
    /// The callbacks run on the main actor, as Peertalk's did. SPLKStaticAsyncUpdateManager relies on
    /// that: cancelling a fetch must run its completion before the next fetch is set up.
    func fetchHierarchyDetail(withTaskPackages packages: [SPLKStaticAsyncUpdateTasksPackage], next: @escaping (Any?) -> Void, failure: @escaping (Error) -> Void, completion: @escaping () -> Void) {
        request(.hierarchyDetails, open: { try await $0.details(packages) }, next: { next([$0]) }, failure: failure, completion: completion)
    }

    func cancelHierarchyDetailFetching() {
        cancelRequest(.hierarchyDetails)
    }

    /// Callbacks run on the main actor, like fetchHierarchyDetail's.
    func fetchModificationPatch(withTasks tasks: [SPLKStaticAsyncUpdateTask], next: @escaping (Any?) -> Void, failure: @escaping (Error) -> Void, completion: @escaping () -> Void) {
        request(.modificationPatch, open: { try await $0.modificationPatch(tasks) }, next: { next($0) }, failure: failure, completion: completion)
    }

    func fetchObject(withOid oid: UInt) async throws -> SPLKObject? {
        if oid == 0 {
            throw SPLKError.inner
        }
        return try await requestSingle(.object) { try await $0.object(oid: oid) }
    }

    func fetchSelectorNames(withClass className: String, hasArg: Bool) async throws -> [String]? {
        try await requestSingle(.selectorNames) { try await $0.selectorNames(className: className, hasArg: hasArg) }
    }

    func invokeMethod(withOid oid: UInt, text: String) async throws -> [String: Any]? {
        if oid == 0 || text.isEmpty {
            throw SPLKError.inner
        }
        guard var value = try await requestSingle(.invokeMethod, { try await $0.invoke(oid: oid, text: text) }) else {
            return nil
        }
        if value["description"] as? String == SPLKStringFlag_VoidReturn {
            // 方法没有返回值时，替换成本地说明
            value["description"] = NSLocalizedString("The method was invoked successfully and no value was returned.", comment: "")
        }
        return value
    }

    func fetchAttrGroupList(withOid oid: UInt) async throws -> [SPLKAttributesGroup]? {
        if oid == 0 {
            throw SPLKError.inner
        }
        return try await requestSingle(.attrGroups) { try await $0.attributeGroups(layerOid: oid) }
    }

    /// 获取某个 imageView 的 image 对象，oid 是 imageView 的 oid
    func fetchImage(withImageViewOid oid: UInt) async throws -> Any? {
        if oid == 0 {
            throw SPLKError.inner
        }
        return try await requestSingle(.imageViewImage) { try await $0.imageData(imageViewOid: oid) }
    }

    /// 修改一个 gestureRecognizer 的 enable 属性。如果 shouldBeEnabled 为 true 则表示想要把它的 enable 属性修改为 true
    func modifyGestureRecognizer(_ oid: UInt, toBeEnabled shouldBeEnabled: Bool) async throws -> Any? {
        if oid == 0 {
            throw SPLKError.inner
        }
        return try await requestSingle(.gestureRecognizer) { NSNumber(value: try await $0.setGestureRecognizer(oid: oid, enabled: shouldBeEnabled)) }
    }

    // MARK: - Private

    // v1 kept one request per type in flight: a newer one discarded the older, which failed with SPLKErrCode_Discard.
    private enum Kind {
        case hierarchy, hierarchyDetails, modificationPatch, inbuiltModification, customModification
        case object, selectorNames, invokeMethod, attrGroups, imageViewImage, gestureRecognizer
    }

    private final class Call {
        var ended = false
        var end: ((Error?) -> Void)?
        var task: Task<Void, Never>?
    }

    private var calls: [Kind: Call] = [:]

    private static var discardError: NSError {
        NSError(domain: SPLKErrorDomain, code: SPLKErrCode_Discard, userInfo: [
            NSLocalizedDescriptionKey: NSLocalizedString("The request is discarded due to a newer same request.", comment: ""),
        ])
    }

    private func begin(_ kind: Kind) -> Call {
        if let previous = calls[kind], !previous.ended {
            previous.end?(Self.discardError)
            previous.task?.cancel()
        }
        let call = Call()
        calls[kind] = call
        return call
    }

    private func finish(_ kind: Kind, _ call: Call) {
        if calls[kind] === call {
            calls[kind] = nil
        }
    }

    /// For requests answered by a single response. A request that ends without one, e.g. after a cancel, throws `CancellationError`.
    private func requestSingle<Value>(_ kind: Kind, _ operation: @escaping (SPLKDeviceSession) async throws -> Value?) async throws -> Value? {
        guard let session else {
            throw SPLKError.noConnect
        }
        let call = begin(kind)
        defer { finish(kind, call) }
        let box: SPLKMainBox<Value?> = try await withCheckedThrowingContinuation { continuation in
            call.end = { error in
                guard !call.ended else { return }
                call.ended = true
                continuation.resume(throwing: error ?? CancellationError())
            }
            call.task = Task {
                do {
                    let value = try await operation(session)
                    guard !call.ended else { return }
                    call.ended = true
                    continuation.resume(returning: SPLKMainBox(value: value))
                } catch {
                    call.end?(SPLKDeviceSession.translate(error))
                }
            }
        }
        return box.value
    }

    // Like RAC's flattenMap into an error, an error ends delivery: later responses and the completion are dropped.
    private func request(_ kind: Kind, open: @escaping (SPLKDeviceSession) async throws -> AsyncThrowingStream<SPLKV2StreamItem, Error>, next: @escaping (SPLKDisplayItemDetail) -> Void, failure: @escaping (Error) -> Void, completion: @escaping () -> Void) {
        guard let session else {
            failure(SPLKError.noConnect)
            return
        }
        let call = begin(kind)
        call.end = { error in
            guard !call.ended else { return }
            call.ended = true
            if let error {
                failure(error)
            } else {
                completion()
            }
        }
        call.task = Task {
            defer { finish(kind, call) }
            do {
                for try await item in try await open(session) {
                    guard !call.ended else { return }
                    if case .nodeDetail(let detail) = item.item {
                        next(SPLKBridge.detail(detail))
                    }
                }
                call.end?(nil)
            } catch {
                call.end?(SPLKDeviceSession.translate(error))
            }
        }
    }

    /// 取消先前发送的尚未完成的 request，这个 request 会被报告为 completion
    private func cancelRequest(_ kind: Kind) {
        guard let call = calls[kind] else {
            return
        }
        calls[kind] = nil
        call.end?(nil)
        call.task?.cancel()
        NSLog("Lookin - 用户手动取消 request")
    }
}

// The main actor resumes and reads it; the box only gets the value through the continuation.
private struct SPLKMainBox<Value>: @unchecked Sendable {
    let value: Value
}
