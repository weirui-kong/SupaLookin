//
//  SPLKDeviceSession.swift
//  SupaLookin
//
//  Created by Weirui Kong on 2026/11/10.
//

import Foundation
import SPLKProtocol
import SPLKModelBridge
import SPLKServer

// One connected app. The network work runs in SPLKClientSession's actors; models are built here, on the main actor that uses them.
final class SPLKDeviceSession: SPLKControlChannel {

    let client: SPLKClientSession
    private(set) lazy var arbiter = SPLKControlArbiter(channel: self)

    init(client: SPLKClientSession) {
        self.client = client
    }

    static let capabilities: Set<String> = [
        SPLKCapability.app, SPLKCapability.hierarchy, SPLKCapability.details,
        SPLKCapability.attrModify, SPLKCapability.attrCustom, SPLKCapability.attrGroups,
        SPLKCapability.object, SPLKCapability.objectInvoke, SPLKCapability.objectSelectors,
        SPLKCapability.image, SPLKCapability.gestureToggle,
        SPLKCapability.controlLease, SPLKCapability.events,
        SPLKCapability.inputTouch, SPLKCapability.inputMotion, SPLKCapability.inputText,
        SPLKCapability.actionSemantic, SPLKCapability.waitIdle, SPLKCapability.eventsHierarchy,
    ]

    static var configuration: SPLKClientSession.Configuration {
        SPLKClientSession.Configuration(clientName: "Supa Lookin", clientVersion: SPLKHelper.splkReadableVersion, capabilities: capabilities, handshakeTimeout: 0.5)
    }

    var serverVersion: String {
        client.serverHello.serverVersion
    }

    func close() async {
        await client.close()
    }

    func waitUntilClosed() async {
        await client.waitUntilClosed()
    }

    // MARK: - Calls

    func appInfo(withImages needImages: Bool, cachedIdentifiers: [UInt]) async throws -> SPLKAppInfo? {
        var call = SPLKV2GetAppInfo()
        call.needImages = needImages
        call.cachedIdentifiers = cachedIdentifiers.map(UInt64.init)
        guard case .appInfo(let message) = try await unary(.getAppInfo(call)) else { return nil }
        let info = SPLKBridge.appInfo(message)
        info.serverReadableVersion = serverVersion as NSString
        info.swiftEnabledInSPLKServer = 1
        return info
    }

    func hierarchy() async throws -> SPLKHierarchyInfo? {
        guard case .hierarchy(let snapshot) = try await unary(.getHierarchy(SPLKV2GetHierarchy())) else { return nil }
        let info = SPLKBridge.hierarchyInfo(snapshot)
        info.serverVersion = SPLK_DOCUMENT_VERSION
        info.appInfo?.serverReadableVersion = serverVersion as NSString
        info.appInfo?.swiftEnabledInSPLKServer = 1
        return info
    }

    func details(_ packages: [SPLKStaticAsyncUpdateTasksPackage]) async throws -> AsyncThrowingStream<SPLKV2StreamItem, Error> {
        var call = SPLKV2FetchDetails()
        call.packages = packages.map(SPLKBridge.packageMessage)
        return try await stream(.fetchDetails(call))
    }

    func modificationPatch(_ tasks: [SPLKStaticAsyncUpdateTask]) async throws -> AsyncThrowingStream<SPLKV2StreamItem, Error> {
        var call = SPLKV2FetchModificationPatch()
        call.tasks = tasks.map(SPLKBridge.taskMessage)
        return try await stream(.fetchModificationPatch(call))
    }

    func modify(_ modification: SPLKAttributeModification, as actor: SPLKControlArbiter.Actor = .window) async throws -> SPLKDisplayItemDetail? {
        guard case .nodeDetail(let detail) = try await mutating(.modifyAttribute(SPLKBridge.modificationMessage(modification)), as: actor) else { return nil }
        return SPLKBridge.detail(detail)
    }

    func modifyCustom(_ modification: SPLKCustomAttrModification, as actor: SPLKControlArbiter.Actor = .window) async throws {
        _ = try await mutating(.modifyCustomAttribute(SPLKBridge.customModificationMessage(modification)), as: actor)
    }

    func object(oid: UInt) async throws -> SPLKObject? {
        var call = SPLKV2GetObject()
        call.oid = UInt64(oid)
        guard case .object(let object) = try await unary(.getObject(call)) else { return nil }
        return SPLKBridge.object(object)
    }

    func selectorNames(className: String, hasArg: Bool) async throws -> [String]? {
        var call = SPLKV2ListSelectors()
        call.className = className
        call.hasArg_p = hasArg
        guard case .selectors(let list) = try await unary(.listSelectors(call)) else { return nil }
        return list.values
    }

    // The dictionary v1's InvokeMethod answered with.
    func invoke(oid: UInt, text: String, as actor: SPLKControlArbiter.Actor = .window) async throws -> [String: Any]? {
        var call = SPLKV2InvokeMethod()
        call.oid = UInt64(oid)
        call.text = text
        guard case .invokeResult(let result) = try await mutating(.invokeMethod(call), as: actor) else { return nil }
        var value: [String: Any] = ["description": result.returnsVoid ? SPLKStringFlag_VoidReturn : result.description_p]
        if result.hasObject {
            value["object"] = SPLKBridge.object(result.object)
        }
        return value
    }

    func attributeGroups(layerOid: UInt) async throws -> [SPLKAttributesGroup]? {
        var call = SPLKV2GetAttributeGroups()
        call.oid = UInt64(layerOid)
        guard case .attributeGroups(let list) = try await unary(.getAttributeGroups(call)) else { return nil }
        return list.groups.map(SPLKBridge.group)
    }

    func imageData(imageViewOid: UInt) async throws -> Data? {
        var call = SPLKV2GetImageViewImage()
        call.oid = UInt64(imageViewOid)
        guard case .image(let image) = try await unary(.getImageViewImage(call)) else { return nil }
        return image.data
    }

    func setGestureRecognizer(oid: UInt, enabled: Bool, as actor: SPLKControlArbiter.Actor = .window) async throws -> Bool {
        var call = SPLKV2SetGestureRecognizerEnabled()
        call.oid = UInt64(oid)
        call.enabled = enabled
        guard case .gestureEnabled(let isEnabled) = try await mutating(.setGestureRecognizerEnabled(call), as: actor) else { return false }
        return isEnabled
    }

    func performAction(_ call: SPLKV2PerformAction, as actor: SPLKControlArbiter.Actor = .window) async throws -> SPLKV2ActionResult {
        guard case .actionResult(let result) = try await mutating(.performAction(call), as: actor) else {
            throw SPLKError.inner
        }
        return result
    }

    func waitForIdle(timeout: TimeInterval) async throws -> SPLKV2ActionResult {
        var call = SPLKV2WaitForIdle()
        call.timeoutMs = UInt32(max(timeout, 0) * 1000)
        guard case .actionResult(let result) = try await unary(.waitForIdle(call)) else {
            throw SPLKError.inner
        }
        return result
    }

    // One-way: a failure arrives on `client.onewayFailures`.
    func injectInput(_ events: [SPLKV2InputEvent], as actor: SPLKControlArbiter.Actor = .window) async throws {
        var call = SPLKV2InjectInput()
        call.events = events
        do {
            let leaseID = try arbiter.leaseID(for: actor, method: SPLKV2Request.OneOf_Call.injectInput(call).methodName)
            try await client.oneway(.injectInput(call), leaseID: leaseID)
        } catch {
            throw Self.translate(error)
        }
    }

    // MARK: - Control

    func acquireControl(kind: SPLKV2AcquireControl.Kind, holderLabel: String, preempt: Bool) async throws -> SPLKV2ControlLease {
        var call = SPLKV2AcquireControl()
        call.kind = kind
        call.holderLabel = holderLabel
        call.preempt = preempt
        guard case .lease(let lease) = try await client.unary(.acquireControl(call)).result else {
            throw SPLKStatusError(.internal, reason: SPLKBridge.Reason.inner)
        }
        return lease
    }

    func releaseControl(_ leaseID: Data) async throws {
        var call = SPLKV2ReleaseControl()
        call.leaseID = leaseID
        _ = try await client.unary(.releaseControl(call))
    }

    // Subscriptions live until either side ends them, so they carry the largest deadline.
    func events(topics: [String]) async throws -> AsyncThrowingStream<SPLKV2StreamItem, Error> {
        var call = SPLKV2Subscribe()
        call.topics = topics
        return try await client.stream(.subscribe(call), deadlineMs: .max)
    }

    // MARK: - Errors

    private func unary(_ call: SPLKV2Request.OneOf_Call, leaseID: Data = Data()) async throws -> SPLKV2Response.OneOf_Result? {
        do {
            return try await client.unary(call, leaseID: leaseID).result
        } catch {
            throw Self.translate(error)
        }
    }

    private func mutating(_ call: SPLKV2Request.OneOf_Call, as actor: SPLKControlArbiter.Actor) async throws -> SPLKV2Response.OneOf_Result? {
        let leaseID: Data
        do {
            leaseID = try arbiter.leaseID(for: actor, method: call.methodName)
        } catch {
            throw Self.translate(error)
        }
        return try await unary(call, leaseID: leaseID)
    }

    private func stream(_ call: SPLKV2Request.OneOf_Call) async throws -> AsyncThrowingStream<SPLKV2StreamItem, Error> {
        do {
            return try await client.stream(call)
        } catch {
            throw Self.translate(error)
        }
    }

    // The NSErrors v1 produced for the same failures, so the UI's messages stay the same.
    nonisolated static func translate(_ error: Error) -> Error {
        guard let status = error as? SPLKStatusError else {
            return error
        }
        switch (status.code, status.reason) {
        case (.notFound, SPLKBridge.Reason.objectDeallocated):
            return SPLKError.objNotFound
        case (.internal, SPLKBridge.Reason.inner):
            return SPLKError.inner
        case (.deadlineExceeded, _):
            return NSError(domain: SPLKErrorDomain, code: SPLKErrCode_Timeout, userInfo: [
                NSLocalizedDescriptionKey: NSLocalizedString("Request timeout", comment: ""),
                NSLocalizedRecoverySuggestionErrorKey: SPLKError.timeoutText,
            ])
        case (.failedPrecondition, SPLKBridge.Reason.appInBackground):
            return NSError(domain: SPLKErrorDomain, code: SPLKErrCode_PingFailForBackgroundState, userInfo: [
                NSLocalizedDescriptionKey: NSLocalizedString("The operation failed because target iOS app has entered to the background state.", comment: ""),
            ])
        case (.unavailable, _):
            return SPLKError.noConnect
        case (.cancelled, _):
            return CancellationError()
        default:
            return SPLKError.make(status.title, status.detail)
        }
    }
}
