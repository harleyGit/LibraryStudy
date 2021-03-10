//
//  RunloopController.m
//  RunLoopWorkDistribution
//
//  Created by Harley Huang on 10/3/2021.
//  Copyright © 2021 Di Wu. All rights reserved.
//

#import "RunloopController.h"

@interface RunloopController ()

@end

@implementation RunloopController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = UIColor.redColor;
    [self addRunLoopObserver];
    [self initData];
}

- (void)initData{
    _name = @"piaojin";
    //默认会添加到当前的runLoop中去,不做任何事情,为了让runLoop一直处理任务而不去睡眠
    _runLoopObServerTimer = [NSTimer scheduledTimerWithTimeInterval:0.001 target:self selector:@selector(timerMethod) userInfo:nil repeats:YES];
}

- (void)addRunLoopObserver{
    //获取当前的CFRunLoopRef
    CFRunLoopRef runLoopRef = CFRunLoopGetCurrent();
    //创建上下文,用于控制器数据的获取
    CFRunLoopObserverContext context =  {
        0,
        (__bridge void *)(self),//self传递过去
        &CFRetain,
        &CFRelease,
        NULL
    };
    //创建一个监听
    static CFRunLoopObserverRef observer;
    observer = CFRunLoopObserverCreate(NULL, kCFRunLoopBeforeWaiting, YES, 0, &runLoopOserverCallBack,&context);
    //注册监听
    CFRunLoopAddObserver(runLoopRef, observer, kCFRunLoopCommonModes);
    //销毁
    CFRelease(observer);
}

//监听CFRunLoopRef回调函数
static void runLoopOserverCallBack(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info){
    RunloopController *viewController = (__bridge RunloopController *)(info);//void *info即是我们前面传递的self(ViewController)
    
    NSLog(@"runLoopOserverCallBack -> name = %@",viewController.name);
}

- (void)timerMethod{
    //不做任何事情,为了让runLoop一直处理任务而不去睡眠
}



@end
