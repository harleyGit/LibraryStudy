//
//  NSString+YEUtil.m
//  IOSDevelopTools
//
//  Created by HuangBin Ye on 2020/4/27.
//  Copyright © 2020 SimonYe. All rights reserved.
//

#import "NSString+YEUtil.h"
#import <arpa/inet.h>
@implementation NSString (YEUtil)
//替换从开始位置第一个匹配的目标字符串
- (NSString *)stringByReplacingFirstOccurrencesOfString:(NSString *)target withString:(NSString *)replacement
{
    //容错
    if (target == nil || [target isKindOfClass:[NSString class]] == NO || target.length == 0 ||
        replacement == nil || [replacement isKindOfClass:[NSString class]] == NO)
    {
        return self;
    }
    
    //获取从开始第一个匹配的Range（默认区分大小写）
    NSRange firstRange = [self rangeOfString:target];
    if (firstRange.length == 0)
    {
        return self;
    }
    
    //替换第一个匹配的目标字符串
    return [self stringByReplacingCharactersInRange:firstRange withString:replacement];
}


- (BOOL)isIPAddressString
{
    //容错
    if (self == nil || self.length == 0)
    {
        return NO;
    }
    //执行判断
    int success;
    struct in_addr dst;
    struct in6_addr dst6;
    const char *utf8 = [self UTF8String];
    
    //这行代码是将一个以 UTF-8 编码的字符串表示的 IPv4 地址转换为二进制形式的网络地址，并将结果存储在指定的变量中，同时检查转换是否成功。
    //inet_pton 是一个 POSIX 标准定义的函数，用于将一个字符串形式的 IP 地址转换为二进制形式的网络地址
    //AF_INET 是一个常量，表示 IPv4 地址族。在这里，它告诉 inet_pton 函数将输入的 IP 地址字符串解释为 IPv4 地址。
    //dst 是一个 struct in_addr 类型的结构体变量，用于存储转换后的二进制形式的 IPv4 地址。s_addr 是 struct in_addr 结构体中存储 IPv4 地址的成员。
    success = inet_pton(AF_INET, utf8, &(dst.s_addr));
    if (success == NO)
    {
        success = inet_pton(AF_INET6, utf8, &dst6);
    }
    return success;
}
@end
