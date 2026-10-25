//
//  NSArray+LookinClient.swift
//  SupaLookin
//
//  Created by Li Kai on 2019/8/14.
//  https://lookin.work
//
//  Ported to Swift by Weirui Kong on 2026/10/25.
//

import Cocoa

extension Array where Element: NSView {

    var visibleViews: [Element] {
        filter { !$0.isHidden }
    }
}

extension Array {

    /// Swift counterpart of LookinShared's `lookin_dequeueWithCount:add:notDequeued:doNext:`
    mutating func dequeue(count: Int, add: (Int) -> Element, notDequeued: (Int, Element) -> Void, doNext: (Int, Element) -> Void) {
        for idx in 0..<count {
            if idx < self.count {
                doNext(idx, self[idx])
            } else {
                let newElement = add(idx)
                append(newElement)
                doNext(idx, newElement)
            }
        }
        if self.count > count {
            for idx in count..<self.count {
                notDequeued(idx, self[idx])
            }
        }
    }

    func element(at index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

extension Array {

    /// Swift counterpart of LookinShared's `lookin_resizeWithCount:add:remove:doNext:`
    func resized(count: Int, add: (Int) -> Element, remove: (Int, Element) -> Void, doNext: (Int, Element) -> Void) -> [Element] {
        var result: [Element] = []
        result.reserveCapacity(count)
        for idx in 0..<count {
            if idx < self.count {
                result.append(self[idx])
                doNext(idx, self[idx])
            } else {
                let newElement = add(idx)
                result.append(newElement)
                doNext(idx, newElement)
            }
        }
        if self.count > count {
            for idx in count..<self.count {
                remove(idx, self[idx])
            }
        }
        return result
    }
}
