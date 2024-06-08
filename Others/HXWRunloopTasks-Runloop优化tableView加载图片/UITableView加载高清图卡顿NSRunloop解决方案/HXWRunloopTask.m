//
//  HXWRunloopTask.m
//  UITableView加载高清图卡顿NSRunloop解决方案
//
//  Created by BTI-HXW on 2019/6/5.
//  Copyright © 2019 BTI-HXW. All rights reserved.
//

#import "HXWRunloopTask.h"
#define MAXTASKS 18

@interface HXWRunloopTask ()
/**
 任务
 */
@property (nonatomic, strong) NSMutableArray<RunloopTask> *tasks;
/**
 timer，唤醒runloop
 */
@property (nonatomic, strong) NSTimer *taskTimer;

@end


@implementation HXWRunloopTask


-(instancetype)init{
    if (self = [super init]) {
        [[NSRunLoop currentRunLoop] addTimer:self.taskTimer forMode:NSDefaultRunLoopMode];
        [self addObserver];
    }
    return self;
}


-(void)dealloc{
    [self.taskTimer invalidate];
    self.taskTimer = nil;
}

- (NSMutableArray<RunloopTask> *)tasks{
    if (!_tasks) {
        _tasks = [NSMutableArray new];
    }
    return _tasks;
}
///保持runloop一直运转
-(NSTimer *)taskTimer{
    if (!_taskTimer) {
        _taskTimer = [NSTimer scheduledTimerWithTimeInterval:0.001 repeats:YES block:^(NSTimer * _Nonnull timer) {
            
        }];
        
    }
    return _taskTimer;
}
///添加到任务队列中
-(void)addTask:(RunloopTask)task{
    [self.tasks addObject:task];
    if (self.tasks.count > MAXTASKS) {
        [self.tasks removeObjectAtIndex:0];
    }
}
#pragma mark 向runloop中注册observer
- (void)addObserver{
    //拿到当前的Runloop
    CFRunLoopRef runloop = CFRunLoopGetCurrent();
    
    /** 配置一个 CFRunLoopObserverContext 结构体，用于设置 Run Loop Observer 的上下文信息，确保在使用时正确地管理相关对象的内存
     
     version：这是一个整数，用于指定 CFRunLoopObserverContext 结构体的版本号。通常情况下，你可以将其设置为 0。在这个例子中，它被设置为 0。
     
     info：这是一个指针，用于指向一个你希望在 Run Loop Observer 中使用的自定义数据结构或对象。在这里，通过 (__bridge void *)(self) 将 Objective-C 对象 self 转换为一个 void 类型的指针，然后存储在 info 中。这样做是为了在 Run Loop Observer 回调函数中能够访问到当前对象的信息。
     
     retain：这是一个函数指针，指向一个用于增加引用计数的函数。在这里，&CFRetain 是一个函数指针，指向 Core Foundation 的 CFRetain 函数，用于增加引用计数。这意味着当 Run Loop Observer 中的 info 被传递给你的回调函数时，它的引用计数会被增加，以防止在使用期间被释放。
     
     release：这是一个函数指针，指向一个用于减少引用计数的函数。在这里，&CFRelease 是一个函数指针，指向 Core Foundation 的 CFRelease 函数，用于减少引用计数。这意味着当 Run Loop Observer 中的 info 不再被需要时，其引用计数会被减少，以便在不再需要时释放相关资源。
     retain 和 release 函数用于确保 info 在合适的时候进行内存管理，以防止内存泄漏。
     
     最后一个成员变量 NULL 是一个预留字段，通常不需要设置，因为它在这个例子中没有被使用到。
     */
    CFRunLoopObserverContext context = {
        0,
        (__bridge void *)(self),
        &CFRetain,
        &CFRelease,
        NULL
    };
    
    //定义一个观察者,static内存中只存在一个
    static CFRunLoopObserverRef obverser;
    
    //创建一个观察者
    /** 创建一个在 Run Loop 等待状态之后触发的观察者，并将其添加到指定的 Run Loop 中的默认模式下。这样做可能是为了在 Run Loop 处于空闲状态时执行某些任务或者进行一些特定的操作。
     
     CFRunLoopObserverCreate 是创建 Run Loop 观察者的函数，它需要几个参数：
     第一个参数是一个分配的 CFAllocator 对象，用于分配内存。在这里设置为 NULL，表示使用默认的分配器。
     
     第二个参数是一个 CFRunLoopActivity 枚举值，指定了要观察的 Run Loop 行为。在这里设置为 kCFRunLoopAfterWaiting，表示在 Run Loop 处于等待状态之后触发回调。
     
     第三个参数是一个 Boolean 值，指定了是否重复执行观察者。在这里设置为 YES，表示观察者会被重复执行。
     
     第四个参数是一个 CFIndex 类型的值，用于指定优先级。在这里设置为 0，表示默认优先级。
     
     第五个参数是一个函数指针，指定了观察者的回调函数。
     
     最后一个参数是一个指向 CFRunLoopObserverContext 结构体的指针，其中包含了观察者的上下文信息。这里将之前创建的 context 结构体的地址传递给了观察者。
     
     
     疑问:为什么要在 kCFRunLoopAfterWaiting 时处理图片加载呢？
     
     可能是因为在这个时机，RunLoop已经完成了一次等待状态，可能是处理完其他任务后的一段空闲时间，这时候可以选择性地执行一些耗时较长的操作，比如图片加载。这样做可以避免图片加载等耗时操作对于界面的流畅度产生太大影响，因为这段代码会在 Run Loop 闲置的时候执行，而不会阻塞其他任务的执行。
     */
    obverser = CFRunLoopObserverCreate(NULL, kCFRunLoopAfterWaiting, YES, 0, &callBack, &context);
    
    /** CFRunLoopAddObserver 函数用于将观察者添加到指定的 Run Loop 中。
     
     第一个参数是要添加观察者的 Run Loop。在这里，runloop 可能是你之前获取到的某个 Run Loop 的引用。
     
     第二个参数是要添加的观察者对象，即之前创建的 obverser。
     
     第三个参数是 Run Loop 的运行模式。在这里，kCFRunLoopDefaultMode 表示将观察者添加到 Run Loop 的默认模式中。
     */
    //添加观察者！！！默认模式下，滑动的时候不处理渲染任务
    CFRunLoopAddObserver(runloop, obverser, kCFRunLoopDefaultMode);
    
    //release
    CFRelease(obverser);
}
///runloop即将休眠的observer回调
void callBack (CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info){
    HXWRunloopTask *runloopTask = (__bridge HXWRunloopTask*)info;
    if(runloopTask.tasks.count==0){
        return;
    }
    ///从任务队列中去任务执行
    RunloopTask task = runloopTask.tasks.firstObject;
    task();
    [runloopTask.tasks removeObjectAtIndex:0];
}
@end
