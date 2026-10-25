//
//  LookinMsgAttribute.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/8/19.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Foundation

final class LookinMsgActionParams {

    var value: Any?
    weak var relatedObject: AnyObject?
    var userInfo: Any?

    var doubleValue: Double {
        guard let number = value as? NSNumber else {
            assertionFailure()
            return 0
        }
        return number.doubleValue
    }

    var integerValue: Int {
        guard let number = value as? NSNumber else {
            assertionFailure()
            return 0
        }
        return number.intValue
    }

    var boolValue: Bool {
        guard let number = value as? NSNumber else {
            assertionFailure()
            return false
        }
        return number.boolValue
    }
}

class LookinMsgAttribute {

    /// 当前的值
    private(set) var currentValue: Any?

    private var subscribers: [LookinMsgTargetAction] = []

    /// 创建一个示例并给予一个初始值
    init(value: Any?) {
        currentValue = value
    }

    /**
     使用 value 作为 currentValue 属性的值
     调用该方法后，所有此前通过 subscribe 注册的 subscriber 的 action 都会被调用，参数是一个 LookinMsgActionParams 对象
     如果传入了 ignoreSubscriber，则 ignoreSubscriber 这个对象不会收到这次通知
     如果传入的 value 和之前已有的 value 是 equal 的，则该方法不会产生任何效果
     传入的 userInfo 对象可在 LookinMsgActionParams 中被读取
     */
    func setValue(_ value: Any?, ignoreSubscriber: AnyObject?, userInfo: Any?) {
        if let current = currentValue as? NSObject, current.isEqual(value) {
            // value 相等的话直接拒绝
            return
        }
        currentValue = value

        // target 已被释放的 target-action 直接删掉
        subscribers.removeAll { $0.target == nil }
        for subscriber in subscribers {
            guard let target = subscriber.target else {
                continue
            }
            if target === ignoreSubscriber {
                // 不要通知 ignoreSubscriber
                continue
            }
            let params = LookinMsgActionParams()
            params.userInfo = userInfo
            params.value = value
            params.relatedObject = subscriber.relatedObject
            subscriber.action(target, params)
        }
    }

    /// target, relatedObject 均不会被强引用。同一个 target 在同一处多次订阅（且 relatedObject 相同）时只会收到一次通知
    /// 如果 sendAtOnce 为 true，则在该方法调用后，会立即收到一条消息
    func subscribe<Target: AnyObject>(_ target: Target, relatedObject: AnyObject? = nil, sendAtOnce: Bool = false, file: String = #fileID, line: Int = #line, action: @escaping (Target, LookinMsgActionParams) -> Void) {
        let newOne = LookinMsgTargetAction(target: target, actionID: "\(file):\(line)", relatedObject: relatedObject) { target, params in
            if let target = target as? Target {
                action(target, params)
            }
        }
        if subscribers.contains(newOne) {
            return
        }
        subscribers.append(newOne)

        if sendAtOnce {
            let params = LookinMsgActionParams()
            params.value = currentValue
            params.relatedObject = relatedObject
            action(target, params)
        }
    }
}

final class LookinDoubleMsgAttribute: LookinMsgAttribute {

    init(double value: Double) {
        super.init(value: value as NSNumber)
    }

    var currentDoubleValue: Double {
        (currentValue as? NSNumber)?.doubleValue ?? 0
    }

    func setDoubleValue(_ value: Double, ignoreSubscriber: AnyObject?) {
        setValue(value as NSNumber, ignoreSubscriber: ignoreSubscriber, userInfo: nil)
    }
}

final class LookinIntegerMsgAttribute: LookinMsgAttribute {

    init(integer value: Int) {
        super.init(value: value as NSNumber)
    }

    var currentIntegerValue: Int {
        (currentValue as? NSNumber)?.intValue ?? 0
    }

    func setIntegerValue(_ value: Int, ignoreSubscriber: AnyObject?) {
        setValue(value as NSNumber, ignoreSubscriber: ignoreSubscriber, userInfo: nil)
    }
}

final class LookinBOOLMsgAttribute: LookinMsgAttribute {

    init(bool value: Bool) {
        super.init(value: value as NSNumber)
    }

    var currentBOOLValue: Bool {
        (currentValue as? NSNumber)?.boolValue ?? false
    }

    func setBOOLValue(_ value: Bool, ignoreSubscriber: AnyObject?) {
        setValue(value as NSNumber, ignoreSubscriber: ignoreSubscriber, userInfo: nil)
    }
}
