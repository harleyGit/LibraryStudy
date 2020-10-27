//
//  Buffer.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 9/13/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

extension ObservableType {

    /**
     Projects each element of an observable sequence into a buffer that's sent out when either it's full or a given amount of time has elapsed, using the specified scheduler to run timers.

     A useful real-world analogy of this overload is the behavior of a ferry leaving the dock when all seats are taken, or at the scheduled time of departure, whichever event occurs first.

     - seealso: [buffer operator on reactivex.io](http://reactivex.io/documentation/operators/buffer.html)

     - parameter timeSpan: Maximum time length of a buffer.
     - parameter count: Maximum element count of a buffer.
     - parameter scheduler: Scheduler to run buffering timers on.
     - returns: An observable sequence of buffers.
     */
    public func buffer(timeSpan: RxTimeInterval, count: Int, scheduler: SchedulerType)
        -> Observable<[Element]> {
        return BufferTimeCount(source: self.asObservable(), timeSpan: timeSpan, count: count, scheduler: scheduler)
    }
}

//调用buffer方法会生成一个BufferTimeCount对象，把对应的缓存时间，缓存个数，调度以及当前Observable保存；当subscribe时，调用run方法生成BufferTimeCountSink
final private class BufferTimeCount<Element>: Producer<[Element]> {
    
    fileprivate let _timeSpan: RxTimeInterval
    fileprivate let _count: Int
    fileprivate let _scheduler: SchedulerType
    fileprivate let _source: Observable<Element>
    
    init(source: Observable<Element>, timeSpan: RxTimeInterval, count: Int, scheduler: SchedulerType) {
        self._source = source
        self._timeSpan = timeSpan
        self._count = count
        self._scheduler = scheduler
    }
    
    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == [Element] {
        let sink = BufferTimeCountSink(parent: self, observer: observer, cancel: cancel)
        let subscription = sink.run()
        return (sink: sink, subscription: subscription)
    }
}

final private class BufferTimeCountSink<Element, Observer: ObserverType>
    : Sink<Observer>
    , LockOwnerType
    , ObserverType
    , SynchronizedOnType where Observer.Element == [Element] {
    typealias Parent = BufferTimeCount<Element>
    
    private let _parent: Parent
    
    let _lock = RecursiveLock()
    
    // state
    private let _timerD = SerialDisposable()
    private var _buffer = [Element]()
    private var _windowID = 0
    
    init(parent: Parent, observer: Observer, cancel: Cancelable) {
        self._parent = parent
        super.init(observer: observer, cancel: cancel)
    }
 
    func run() -> Disposable {
        self.createTimer(self._windowID)
        return Disposables.create(_timerD, _parent._source.subscribe(self))
    }
    
    func startNewWindowAndSendCurrentOne() {
        self._windowID = self._windowID &+ 1
        let windowID = self._windowID
        
        let buffer = self._buffer
        self._buffer = []
        self.forwardOn(.next(buffer))
        
        self.createTimer(windowID)
    }
    
    //当调用onNext发送元素时调用
    func on(_ event: Event<Element>) {
        self.synchronizedOn(event)
    }

    func _synchronized_on(_ event: Event<Element>) {
        switch event {
        case .next(let element):
            //元素添加到buffer数组中，并且当满足缓存个数时，发送
            self._buffer.append(element)
            
            if self._buffer.count == self._parent._count {
                self.startNewWindowAndSendCurrentOne()
            }
            
        case .error(let error):
            self._buffer = []
            self.forwardOn(.error(error))
            self.dispose()
        case .completed:
            self.forwardOn(.next(self._buffer))
            self.forwardOn(.completed)
            self.dispose()
        }
    }
    
    //当执行run方法时调用
    func createTimer(_ windowID: Int) {
        //DisposeBase子类
        if self._timerD.isDisposed {
            return
        }
        
        if self._windowID != windowID {
            return
        }

        let nextTimer = SingleAssignmentDisposable()
        
        self._timerD.disposable = nextTimer

        //调度之后定时器执行
        let disposable = self._parent._scheduler.scheduleRelative(windowID, dueTime: self._parent._timeSpan) { previousWindowID in
            self._lock.performLocked {
                //当前窗口与回调的滑动窗口id不同则返回
                if previousWindowID != self._windowID {
                    return
                }
             
                //窗口id+1，调用self.forwardOn(.next(buffer))
                self.startNewWindowAndSendCurrentOne()
            }
            
            return Disposables.create()
        }

        nextTimer.setDisposable(disposable)
    }
}
