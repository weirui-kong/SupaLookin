//
//  LKKVOSubject.swift
//  SupaLookin
//
//  Created by Weirui Kong on 2026/10/25.
//

import Combine

/// Stands in for `RACObserve` on a property: `publisher` emits the current value on subscription, and again whenever the
/// owner calls `notify()`. Setters call it last, because KVO's didChange fired after the whole setter ran, including an
/// early return for an unchanged value.
final class LKKVOSubject<Value> {

    private let getter: () -> Value
    private let subject = PassthroughSubject<Void, Never>()

    init(_ getter: @escaping () -> Value) {
        self.getter = getter
    }

    func notify() {
        subject.send(())
    }

    var publisher: AnyPublisher<Value, Never> {
        let getter = self.getter
        return Just(())
            .append(subject)
            .map { getter() }
            .eraseToAnyPublisher()
    }
}
