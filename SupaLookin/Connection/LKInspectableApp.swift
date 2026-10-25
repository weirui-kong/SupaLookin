//
//  LKInspectableApp.swift
//  SupaLookin
//
//  Created by Li Kai on 2018/11/3.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Foundation
import LookinShared

final class LKInspectableApp {

    var serverVersionError: NSError?
    var appInfo: LookinAppInfo?
    weak var channel: Lookin_PTChannel?

    func fetchHierarchyData() async throws -> LookinHierarchyInfo? {
        // Lookin 1.0.4 开始加入这个参数
        let param: NSDictionary = ["clientVersion": LKHelper.lookinReadableVersion]
        return try await requestSingle(type: LookinRequestTypeHierarchy, data: param) as? LookinHierarchyInfo
    }

    func submitInbuiltModification(_ modification: LookinAttributeModification) async throws -> Any? {
        try await requestSingle(type: LookinRequestTypeInbuiltAttrModification, data: modification)
    }

    func submitCustomModification(_ modification: LookinCustomAttrModification) async throws -> Any? {
        try await requestSingle(type: LookinRequestTypeCustomAttrModification, data: modification)
    }

    /// 每收到一批 detail 就调用一次 next
    /// The callbacks run synchronously inside Peertalk's callback, as the RAC subscriber's did. LKStaticAsyncUpdateManager relies on
    /// that: cancelling a fetch must run its completion before the next fetch is set up.
    func fetchHierarchyDetail(withTaskPackages packages: [LookinStaticAsyncUpdateTasksPackage], next: @escaping (Any?) -> Void, failure: @escaping (Error) -> Void, completion: @escaping () -> Void) {
        request(type: LookinRequestTypeHierarchyDetails, data: packages as NSArray, next: next, failure: failure, completion: completion)
    }

    func cancelHierarchyDetailFetching() {
        cancelRequest(type: LookinRequestTypeHierarchyDetails)
        push(type: LookinPush_CanceHierarchyDetails, data: nil)
    }

    /// Callbacks run synchronously, like fetchHierarchyDetail's.
    func fetchModificationPatch(withTasks tasks: [LookinStaticAsyncUpdateTask], next: @escaping (Any?) -> Void, failure: @escaping (Error) -> Void, completion: @escaping () -> Void) {
        request(type: LookinRequestTypeAttrModificationPatch, data: tasks as NSArray, next: next, failure: failure, completion: completion)
    }

    func fetchObject(withOid oid: UInt) async throws -> LookinObject? {
        if oid == 0 {
            throw LookinError.inner
        }
        return try await requestSingle(type: LookinRequestTypeFetchObject, data: NSNumber(value: oid)) as? LookinObject
    }

    func fetchSelectorNames(withClass className: String, hasArg: Bool) async throws -> [String]? {
        let param: NSDictionary = ["className": className, "hasArg": NSNumber(value: hasArg)]
        return try await requestSingle(type: LookinRequestTypeAllSelectorNames, data: param) as? [String]
    }

    func invokeMethod(withOid oid: UInt, text: String) async throws -> [String: Any]? {
        if oid == 0 || text.isEmpty {
            throw LookinError.inner
        }
        let param: NSDictionary = ["oid": NSNumber(value: oid), "text": text]
        guard var value = try await requestSingle(type: LookinRequestTypeInvokeMethod, data: param) as? [String: Any] else {
            return nil
        }
        if value["description"] as? String == LookinStringFlag_VoidReturn {
            // 方法没有返回值时，替换成本地说明
            value["description"] = NSLocalizedString("The method was invoked successfully and no value was returned.", comment: "")
        }
        return value
    }

    func fetchAttrGroupList(withOid oid: UInt) async throws -> [LookinAttributesGroup]? {
        if oid == 0 {
            throw LookinError.inner
        }
        return try await requestSingle(type: LookinRequestTypeAllAttrGroups, data: NSNumber(value: oid)) as? [LookinAttributesGroup]
    }

    /// 获取某个 imageView 的 image 对象，oid 是 imageView 的 oid
    func fetchImage(withImageViewOid oid: UInt) async throws -> Any? {
        if oid == 0 {
            throw LookinError.inner
        }
        return try await requestSingle(type: LookinRequestTypeFetchImageViewImage, data: NSNumber(value: oid))
    }

    /// 修改一个 gestureRecognizer 的 enable 属性。如果 shouldBeEnabled 为 true 则表示想要把它的 enable 属性修改为 true
    func modifyGestureRecognizer(_ oid: UInt, toBeEnabled shouldBeEnabled: Bool) async throws -> Any? {
        if oid == 0 {
            throw LookinError.inner
        }
        let param: NSDictionary = ["oid": NSNumber(value: oid), "enable": NSNumber(value: shouldBeEnabled)]
        return try await requestSingle(type: LookinRequestTypeModifyRecognizerEnable, data: param)
    }

    // MARK: - Private

    private func push(type pushType: Int, data: Any?) {
        guard let channel else {
            return
        }
        LKConnectionManager.sharedInstance.push(type: UInt32(pushType), data: data, channel: channel)
    }

    private func request(type requestType: Int, data: Any?, next: @escaping (Any?) -> Void, failure: @escaping (Error) -> Void, completion: @escaping () -> Void) {
        guard let channel else {
            failure(LookinError.noConnect)
            return
        }
        // Like RAC's flattenMap into an error, a translated error ends delivery: later responses and the completion are dropped.
        var hasEnded = false
        LKConnectionManager.sharedInstance.sendRequest(type: UInt32(requestType), data: data, channel: channel, next: { attachment in
            guard !hasEnded else { return }
            if let error = attachment?.error as NSError? {
                hasEnded = true
                // 翻译成本地文字
                if error.code == LookinErrCode_ObjectNotFound {
                    failure(LookinError.objNotFound)
                } else if error.code == LookinErrCode_Inner {
                    failure(LookinError.inner)
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
        LKConnectionManager.sharedInstance.cancelRequest(type: UInt32(requestType), channel: channel)
    }
}

// Peertalk calls back on the main queue and the stream is read on the main actor, so the value never crosses threads.
private struct ResponseBox: @unchecked Sendable {
    let value: Any?
}
