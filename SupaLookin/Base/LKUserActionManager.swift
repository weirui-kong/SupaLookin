//
//  LKUserActionManager.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/8/30.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Foundation

enum LKUserActionType {
    case none
    /// 在 preview 里执行了 click、double click、pan 之类的操作
    case previewOperation
    /// 点击了 dashboard
    case dashboardClick
    /// selectedItem 改变了
    case selectedItemChange
}

protocol LKUserActionManagerDelegate: AnyObject {
    /// 当 sendAction 被业务调用时，该 delegate 方法也会被调用
    func userActionManager(_ manager: LKUserActionManager, didAct type: LKUserActionType)
}

final class LKUserActionManager {

    static let sharedInstance = LKUserActionManager()

    private var delegators: [WeakReference] = []

    private init() {}

    /// delegate 不会被强引用，也无需在 delegate 对象被释放时设法 removeDelegate 之类的，相同的 delegate 被重复添加只会视为被添加一次
    func addDelegate(_ delegate: LKUserActionManagerDelegate) {
        delegators.removeAll { $0.object == nil }
        if delegators.contains(where: { $0.object === delegate }) {
            return
        }
        delegators.append(WeakReference(delegate))
    }

    /// 业务调用该方法
    func sendAction(_ type: LKUserActionType) {
        if type == .none {
            assertionFailure()
            return
        }
        for delegator in delegators {
            (delegator.object as? LKUserActionManagerDelegate)?.userActionManager(self, didAct: type)
        }
    }
}

private struct WeakReference {

    weak var object: AnyObject?

    init(_ object: AnyObject) {
        self.object = object
    }
}
