//
//  HXWRunloopTask.h
//  UITableView加载高清图卡顿NSRunloop解决方案
//
//  Created by BTI-HXW on 2019/6/5.
//  Copyright © 2019 BTI-HXW. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^RunloopTask)(void);


@interface HXWRunloopTask : NSObject

- (void)addTask:(RunloopTask)task;

@end

NS_ASSUME_NONNULL_END
