//
//  ZYRequestCache.m
//  RetryNetwork
//
//  Created by 王志盼 on 2017/12/25.
//  Copyright © 2017年 王志盼. All rights reserved.
//

#import "ZYRequestCache.h"
#import "YQDStorageUtils.h"
#import "ZYRequestRealm.h"
#import "ZYRequest.h"

@interface ZYRequestCache()

@end

static id _instance = nil;

@implementation ZYRequestCache
+ (instancetype)sharedInstance
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (_instance == nil)
        {
            _instance = [[self alloc] init];
        }
    });
    
    return _instance;
}

- (NSData *)readDataForKey:(NSString *)key
{
    return [YQDStorageUtils readDataFromFileByUrl:key];
}

- (void)saveData:(NSData *)data ForKey:(NSString *)key
{
    [YQDStorageUtils saveUrl:key withData:data];
}

//将request存入realm数据库
- (void)saveRequestToRealm:(ZYRequest *)request
{
    [[ZYRequestRealm sharedInstance] addOrUpdateObj:[request copy]];
}

//将以requestId为主键的request从realm数据库中删除
- (void)deleteRequestFromRealmWithRequestId:(int)requestId
{
    [[ZYRequestRealm sharedInstance] deleteobjsWithBlock:^{
        RLMResults *results = [ZYRequest objectsWhere:@"requestId = %d", requestId];
        [[ZYRequestRealm sharedInstance] deleteResultsObj:results];
    }];
}

- (void)deleteRequestFromRealmWhere:(NSString *)predicateStr
{
    [[ZYRequestRealm sharedInstance] deleteobjsWithBlock:^{
        RLMResults *results = [ZYRequest objectsWhere:predicateStr];
        [[ZYRequestRealm sharedInstance] deleteResultsObj:results];
    }];
}

- (NSArray *)allRequestsFromRealmWihtClass:(Class)cls
{
    return [[ZYRequestRealm sharedInstance] queryAllObjsForClass:cls];
}

@end
