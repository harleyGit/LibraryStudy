//
//  YQDHttpClinetCore.h
//  YQD_iPhone
//
//  Created by 王志盼 on 2017/7/24.
//  Copyright © 2017年 王志盼. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AFNetworking.h"
#import "ZYRequestMacro.h"



/**
 *  请求开始前预处理Block
 */
typedef void(^PrepareExecuteBlock)(void);

@interface YQDHttpClinetCore : NSObject
+ (instancetype)sharedClient;


// 监听网络状态，判断是否有网
- (void)startMonitoringNetwork;

/**
 *  HTTP请求（GET、POST、DELETE、PUT）
 *  @param method      RESTFul请求类型
 *  @param parameters  请求参数
 *  @param prepare     请求前预处理块
 *  @param success     请求成功处理块
 *  @param failure     请求失败处理块
 */

//NSURLSessoin，iOS7.0之后
- (void)requestWithPath:(NSString *)url method:(NSInteger)method parameters:(id)parameters prepareExecute:(PrepareExecuteBlock)prepare success:(void(^)(NSURLSessionDataTask *task,id responseObject))success failure:(void(^)(NSURLSessionDataTask *task,NSError *error))failure;


/**
 *  HTTP请求（HEAD）
 */
- (void)requestWithPathInHEAD:(NSString *)url
                   parameters:(NSDictionary *)parameters
                      success:(void (^)(NSURLSessionDataTask *task))success
                      failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure;



/**
 *  图片上传方法
 *
 *  @param URL        请求url
 *  @param parameters 需要的参数
 *  @param image      上传的图片
 *  @param name       上传到服务器中接受该文件的字段名，不能为空
 *  @param fileName   存到服务器中的文件名，不能为空
 */
- (void)uploadWithURL:(NSString *)URL
           parameters:(id)parameters
                image:(UIImage *)image
                 name:(NSString *)name
             fileName:(NSString *)fileName
              success:(void(^)(id responseObject))success
              failure:(void(^)(NSError *error))failure;
@end
