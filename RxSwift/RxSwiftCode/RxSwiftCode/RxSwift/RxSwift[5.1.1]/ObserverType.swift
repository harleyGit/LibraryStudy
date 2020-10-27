//
//  ObserverType.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/8/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/// Supports push-style iteration over an observable sequence.
///ObserverType 协议的作用是支持可观察序列上的推式迭代，我理解的意思是可以按顺序观察
public protocol ObserverType {
    /// The type of elements in sequence that observer can observe.
    /// 观察者可以观察到的按顺序排列的元素的类型
    associatedtype Element

    @available(*, deprecated, renamed: "Element")
    typealias E = Element

    /// Notify observer about sequence event.
    ///
    /// - parameter event: Event that occurred.
    // 将序列事件通知给观察者，Event是枚举类型
    //其中定义了观察元素以及观察方法，并且默认实现了三种事件方法：onNext，onCompleted，onError
    func on(_ event: Event<Element>)
}

/// Convenience API extensions to provide alternate next, error, completed events
extension ObserverType {
    
    /// Convenience method equivalent to `on(.next(element: Element))`
    ///
    /// - parameter element: Next element to send to observer(s)
    public func onNext(_ element: Element) {
        self.on(.next(element))
    }
    
    /// Convenience method equivalent to `on(.completed)`
    public func onCompleted() {
        self.on(.completed)
    }
    
    /// Convenience method equivalent to `on(.error(Swift.Error))`
    /// - parameter error: Swift.Error to send to observer(s)
    public func onError(_ error: Swift.Error) {
        self.on(.error(error))
    }
}
