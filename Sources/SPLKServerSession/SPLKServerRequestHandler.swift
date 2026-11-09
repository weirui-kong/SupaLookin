//
//  SPLKServerRequestHandler.swift
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

// Objective-C models aren't Sendable; each crosses from the main actor once and is only read afterwards.
struct SPLKTransfer<Value>: @unchecked Sendable {
    let value: Value
}

struct SPLKServerRequestHandler: SPLKRequestHandler {

    let state: SPLKServerState

    // The builders gate custom info on a v1 client version of at least 1.0.4, and assert on malformed versions.
    // Every v2 client has those features, so the peer's own version never reaches them.
    static let v1FeatureVersion = "1.0.4"

    // Converting, PNG encoding included, stays off the main thread, in arrival order.
    private static let conversionQueue = DispatchQueue(label: "SPLKServerSession.conversion")

    func handle(_ request: SPLKV2Request, context: SPLKRequestContext) async throws -> SPLKHandlerResult {
        switch request.call {
        case .subscribe, .releaseControl:
            break
        default:
            guard state.isActive else {
                throw SPLKStatusError(.failedPrecondition, reason: SPLKBridge.Reason.appInBackground)
            }
        }
        try state.authorize(request, session: context.sessionID)

        switch request.call {
        case .getAppInfo(let call):
            let info = await MainActor.run {
                SPLKTransfer(value: SPLKServerOperations.appInfo(withImages: call.needImages, localIdentifiers: call.cachedIdentifiers.map { NSNumber(value: $0) }))
            }
            let screen = await MainActor.run { SPLKServerRuntime.screenInfo() }
            return .response(.appInfo(SPLKBridge.appInfoMessage(info.value, screen: screen)))

        case .getHierarchy:
            let (info, screen) = await MainActor.run {
                (SPLKTransfer(value: SPLKServerOperations.hierarchy(withClientVersion: Self.v1FeatureVersion)), SPLKServerRuntime.screenInfo())
            }
            let version = await MainActor.run { SPLKUIMonitor.shared.currentGeneration() }
            return .response(.hierarchy(SPLKBridge.snapshot(info.value, version: version, screen: screen)))

        case .fetchDetails(let call):
            let packages = SPLKTransfer(value: call.packages.map { SPLKBridge.package($0, clientVersion: Self.v1FeatureVersion) })
            return .stream(Self.detailStream { progress, finished in
                await MainActor.run {
                    SPLKTransfer(value: SPLKServerOperations.fetchDetails(packages: packages.value, progress: { details in
                        details.forEach(progress)
                    }, finished: finished))
                }
            } cancel: { token in
                await MainActor.run { SPLKServerOperations.cancelDetailsFetching(token.value) }
            })

        case .modifyAttribute(let call):
            let modification = SPLKTransfer(value: SPLKBridge.modification(call, clientVersion: Self.v1FeatureVersion))
            let detail: SPLKTransfer<SPLKDisplayItemDetail?> = try await Self.reply { reply in
                SPLKServerOperations.modifyAttribute(modification.value) { detail, error in reply(detail, error) }
            }
            return .response(detail.value.map { .nodeDetail(SPLKBridge.detailMessage($0)) })

        case .fetchModificationPatch(let call):
            let tasks = SPLKTransfer(value: call.tasks.map { SPLKBridge.task($0, clientVersion: Self.v1FeatureVersion) })
            let expected = call.tasks.count
            return .stream(Self.detailStream(expected: expected) { progress, _ in
                await MainActor.run {
                    SPLKServerOperations.fetchModificationPatch(tasks: tasks.value, progress: progress)
                    return SPLKTransfer(value: NSNull() as Any)
                }
            } cancel: { _ in })

        case .modifyCustomAttribute(let call):
            let modification = SPLKTransfer(value: SPLKBridge.customModification(call))
            let succeeded = await MainActor.run { SPLKServerOperations.modifyCustomAttribute(modification.value) }
            guard succeeded else {
                throw SPLKStatusError(.internal, reason: SPLKBridge.Reason.inner)
            }
            return .response(.empty(SPLKV2Empty()))

        case .invokeMethod(let call):
            let result: SPLKTransfer<[String: Any]?> = try await Self.reply { reply in
                SPLKServerOperations.invokeMethod(oid: UInt(call.oid), text: call.text) { result, error in reply(result, error) }
            }
            var message = SPLKV2InvokeResult()
            let description = result.value?["description"] as? String
            if description == SPLKStringFlag_VoidReturn {
                message.returnsVoid = true
            } else {
                message.description_p = description ?? ""
            }
            if let object = result.value?["object"] as? SPLKObject {
                message.object = SPLKBridge.objectRef(object)
            }
            return .response(.invokeResult(message))

        case .getObject(let call):
            let object = await MainActor.run { SPLKTransfer(value: SPLKServerOperations.object(withOid: UInt(call.oid))) }
            return .response(object.value.map { .object(SPLKBridge.objectRef($0)) })

        case .getImageViewImage(let call):
            let data: SPLKTransfer<Data?> = try await Self.reply { reply in
                SPLKServerOperations.imageData(imageViewOid: UInt(call.oid)) { data, error in reply(data, error) }
            }
            return .response(SPLKBridge.encodedImage(data: data.value).map { .image($0) })

        case .setGestureRecognizerEnabled(let call):
            let enabled: SPLKTransfer<NSNumber?> = try await Self.reply { reply in
                SPLKServerOperations.setGestureRecognizer(oid: UInt(call.oid), enabled: call.enabled) { enabled, error in reply(enabled, error) }
            }
            return .response(.gestureEnabled(enabled.value?.boolValue ?? false))

        case .getAttributeGroups(let call):
            let groups: SPLKTransfer<[SPLKAttributesGroup]?> = try await Self.reply { reply in
                SPLKServerOperations.attributeGroups(layerOid: UInt(call.oid)) { groups, error in reply(groups, error) }
            }
            var list = SPLKV2AttributeGroupList()
            list.groups = (groups.value ?? []).map(SPLKBridge.groupMessage)
            return .response(.attributeGroups(list))

        case .listSelectors(let call):
            let names: SPLKTransfer<[String]?> = try await Self.reply { reply in
                SPLKServerOperations.selectorNames(className: call.className, hasArg: call.hasArg_p) { names, error in reply(names, error) }
            }
            var list = SPLKV2StringList()
            list.values = names.value ?? []
            return .response(.selectors(list))

        case .acquireControl(let call):
            return .response(.lease(try state.acquire(call, session: context.sessionID).message))

        case .releaseControl(let call):
            state.release(leaseID: call.leaseID)
            return .response(.empty(SPLKV2Empty()))

        case .subscribe(let call):
            return .stream(state.subscribe(Set(call.topics)))

        case .injectInput(let call):
            try await SPLKServerInput.replay(call.events)
            return .response(nil)

        case .performAction(let call):
            return .response(.actionResult(try await SPLKServerActions.perform(call)))

        case .waitForIdle(let call):
            let timeout = call.timeoutMs == 0 ? 2 : TimeInterval(call.timeoutMs) / 1000
            return .response(.actionResult(await SPLKServerActions.waitForIdle(timeout: timeout)))

        case nil:
            throw SPLKStatusError(.unimplemented)
        }
    }

    func sessionDidEnd(_ sessionID: Data) async {
        state.sessionEnded(sessionID)
    }

    // Runs an operation that answers once through a (value, error) block on the main actor.
    private static func reply<Value>(_ operation: @escaping @MainActor (@escaping (Value?, Error?) -> Void) -> Void) async throws -> SPLKTransfer<Value?> {
        try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                operation { value, error in
                    if let error {
                        continuation.resume(throwing: SPLKBridge.statusError(error as NSError))
                    } else {
                        continuation.resume(returning: SPLKTransfer(value: value))
                    }
                }
            }
        }
    }

    // Streams details from an operation that reports them through a block, until `finished` or `expected` of them.
    private static func detailStream(
        expected: Int? = nil,
        start: @escaping @Sendable (_ progress: @escaping @Sendable (SPLKDisplayItemDetail) -> Void, _ finished: @escaping @Sendable () -> Void) async -> SPLKTransfer<Any>,
        cancel: @escaping @Sendable (SPLKTransfer<Any>) async -> Void
    ) -> AsyncThrowingStream<SPLKV2StreamItem, Error> {
        AsyncThrowingStream { continuation in
            let count = SPLKCounter()
            let finish: @Sendable () -> Void = {
                conversionQueue.async { continuation.finish() }
            }
            let progress: @Sendable (SPLKDisplayItemDetail) -> Void = { detail in
                let transfer = SPLKTransfer(value: detail)
                conversionQueue.async {
                    var item = SPLKV2StreamItem()
                    item.nodeDetail = SPLKBridge.detailMessage(transfer.value)
                    continuation.yield(item)
                }
                if let expected, count.increment() >= expected {
                    finish()
                }
            }
            if expected == 0 {
                finish()
            }
            let started = Task {
                await start(progress, finish)
            }
            continuation.onTermination = { termination in
                guard case .cancelled = termination else { return }
                Task {
                    let token = await started.value
                    await cancel(token)
                }
            }
        }
    }
}

final class SPLKCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    func increment() -> Int {
        lock.lock()
        defer { lock.unlock() }
        value += 1
        return value
    }
}

#endif
