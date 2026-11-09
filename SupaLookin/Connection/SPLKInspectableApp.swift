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
import SPLKServer

final class SPLKInspectableApp {

    var serverVersionError: NSError?
    var appInfo: SPLKAppInfo?
    weak var channel: SPLK_PTChannel?

    func fetchHierarchyData() async throws -> SPLKHierarchyInfo? {
        // Lookin 1.0.4 开始加入这个参数
        let param: NSDictionary = ["clientVersion": SPLKHelper.splkReadableVersion]
        return try await requestSingle(type: SPLKRequestTypeHierarchy, data: param) as? SPLKHierarchyInfo
    }

    func submitInbuiltModification(_ modification: SPLKAttributeModification) async throws -> Any? {
        try await requestSingle(type: SPLKRequestTypeInbuiltAttrModification, data: modification)
    }

    func submitCustomModification(_ modification: SPLKCustomAttrModification) async throws -> Any? {
        try await requestSingle(type: SPLKRequestTypeCustomAttrModification, data: modification)
    }

    /// 每收到一批 detail 就调用一次 next
    /// The callbacks run synchronously inside Peertalk's callback, as the RAC subscriber's did. SPLKStaticAsyncUpdateManager relies on
    /// that: cancelling a fetch must run its completion before the next fetch is set up.
    func fetchHierarchyDetail(withTaskPackages packages: [SPLKStaticAsyncUpdateTasksPackage], next: @escaping (Any?) -> Void, failure: @escaping (Error) -> Void, completion: @escaping () -> Void) {
        request(type: SPLKRequestTypeHierarchyDetails, data: packages as NSArray, next: next, failure: failure, completion: completion)
    }

    func cancelHierarchyDetailFetching() {
        cancelRequest(type: SPLKRequestTypeHierarchyDetails)
        push(type: SPLKPush_CanceHierarchyDetails, data: nil)
    }

    /// Callbacks run synchronously, like fetchHierarchyDetail's.
    func fetchModificationPatch(withTasks tasks: [SPLKStaticAsyncUpdateTask], next: @escaping (Any?) -> Void, failure: @escaping (Error) -> Void, completion: @escaping () -> Void) {
        request(type: SPLKRequestTypeAttrModificationPatch, data: tasks as NSArray, next: next, failure: failure, completion: completion)
    }

    func fetchObject(withOid oid: UInt) async throws -> SPLKObject? {
        if oid == 0 {
            throw SPLKError.inner
        }
        return try await requestSingle(type: SPLKRequestTypeFetchObject, data: NSNumber(value: oid)) as? SPLKObject
    }

    func fetchSelectorNames(withClass className: String, hasArg: Bool) async throws -> [String]? {
        let param: NSDictionary = ["className": className, "hasArg": NSNumber(value: hasArg)]
        return try await requestSingle(type: SPLKRequestTypeAllSelectorNames, data: param) as? [String]
    }

    func invokeMethod(withOid oid: UInt, text: String) async throws -> [String: Any]? {
        if oid == 0 || text.isEmpty {
            throw SPLKError.inner
        }
        let param: NSDictionary = ["oid": NSNumber(value: oid), "text": text]
        guard var value = try await requestSingle(type: SPLKRequestTypeInvokeMethod, data: param) as? [String: Any] else {
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
        return try await requestSingle(type: SPLKRequestTypeAllAttrGroups, data: NSNumber(value: oid)) as? [SPLKAttributesGroup]
    }

    /// 获取某个 imageView 的 image 对象，oid 是 imageView 的 oid
    func fetchImage(withImageViewOid oid: UInt) async throws -> Any? {
        if oid == 0 {
            throw SPLKError.inner
        }
        return try await requestSingle(type: SPLKRequestTypeFetchImageViewImage, data: NSNumber(value: oid))
    }

    /// 修改一个 gestureRecognizer 的 enable 属性。如果 shouldBeEnabled 为 true 则表示想要把它的 enable 属性修改为 true
    func modifyGestureRecognizer(_ oid: UInt, toBeEnabled shouldBeEnabled: Bool) async throws -> Any? {
        if oid == 0 {
            throw SPLKError.inner
        }
        let param: NSDictionary = ["oid": NSNumber(value: oid), "enable": NSNumber(value: shouldBeEnabled)]
        return try await requestSingle(type: SPLKRequestTypeModifyRecognizerEnable, data: param)
    }

    // MARK: - Private

    private func push(type pushType: Int, data: Any?) {
        guard let channel else {
            return
        }
        SPLKConnectionManager.sharedInstance.push(type: UInt32(pushType), data: data, channel: channel)
    }

    private func request(type requestType: Int, data: Any?, next: @escaping (Any?) -> Void, failure: @escaping (Error) -> Void, completion: @escaping () -> Void) {
        guard let channel else {
            failure(SPLKError.noConnect)
            return
        }
        // Like RAC's flattenMap into an error, a translated error ends delivery: later responses and the completion are dropped.
        var hasEnded = false
        SPLKConnectionManager.sharedInstance.sendRequest(type: UInt32(requestType), data: data, channel: channel, next: { attachment in
            guard !hasEnded else { return }
            if let error = attachment?.error as NSError? {
                hasEnded = true
                // 翻译成本地文字
                if error.code == SPLKErrCode_ObjectNotFound {
                    failure(SPLKError.objNotFound)
                } else if error.code == SPLKErrCode_Inner {
                    failure(SPLKError.inner)
                } else {
                    failure(error)
                }
            } else {
                next(attachment?.data)
            }
        }, fail: { error in
            guard !hasEnded else { return }
            hasEnded = true
            failure(error)
        }, completion: {
            guard !hasEnded else { return }
            hasEnded = true
            completion()
        })
    }

    private func request(type requestType: Int, data: Any?) -> AsyncThrowingStream<ResponseBox, Error> {
        AsyncThrowingStream { continuation in
            request(type: requestType, data: data, next: { value in
                continuation.yield(ResponseBox(value: value))
            }, failure: { error in
                continuation.finish(throwing: error)
            }, completion: {
                continuation.finish()
            })
        }
    }

    /// For requests answered by a single response. A request that completes without one, e.g. after a cancel, throws `CancellationError`.
    private func requestSingle(type requestType: Int, data: Any?) async throws -> Any? {
        for try await box in request(type: requestType, data: data) {
            return box.value
        }
        throw CancellationError()
    }

    private func cancelRequest(type requestType: Int) {
        guard let channel else {
            return
        }
        SPLKConnectionManager.sharedInstance.cancelRequest(type: UInt32(requestType), channel: channel)
    }
}

// Peertalk calls back on the main queue and the stream is read on the main actor, so the value never crosses threads.
private struct ResponseBox: @unchecked Sendable {
    let value: Any?
}
