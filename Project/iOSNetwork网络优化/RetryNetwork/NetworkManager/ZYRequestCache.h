//
//  ZYRequestCache.h
//  RetryNetwork
//
//  Created by 王志盼 on 2017/12/25.
//  Copyright © 2017年 王志盼. All rights reserved.
//

#import <Foundation/Foundation.h>

@class  ZYRequest;
@interface ZYRequestCache : NSObject
+ (instancetype)sharedInstance;

/**
 从沙盒里面读取数据
 */
- (NSData *)readDataForKey:(NSString *)key;

/**
 将data存入沙盒路径
 */
- (void)saveData:(NSData *)data ForKey:(NSString *)key;

//将request存入realm数据库
- (void)saveRequestToRealm:(ZYRequest *)request;

//将以requestId为主键的request从realm数据库中删除
- (void)deleteRequestFromRealmWithRequestId:(int)requestId;

//将条件字符拼接在predicateStr
- (void)deleteRequestFromRealmWhere:(NSString *)predicateStr;

//realm数据库里面所有request请求
- (NSArray *)allRequestsFromRealmWihtClass:(Class)cls;
@end
