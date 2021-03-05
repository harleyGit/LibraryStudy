//
//  ActivityIndicator.swift
//  RxExample
//
//  Created by Krunoslav Zaher on 10/18/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//
///RX_NO_MODULE这个宏的字面意思应该是没有rx的模块意思,但是没有找到具体实现在哪里,如果谁知道麻烦告知
#if !RX_NO_MODULE
import RxSwift
import RxCocoa
#endif

/// 活动令牌
///ActivityToken遵守Disposable、ObservableConvertibleType协议，也就是说ActivityToken既是Disposable也是Observable。实际上是用来存储一个Observable和Disposable清理资源的闭包。
private struct ActivityToken<E>: ObservableConvertibleType, Disposable {
    private let _source: Observable<E>
    private let _dispose: Cancelable

    init(source: Observable<E>, disposeAction: @escaping () -> Void) {
        _source = source
        //作为Disposable时本质上是初始化传入的闭包创建的Disposable
        _dispose = Disposables.create(with: disposeAction)
    }

    func dispose() {
        _dispose.dispose()
    }

    func asObservable() -> Observable<E> {
        return _source
    }
}

/**
 Enables monitoring of sequence computation.
 If there is at least one sequence computation in progress, `true` will be sent.
 When all activities complete `false` will be sent.
 */
/// 活动指示器
/**
 *ActivityIndicator的实现思想类似于内存管理中的引用计数，通过increment/decrement这两个函数来增/减计数的值，再使用BehaviorRelay把这些计数值作为元素发送出来，最后通过map操作符将元素转换为转化为BOOL类型的序列。
 */
public class ActivityIndicator: SharedSequenceConvertibleType {
    public typealias Element = Bool
    public typealias SharingStrategy = DriverSharingStrategy

    /// 锁
    private let _lock = NSRecursiveLock()
    /// 计数序列
    private let _relay = BehaviorRelay(value: 0)
    /// 加载序列
    private let _loading: SharedSequence<SharingStrategy, Bool>

    public init() {
        //使用distinctUntilChanged操作符保证序列值发生变化时发出元素
        _loading = _relay.asDriver()
            .map { $0 > 0 }
            .distinctUntilChanged()
    }

    /// 跟踪活动
    /// - Parameter source: 源序列
    fileprivate func trackActivityOfObservable<Source: ObservableConvertibleType>(_ source: Source) -> Observable<Source.Element> {
        //使用using操作符，把前面的ActivityToken作为resourceFactory（序列完成需要清理的资源）参数。保证参数序列完成时，清理资源的同时执行减量计数函数
        return Observable.using({ () -> ActivityToken<Source.Element> in
            // 增量计数
            self.increment()
            // 返回一个Disposable
            return ActivityToken(source: source.asObservable(), disposeAction: self.decrement)
        }, observableFactory: { value in
            // 返回一个序列
            return value.asObservable()
        })
    }

    private func increment() {
        _lock.lock()
        _relay.accept(_relay.value + 1)
        _lock.unlock()
    }

    private func decrement() {
        _lock.lock()
        _relay.accept(_relay.value - 1)
        _lock.unlock()
    }

    public func asSharedSequence() -> SharedSequence<SharingStrategy, Element> {
        return _loading
    }
}

extension ObservableConvertibleType {
    public func trackActivity(_ activityIndicator: ActivityIndicator) -> Observable<Element> {
        return activityIndicator.trackActivityOfObservable(self)
    }
}
