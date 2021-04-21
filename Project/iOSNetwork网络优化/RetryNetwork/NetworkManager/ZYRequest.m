//
//  ZYRequest.m
//  RetryNetwork
//
//  Created by 王志盼 on 2017/12/21.
//  Copyright © 2017年 王志盼. All rights reserved.
//

#import "ZYRequest.h"

@interface ZYRequest()
@property (nonatomic, assign, readwrite) int retryCount;
@property (nonatomic, copy, readwrite) NSString *paramStr;


@end

@implementation ZYRequest

- (instancetype)init
{
    if (self = [super init])
    {
        self.retryCount = 3;
        self.reliability = ZYRequestReliabilityRetry;
        self.method = YQDRequestTypeGet;
        self.cacheKey = nil;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    ZYRequest *request = [[[self class] allocWithZone:zone] init];
    request.retryCount = self.retryCount;
    request.reliability = self.reliability;
    request.method = self.method;
    request.cacheKey = self.cacheKey;
    request.requestId = self.requestId;
    request.params = self.params;
    request.urlStr = self.urlStr;
    request.paramStr = self.paramStr;
    
    return request;
}

- (void)setReliability:(ZYRequestReliability)reliability
{
    _reliability = reliability;
    
    if (reliability == ZYRequestReliabilityNormal)
    {
        _retryCount = 1;
    }
    
    [self setParams:_params];
}

- (void)setParams:(NSDictionary *)params
{
    _params = params;
    
    if (!params) return;
    
    if (_reliability == ZYRequestReliabilityStoreToDB)
    {
        NSData *data = [NSJSONSerialization dataWithJSONObject:self.params options:NSJSONWritingPrettyPrinted error:nil];
        self.paramStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
}

- (void)reduceRetryCount
{
    self.retryCount--;
    if (self.retryCount < 0) self.retryCount = 0;
}

- (BOOL)isEqual:(ZYRequest *)object
{
    if (object == nil) return false;
    
    if (object.requestId == self.requestId || object == self) return true;
    
    return false;
}

#pragma mark - realm的相关处理

+ (NSString *)primaryKey
{
    return @"requestId";
}

+ (NSArray<NSString *> *)ignoredProperties
{
    return @[@"params"];
}

@end
