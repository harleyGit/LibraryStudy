//
//  AtomicInt.swift
//  Platform
//
//  Created by Krunoslav Zaher on 10/28/18.
//  Copyright © 2018 Krunoslav Zaher. All rights reserved.
//

import class Foundation.NSLock

/// 继承自NSLock保证原子性
final class AtomicInt: NSLock {
    fileprivate var value: Int32
    public init(_ value: Int32 = 0) {
        self.value = value
    }
}

@discardableResult
@inline(__always)//总是被编译成inline的形式
/// @inline(__always)：函数内联是一种编译器优化技术，它通过使用方法的内容替换直接调用该方法，就相当于假装该方法并不存在一样，这种做法在很大程度上优化了性能

func add(_ this: AtomicInt, _ value: Int32) -> Int32 {
    this.lock()
    let oldValue = this.value
    this.value += value
    this.unlock()
    return oldValue
}

@discardableResult
@inline(__always)
func sub(_ this: AtomicInt, _ value: Int32) -> Int32 {
    this.lock()
    let oldValue = this.value
    this.value -= value
    this.unlock()
    return oldValue
}

@discardableResult
@inline(__always)
func fetchOr(_ this: AtomicInt, _ mask: Int32) -> Int32 {
    this.lock()
    let oldValue = this.value
    this.value |= mask
    this.unlock()
    return oldValue
}

@inline(__always)
func load(_ this: AtomicInt) -> Int32 {
    this.lock()
    let oldValue = this.value
    this.unlock()
    return oldValue
}

@discardableResult
@inline(__always)
func increment(_ this: AtomicInt) -> Int32 {
    return add(this, 1)
}

@discardableResult
@inline(__always)
func decrement(_ this: AtomicInt) -> Int32 {
    return sub(this, 1)
}

@inline(__always)
func isFlagSet(_ this: AtomicInt, _ mask: Int32) -> Bool {
    return (load(this) & mask) != 0
}
