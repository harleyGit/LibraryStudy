//
//  RecursiveLock.swift
//  Platform
//
//  Created by Krunoslav Zaher on 12/18/16.
//  Copyright © 2016 Krunoslav Zaher. All rights reserved.
//

import class Foundation.NSRecursiveLock

#if TRACE_RESOURCES
    class RecursiveLock: NSRecursiveLock {
        override init() {
            _ = Resources.incrementTotal()
            super.init()
        }

        override func lock() {
            super.lock()
            _ = Resources.incrementTotal()
        }

        override func unlock() {
            super.unlock()
            _ = Resources.decrementTotal()
        }

        deinit {
            _ = Resources.decrementTotal()
        }
    }
#else
    ///NSRecursiveLock：是一个递归锁，这个锁可以被同一线程多次请求，而不会引起死锁。它主要是用在循环或递归操作中
    ///NSRecursiveLock：https://www.dazhuanlan.com/2019/11/08/5dc5838a41a22/
    typealias RecursiveLock = NSRecursiveLock
#endif
