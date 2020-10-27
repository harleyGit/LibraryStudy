//
//  Reactive.swift
//  RxSwift
//
//  Created by Yury Korolev on 5/2/16.
//  Copyright © 2016 Krunoslav Zaher. All rights reserved.
//

/**
 Use `Reactive` proxy as customization point for constrained protocol extensions.

 General pattern would be:

 // 1. Extend Reactive protocol with constrain on Base
 // Read as: Reactive Extension where Base is a SomeType
 extension Reactive where Base: SomeType {
 // 2. Put any specific reactive extension for SomeType here
 }

 With this approach we can have more specialized methods and properties using
 `Base` and not just specialized on common base type.

 */

///label.rx
///label会传入这个base
public struct Reactive<Base> {
    /// Base object to extend.
    public let base: Base

    /// Creates extensions with base object.
    ///
    /// - parameter base: Base object.
    public init(_ base: Base) {
        self.base = base
    }
}

/// A type that has reactive extensions.
public protocol ReactiveCompatible {
    /// Extended type
    /// associatedtype： 协议关联类型
    associatedtype ReactiveBase

    @available(*, deprecated, renamed: "ReactiveBase")
    typealias CompatibleType = ReactiveBase

    /// Reactive extensions.
    /// 元类型，此处为Reactive泛型并且用关联类型进行约束
    ///{ get set } 表示该属性是可读与可写的属性
    ///Class.Type : 获取这个类的元类型
    static var rx: Reactive<ReactiveBase>.Type { get set }

    /// Reactive extensions.
    var rx: Reactive<ReactiveBase> { get set }
}

extension ReactiveCompatible {
    /// Reactive extensions.
    //接口中使用的类型就是实现这个接口本身的类型的话，需要使用 Self 进行指代
    public static var rx: Reactive<Self>.Type {
        get {
            return Reactive<Self>.self
        }
        // swiftlint:disable:next unused_setter_value
        set {
            // this enables using Reactive to "mutate" base type
        }
    }

    /// Reactive extensions.
    public var rx: Reactive<Self> {
        get {
            return Reactive(self)
        }
        // swiftlint:disable:next unused_setter_value
        set {
            // this enables using Reactive to "mutate" base object
        }
    }
}

import class Foundation.NSObject

/// Extend NSObject with `rx` proxy.
///当我们输入label.rx时，实际上是因为NSObject遵从了ReactiveCompatible协议添加了命名空间
extension NSObject: ReactiveCompatible { }





