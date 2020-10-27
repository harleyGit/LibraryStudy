//
//  ObservableConvertibleType.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 9/17/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/// Type that can be converted to observable sequence (`Observable<Element>`).
///这个协议表示可以转换为可观察序列类型。其中Element表示序列元素的别名，asObservable方法是将self转换为Observable 序列
public protocol ObservableConvertibleType {
    /// Type of elements in sequence.
    //声明关联类型
    associatedtype Element

    @available(*, deprecated, renamed: "Element")
    typealias E = Element

    /// Converts `self` to `Observable` sequence.
    ///
    /// - returns: Observable sequence that represents `self`.
    func asObservable() -> Observable<Element>
}
