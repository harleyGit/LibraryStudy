//
//  SchedulerType.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/8/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import enum Dispatch.DispatchTimeInterval
import struct Foundation.Date

// Type that represents time interval in the context of RxSwift.
public typealias RxTimeInterval = DispatchTimeInterval

/// Type that represents absolute time in the context of RxSwift.
public typealias RxTime = Date

/// Represents an object that schedules units of work.
///SchedulerType： 表示调度工作单元的对象，继承自ImmediateSchedulerType，内部包含立即执行的调度和周期调用的调度
public protocol SchedulerType: ImmediateSchedulerType {

    /// - returns: Current time.
    var now : RxTime {
        get
    }

    /**
    Schedules an action to be executed.
    
    - parameter state: State passed to the action to be executed.
    - parameter dueTime: Relative time after which to execute the action.
    - parameter action: Action to be executed.
    - returns: The disposable object used to cancel the scheduled action (best effort).
    */
    func scheduleRelative<StateType>(_ state: StateType, dueTime: RxTimeInterval, action: @escaping (StateType) -> Disposable) -> Disposable
 
    /**
    Schedules a periodic piece of work.
    
    - parameter state: State passed to the action to be executed.
    - parameter startAfter: Period after which initial work should be run.
    - parameter period: Period for running the work periodically.
    - parameter action: Action to be executed.
    - returns: The disposable object used to cancel the scheduled action (best effort).
    */
    func schedulePeriodic<StateType>(_ state: StateType, startAfter: RxTimeInterval, period: RxTimeInterval, action: @escaping (StateType) -> StateType) -> Disposable
}

extension SchedulerType {

    /**
    Periodic task will be emulated using recursive scheduling.

    - parameter state: Initial state passed to the action upon the first iteration.
    - parameter startAfter: Period after which initial work should be run.
    - parameter period: Period for running the work periodically.
    - returns: The disposable object used to cancel the scheduled recurring action (best effort).
    */
    ///使用递归调度模拟周期性任务
    public func schedulePeriodic<StateType>(_ state: StateType, startAfter: RxTimeInterval, period: RxTimeInterval, action: @escaping (StateType) -> StateType) -> Disposable {
        let schedule = SchedulePeriodicRecursive(scheduler: self, startAfter: startAfter, period: period, action: action, state: state)
            
        return schedule.start()
    }

    /// SchedulePeriodicRecursive内部会调用到如下方法
    func scheduleRecursive<State>(_ state: State, dueTime: RxTimeInterval, action: @escaping (State, AnyRecursiveScheduler<State>) -> Void) -> Disposable {
        let scheduler = AnyRecursiveScheduler(scheduler: self, action: action)
         
        scheduler.schedule(state, dueTime: dueTime)
            
        return Disposables.create(with: scheduler.dispose)
    }
}
