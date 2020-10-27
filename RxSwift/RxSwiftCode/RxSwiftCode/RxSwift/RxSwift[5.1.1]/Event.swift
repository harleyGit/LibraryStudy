//
//  Event.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/8/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/// Represents a sequence event.
///
/// Sequence grammar: 
/// **next\* (error | completed)**
/// Event表示序列事件，是一个泛型枚举
public enum Event<Element> {
    /// Next element is produced.
    case next(Element)

    /// Sequence terminated with an error.
    case error(Swift.Error)

    /// Sequence completed successfully.
    case completed
}

///遵从了系统的CustomDebugStringConvertible协议，重写了debugDescription属性让其可以在debug模式下打印
///CustomStringConvertible 和CustomDebugStringConvertible这两个协议类似于Objective-C中的重写description方法
///继承协议 实现description 和 debugDescription 属性 即可打印出想要的数据内容
extension Event: CustomDebugStringConvertible {
    /// Description of event.
    /// 重写了打印Debug下的打印方法
    public var debugDescription: String {
        switch self {
        case .next(let value):
            return "next(\(value))"
        case .error(let error):
            return "error(\(error))"
        case .completed:
            return "completed"
        }
    }
}

extension Event {
    /// Is `completed` or `error` event.
    /// 是否是`completed` 或 `error`事件
    public var isStopEvent: Bool {
        switch self {
        case .next: return false
        case .error, .completed: return true
        }
    }

    /// If `next` event, returns element value.
    /// 返回`next`事件的元素
    public var element: Element? {
        if case .next(let value) = self {
            return value
        }
        return nil
    }

    /// If `error` event, returns error.
    public var error: Swift.Error? {
        if case .error(let error) = self {
            return error
        }
        return nil
    }

    /// If `completed` event, returns `true`.
    public var isCompleted: Bool {
        if case .completed = self {
            return true
        }
        return false
    }
}

extension Event {
    /// Maps sequence elements using transform. If error happens during the transform, `.error`
    /// will be returned as value.
    public func map<Result>(_ transform: (Element) throws -> Result) -> Event<Result> {
        do {
            switch self {
            case let .next(element):
                return .next(try transform(element))
            case let .error(error):
                return .error(error)
            case .completed:
                return .completed
            }
        }
        catch let e {
            return .error(e)
        }
    }
}

/// A type that can be converted to `Event<Element>`.
public protocol EventConvertible {
    /// Type of element in event
    associatedtype Element

    @available(*, deprecated, renamed: "Element")
    typealias ElementType = Element

    /// Event representation of this instance
    var event: Event<Element> { get }
}

extension Event: EventConvertible {
    /// Event representation of this instance
    public var event: Event<Element> {
        return self
    }
}
