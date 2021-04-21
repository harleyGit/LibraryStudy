//
//  ZYRequestManager.h
//  RetryNetwork
//
//  Created by 王志盼 on 2017/12/21.
//  Copyright © 2017年 王志盼. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ZYRequest;

/**
 *  成功时调用的Block
 */
typedef void (^SuccessBlock)(id obj);

/**
 *  失败时调用的Block
 */
typedef void (^FailedBlock)(id obj);

@interface ZYRequestManager : NSObject

+ (instancetype)sharedInstance;

- (void)sendRequest:(ZYRequest *)request successBlock:(SuccessBlock)successBlock failureBlock:(FailedBlock)failedBlock;
@end
