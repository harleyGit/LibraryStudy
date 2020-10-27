//
//  Disposable.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/8/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/// Represents a disposable resource.
//Disposable也是声明的一个协议，用来表示资源释放
public protocol Disposable {
    /// Dispose resource.
    func dispose()
}
