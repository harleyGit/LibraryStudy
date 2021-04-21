//
//  ZYRequest.h
//  RetryNetwork
//
//  Created by 王志盼 on 2017/12/21.
//  Copyright © 2017年 王志盼. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZYRequestMacro.h"
#import <Realm/Realm.h>



typedef NS_ENUM(NSInteger, ZYRequestReliability){

    //如果没有发送成功，就放入调度队列再次发送
    ZYRequestReliabilityRetry,
    
    //必须要成功的请求，如果不成功就存入DB，然后在网络好的情况下继续发送，类似微信发消息
    //需要注意的是，这类请求不需要回调的
    //类似于发微信成功与否
    //就是必定成功的请求，只需要在有网的状态下，必定成功
    ZYRequestReliabilityStoreToDB,
    
    //普通请求，成不成功不影响业务，不需要重新发送
    //类似统计、后台拉取本地已有的配置之类的请求
    ZYRequestReliabilityNormal
};


@interface ZYRequest : RLMObject<NSCopying>

//存入数据库的唯一标示
@property (nonatomic, assign) int requestId;

/**请求参数对*/
@property (nonatomic, strong) NSDictionary *params;


/**
 请求的url
 */
@property (nonatomic, copy) NSString *urlStr;

/**
 请求重复策略，默认重发
 */
@property (nonatomic, assign) ZYRequestReliability reliability;

/**
 请求方法，默认get请求
 */
@property (nonatomic, assign) YQDRequestType method;


/**
 是否需要缓存响应的数据，如果cacheKey为nil，就不会缓存响应的数据
 */
@property (nonatomic, copy) NSString *cacheKey;

/**
 请求没发送成功，重新发送的次数
 */
@property (nonatomic, assign, readonly) int retryCount;


/**
 realm不支持NSDictionary，所以params直接转化为字符串存储
 只在请求需要存入数据库中，此参数才有相应的作用
 ZYRequestReliabilityStoreToDB这种类型下
 */
@property (nonatomic, copy, readonly) NSString *paramStr;


- (void)reduceRetryCount;
@end
RLM_ARRAY_TYPE(ZYRequest)
