//
//  AnyObserver.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/28/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/// A type-erased `ObserverType`.
///
/// Forwards operations to an arbitrary underlying observer with the same `Element` type, hiding the specifics of the underlying observer type.
public struct AnyObserver<Element> : ObserverType {
    /// Anonymous event handler type.
    public typealias EventHandler = (Event<Element>) -> Void //定义了 EventHandler，它是一个 闭包类型，参数是 Event<Element>，返回值是 Void（即没有返回值）

    private let observer: EventHandler

    /// Construct an instance whose `on(event)` calls `eventHandler(event)`
    ///
    /// - parameter eventHandler: Event handler that observes sequences events.
    public init(eventHandler: @escaping EventHandler) {
        self.observer = eventHandler
    }
    
    /// Construct an instance whose `on(event)` calls `observer.on(event)`
    ///
    /// - parameter observer: Observer that receives sequence events.
    public init<Observer: ObserverType>(_ observer: Observer) where Observer.Element == Element {
        // self.observer = observer.on，AnonymousObservableSink类的on函数赋值给AnyObserver类的observer变量
        // 从这里就可以明白为什么这行代码observer.onNext("发送信号") 最终会触发AnonymousObservableSink.on事件
        self.observer = observer.on
    }
    
    /// Send `event` to this observer.
    ///
    /// - parameter event: Event instance.
    public func on(_ event: Event<Element>) {
        self.observer(event)    // 这个self.observer是 self.observer = observer.on，但是observer.on(注意：这个on是一个方法，不是一个属性，)中的observer是Create.swift文件中的AnonymousObservableSink类实例对象
    }

    /// Erases type of observer and returns canonical observer.
    ///
    /// - returns: type erased observer.
    public func asObserver() -> AnyObserver<Element> {
        self
    }
}

extension AnyObserver {
    /// Collection of `AnyObserver`s
    typealias s = Bag<(Event<Element>) -> Void>
}

extension ObserverType {
    /// Erases type of observer and returns canonical observer.
    ///
    /// - returns: type erased observer.
    public func asObserver() -> AnyObserver<Element> {
        AnyObserver(self)
    }

    /// Transforms observer of type R to type E using custom transform method.
    /// Each event sent to result observer is transformed and sent to `self`.
    ///
    /// - returns: observer that transforms events.
    public func mapObserver<Result>(_ transform: @escaping (Result) throws -> Element) -> AnyObserver<Result> {
        AnyObserver { e in
            self.on(e.map(transform))
        }
    }
}
