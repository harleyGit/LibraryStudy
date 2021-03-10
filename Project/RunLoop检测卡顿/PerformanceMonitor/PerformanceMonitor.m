//
//  PerformanceMonitor.m
//  SuperApp
//
//  Created by tanhao on 15/11/12.
//  Copyright © 2015年 Tencent. All rights reserved.
//

#import "PerformanceMonitor.h"
#import <CrashReporter/CrashReporter.h>

@interface PerformanceMonitor ()
{
    int timeoutCount; // 耗时次数
    CFRunLoopObserverRef observer;// 观察者
    
@public
    dispatch_semaphore_t semaphore; // 信号
    CFRunLoopActivity activity;// 状态
}
@end

@implementation PerformanceMonitor

+ (instancetype)sharedInstance
{
    static id instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

//要监控NSRunLoop的状态,我们需要使用到CFRunLoopObserverRef,通过它可以实时获得这些状态值的变化
static void runLoopObserverCallBack(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info)
{
    PerformanceMonitor *moniotr = (__bridge PerformanceMonitor*)info;
    
    //记录状态值
    moniotr->activity = activity;
    
    //发送信号
    dispatch_semaphore_t semaphore = moniotr->semaphore;
    long st = dispatch_semaphore_signal(semaphore);
    NSLog(@"dispatch_semaphore_signal:st=%ld,time:%@",st,[PerformanceMonitor getCurTime]);
    
    
    /* Run Loop Observer Activities */
    //    typedef CF_OPTIONS(CFOptionFlags, CFRunLoopActivity) {
    //        kCFRunLoopEntry = (1UL << 0),    // 进入RunLoop循环(这里其实还没进入)
    //        kCFRunLoopBeforeTimers = (1UL << 1),  // RunLoop 要处理timer了
    //        kCFRunLoopBeforeSources = (1UL << 2), // RunLoop 要处理source了
    //        kCFRunLoopBeforeWaiting = (1UL << 5), // RunLoop要休眠了
    //        kCFRunLoopAfterWaiting = (1UL << 6),   // RunLoop醒了
    //        kCFRunLoopExit = (1UL << 7),           // RunLoop退出（和kCFRunLoopEntry对应）
    //        kCFRunLoopAllActivities = 0x0FFFFFFFU
    //    };
    
    if (activity == kCFRunLoopEntry) {  // 即将进入RunLoop
        NSLog(@"runLoopObserverCallBack - %@",@"kCFRunLoopEntry");
    } else if (activity == kCFRunLoopBeforeTimers) {    // 即将处理Timer
        NSLog(@"runLoopObserverCallBack - %@",@"kCFRunLoopBeforeTimers");
    } else if (activity == kCFRunLoopBeforeSources) {   // 即将处理Source
        NSLog(@"runLoopObserverCallBack - %@",@"kCFRunLoopBeforeSources");
    } else if (activity == kCFRunLoopBeforeWaiting) {   //即将进入休眠
        NSLog(@"runLoopObserverCallBack - %@",@"kCFRunLoopBeforeWaiting");
    } else if (activity == kCFRunLoopAfterWaiting) {    // 刚从休眠中唤醒
        NSLog(@"runLoopObserverCallBack - %@",@"kCFRunLoopAfterWaiting");
    } else if (activity == kCFRunLoopExit) {    // 即将退出RunLoop
        NSLog(@"runLoopObserverCallBack - %@",@"kCFRunLoopExit");
    } else if (activity == kCFRunLoopAllActivities) {
        NSLog(@"runLoopObserverCallBack - %@",@"kCFRunLoopAllActivities");
    }
    
}

- (void)stop
{
    if (!observer)
        return;
    
    CFRunLoopRemoveObserver(CFRunLoopGetMain(), observer, kCFRunLoopCommonModes);
    CFRelease(observer);
    observer = NULL;
}

- (void)start
{
    if (observer)
        return;
    
    // 信号
    semaphore = dispatch_semaphore_create(0);
    NSLog(@"dispatch_semaphore_create:%@",[PerformanceMonitor getCurTime]);
    
    
    // 注册RunLoop状态观察, 设置Run Loop observer的运行环境
    CFRunLoopObserverContext context = {0,(__bridge void*)self,NULL,NULL};
    
    /*
     创建Run loop observer对象
     第一个参数用于分配该observer对象的内存
     第二个参数用以设置该observer所要关注的的事件，详见回调函数myRunLoopObserver中注释
     第三个参数用于标识该observer是在第一次进入run loop时执行还是每次进入run loop处理时均执行
     第四个参数用于设置该observer的优先级
     第五个参数用于设置该observer的回调函数
     第六个参数用于设置该observer的运行环境
     */
    observer = CFRunLoopObserverCreate(kCFAllocatorDefault,
                                       kCFRunLoopAllActivities,
                                       YES,
                                       0,
                                       &runLoopObserverCallBack,
                                       &context);
    //将新建的observer加入到当前的thread的runLoop， CFRunLoopGetMain()获得主线程对应的runloop
    CFRunLoopAddObserver(CFRunLoopGetMain(), observer, kCFRunLoopCommonModes);
    
    // 在子线程监控时长
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        while (YES)
        {
            // 有信号的话 就查询当前runloop的状态
            // 假定连续5次超时50ms认为卡顿(当然也包含了单次超时250ms)
            // 因为下面 runloop 状态改变回调方法runLoopObserverCallBack中会将信号量递增 1,所以每次 runloop 状态改变后,下面的语句都会执行一次
            // dispatch_semaphore_wait:Returns zero on success, or non-zero if the timeout occurred.
            long st = dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 50*NSEC_PER_MSEC));
            if (st != 0)
            {
                if (!observer)
                {
                    timeoutCount = 0;
                    semaphore = 0;
                    activity = 0;
                    return;
                }
                
                NSLog(@"st = %ld,activity = %lu,timeoutCount = %d,time:%@",st,activity,timeoutCount,[self getCurTime]);
                
                //activiety 是即将处理 source 和 即将 sleep
                //调用方法主要就是在kCFRunLoopBeforeSources和kCFRunLoopBeforeWaiting之间,还有kCFRunLoopAfterWaiting之后,也就是如果我们发现这两个时间内耗时太长,那么就可以判定出此时主线程卡顿
                if (activity==kCFRunLoopBeforeSources || activity==kCFRunLoopAfterWaiting)
                {
                    if (++timeoutCount < 5)
                        continue;
                    //处理卡顿信息上传到服务器
                    PLCrashReporterConfig *config = [[PLCrashReporterConfig alloc] initWithSignalHandlerType:PLCrashReporterSignalHandlerTypeBSD
                                                                                       symbolicationStrategy:PLCrashReporterSymbolicationStrategyAll];
                    PLCrashReporter *crashReporter = [[PLCrashReporter alloc] initWithConfiguration:config];
                    
                    NSData *data = [crashReporter generateLiveReport];
                    PLCrashReport *reporter = [[PLCrashReport alloc] initWithData:data error:NULL];
                    NSString *report = [PLCrashReportTextFormatter stringValueForCrashReport:reporter
                                                                              withTextFormat:PLCrashReportTextFormatiOS];
                    //将字符串上传到服务器
                    NSLog(@"------------\n%@\n------------", report);
                }
            }
            timeoutCount = 0;
        }
    });
}

#pragma mark - private function

- (NSString *)getCurTime {
    NSDateFormatter *format = [[NSDateFormatter alloc] init];
    [format setDateFormat:@"YYYY/MM/dd hh:mm:ss:SSS"];
    NSString *curTime = [format stringFromDate:[NSDate date]];
    
    return curTime;
}

+ (NSString *) getCurTime {
    NSDateFormatter *format = [[NSDateFormatter alloc] init];
    [format setDateFormat:@"YYYY/MM/dd hh:mm:ss:SSS"];
    NSString *curTime = [format stringFromDate:[NSDate date]];
    
    return curTime;
}


@end
