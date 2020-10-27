//
//  Observable.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/8/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/// A type-erased `ObservableType`. 
///
/// It represents a push style sequence.
///Observable为遵从ObservableType协议的类，它表示一个push样式序列，可以让订阅“观察者”接收此序列的事件。
///而在ObservableType协议中，默认实现了asObservable()方法，以及定义了subscribe方法，该方法中参数需要是遵从ObserverType协议类型
public class Observable<Element> : ObservableType {
    init() {
#if TRACE_RESOURCES
        _ = Resources.incrementTotal()
#endif
    }
    // MARK: 该subscribe方法的形参observer必须遵从ObserverType协议，返回类型是满足Disposable协议类型，并且需要满足参数.Element 类型和当前Observable类中的Element泛型为同一类型

    public func subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element {
        rxAbstractMethod()
    }
    
    public func asObservable() -> Observable<Element> {
        return self
    }
    
    deinit {
#if TRACE_RESOURCES
        _ = Resources.decrementTotal()
#endif
    }
}

