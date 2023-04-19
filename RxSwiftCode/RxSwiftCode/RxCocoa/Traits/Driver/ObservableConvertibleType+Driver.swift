//
//  ObservableConvertibleType+Driver.swift
//  RxCocoa
//
//  Created by Krunoslav Zaher on 9/19/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import RxSwift

extension ObservableConvertibleType {
    /**
    Converts observable sequence to `Driver` trait.
    
    - parameter onErrorJustReturn: Element to return in case of error and after that complete the sequence.
    - returns: Driver trait.
    */
    public func asDriver(onErrorJustReturn: Element) -> Driver<Element> {
        let source = self
            .asObservable()
            .observe(on:DriverSharingStrategy.scheduler)
            .catchAndReturn(onErrorJustReturn)
        return Driver(source)
    }
    
    /**
    Converts observable sequence to `Driver` trait.
    
    - parameter onErrorDriveWith: Driver that continues to drive the sequence in case of error.
    - returns: Driver trait.
    */
    public func asDriver(onErrorDriveWith: Driver<Element>) -> Driver<Element> {
        let source = self
            .asObservable()
            .observe(on:DriverSharingStrategy.scheduler)
            .catch { _ in
                onErrorDriveWith.asObservable()
            }
        return Driver(source)
    }

    /**
    Converts observable sequence to `Driver` trait.
    
    - parameter onErrorRecover: Calculates driver that continues to drive the sequence in case of error.
    - returns: Driver trait.
    */
    public func asDriver(onErrorRecover: @escaping (_ error: Swift.Error) -> Driver<Element>) -> Driver<Element> {
        //observerOn方法是用来指定线程的，这里指定了DriverSharingStrategy.scheduler内部指定的就是主线程，这里就解决了Driver的执行是在主线程的，我们可以为所欲为的刷新UI，不用担心线程问题
        //catchError方法是用来处理错误信号的，当接收到错误信号后，可以把错误信号处理成一个onNext信号发送出去
        //
        let source = self
            .asObservable()
            .observe(on:DriverSharingStrategy.scheduler)
            .catch { error in
                onErrorRecover(error).asObservable()
            }
        return Driver(source)
    }
}
