// AFNetworkReachabilityManager.m
// Copyright (c) 2011–2016 Alamofire Software Foundation ( http://alamofire.org/ )
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "AFNetworkReachabilityManager.h"
#if !TARGET_OS_WATCH

#import <netinet/in.h>
#import <netinet6/in6.h>
#import <arpa/inet.h>
#import <ifaddrs.h>
#import <netdb.h>

NSString * const AFNetworkingReachabilityDidChangeNotification = @"com.alamofire.networking.reachability.change";
NSString * const AFNetworkingReachabilityNotificationStatusItem = @"AFNetworkingReachabilityNotificationStatusItem";

typedef void (^AFNetworkReachabilityStatusBlock)(AFNetworkReachabilityStatus status);
typedef AFNetworkReachabilityManager * (^AFNetworkReachabilityStatusCallback)(AFNetworkReachabilityStatus status);

NSString * AFStringFromNetworkReachabilityStatus(AFNetworkReachabilityStatus status) {
    switch (status) {
        case AFNetworkReachabilityStatusNotReachable:
            return NSLocalizedStringFromTable(@"Not Reachable", @"AFNetworking", nil);
        case AFNetworkReachabilityStatusReachableViaWWAN:
            return NSLocalizedStringFromTable(@"Reachable via WWAN", @"AFNetworking", nil);
        case AFNetworkReachabilityStatusReachableViaWiFi:
            return NSLocalizedStringFromTable(@"Reachable via WiFi", @"AFNetworking", nil);
        case AFNetworkReachabilityStatusUnknown:
        default:
            return NSLocalizedStringFromTable(@"Unknown", @"AFNetworking", nil);
    }
}

static AFNetworkReachabilityStatus AFNetworkReachabilityStatusForFlags(SCNetworkReachabilityFlags flags) {
    BOOL isReachable = ((flags & kSCNetworkReachabilityFlagsReachable) != 0);
    BOOL needsConnection = ((flags & kSCNetworkReachabilityFlagsConnectionRequired) != 0);
    BOOL canConnectionAutomatically = (((flags & kSCNetworkReachabilityFlagsConnectionOnDemand ) != 0) || ((flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0));
    BOOL canConnectWithoutUserInteraction = (canConnectionAutomatically && (flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0);
    BOOL isNetworkReachable = (isReachable && (!needsConnection || canConnectWithoutUserInteraction));

    AFNetworkReachabilityStatus status = AFNetworkReachabilityStatusUnknown;
    if (isNetworkReachable == NO) {
        status = AFNetworkReachabilityStatusNotReachable;
    }
#if	TARGET_OS_IPHONE
    else if ((flags & kSCNetworkReachabilityFlagsIsWWAN) != 0) {
        status = AFNetworkReachabilityStatusReachableViaWWAN;
    }
#endif
    else {
        status = AFNetworkReachabilityStatusReachableViaWiFi;
    }

    return status;
}

/**
 * Queue a status change notification for the main thread.
 *
 * This is done to ensure that the notifications are received in the same order
 * as they are sent. If notifications are sent directly, it is possible that
 * a queued notification (for an earlier status condition) is processed after
 * the later update, resulting in the listener being left in the wrong state.
 */
static void AFPostReachabilityStatusChange(SCNetworkReachabilityFlags flags, AFNetworkReachabilityStatusCallback block) {
    AFNetworkReachabilityStatus status = AFNetworkReachabilityStatusForFlags(flags);
    dispatch_async(dispatch_get_main_queue(), ^{
        AFNetworkReachabilityManager *manager = nil;
        if (block) {
            manager = block(status);
        }
        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
        NSDictionary *userInfo = @{ AFNetworkingReachabilityNotificationStatusItem: @(status) };
        [notificationCenter postNotificationName:AFNetworkingReachabilityDidChangeNotification object:manager userInfo:userInfo];
    });
}

/// SCNetworkReachabilityFlags 是用于表示网络可达性的标志位（flags）的一个数据类型，通常在iOS和macOS开发中使用。
static void AFNetworkReachabilityCallback(SCNetworkReachabilityRef __unused target, SCNetworkReachabilityFlags flags, void *info) {
    AFPostReachabilityStatusChange(flags, (__bridge AFNetworkReachabilityStatusCallback)info);
}


static const void * AFNetworkReachabilityRetainCallback(const void *info) {
    //Block_copy 这个宏的作用是用于安全地复制传递给它的 Block，并保持类型一致性。在 ARC 环境中，通常不需要手动管理 Block 的内存，但在某些情况下，特别是在 C 函数指针等地方，可能需要手动复制 Block。
    return Block_copy(info);
}

static void AFNetworkReachabilityReleaseCallback(const void *info) {
    if (info) {
        Block_release(info);
    }
}

@interface AFNetworkReachabilityManager ()
/**
 *SCNetworkReachabilityRef 是 Core Foundation 框架中与网络可达性相关的引用类型。它用于在 macOS 和 iOS 等苹果平台上检查设备的网络连接状态。具体而言，它提供了一种方法来检测设备是否可以访问特定的网络地址，并提供了有关网络连接的信息。
 *   这个引用类型通常用于以下目的：
 *
 *      检测网络连接状态： 通过使用 SCNetworkReachabilityCreateWithName 或 SCNetworkReachabilityCreateWithAddress 等函数创建一个 SCNetworkReachabilityRef 实例，然后使用 SCNetworkReachabilityGetFlags 函数获取网络连接的状态。
 
 *      监测网络连接的变化： 通过使用 SCNetworkReachabilitySetCallback 和 SCNetworkReachabilityScheduleWithRunLoop 等函数设置回调函数，可以监视网络连接状态的变化，当网络状态发生变化时，会触发注册的回调函数。
 
 *      处理网络连接状态变化： 使用注册的回调函数处理网络连接状态的变化，以便在网络状态发生变化时采取适当的操作
 */
@property (readonly, nonatomic, assign) SCNetworkReachabilityRef networkReachability;
@property (readwrite, nonatomic, assign) AFNetworkReachabilityStatus networkReachabilityStatus;
@property (readwrite, nonatomic, copy) AFNetworkReachabilityStatusBlock networkReachabilityStatusBlock;
@end

@implementation AFNetworkReachabilityManager

+ (instancetype)sharedManager {
    static AFNetworkReachabilityManager *_sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedManager = [self manager];
    });

    return _sharedManager;
}

+ (instancetype)managerForDomain:(NSString *)domain {
    //创建一个网络可达性引用，以检查指定域名的网络连接状态
    //SCNetworkReachabilityCreateWithName: 这是创建网络可达性引用的函数。它接受两个参数，第一个参数是分配器（Allocator），用于分配内存。kCFAllocatorDefault 是 Core Foundation 默认的分配器
    SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithName(kCFAllocatorDefault, [domain UTF8String]);

    AFNetworkReachabilityManager *manager = [[self alloc] initWithReachability:reachability];
    
    CFRelease(reachability);

    return manager;
}


/// ，用于根据给定的网络地址创建并返回一个 AFNetworkReachabilityManager 的实例。这个类通常用于监测设备与网络的连接状态
/// @param address 网络地址
+ (instancetype)managerForAddress:(const void *)address {
    //使用 SCNetworkReachabilityCreateWithAddress 函数，通过指定的网络地址（address）创建了一个 SCNetworkReachabilityRef 对象。这个对象用于检测与指定网络地址的可达性，即设备是否能够成功连接到该网络地址
    SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr *)address);
    //AFNetworkReachabilityManager 是 AFNetworking 库提供的一个用于监测网络可达性的类
    AFNetworkReachabilityManager *manager = [[self alloc] initWithReachability:reachability];

    CFRelease(reachability);
    
    return manager;
}


/// 在创建网络请求时用于获取适当的 AFHTTPSessionManager 的一部分。它通过检查操作系统版本来选择性地使用 IPv6 或 IPv4 地址结构，并创建相应的网络请求管理器
+ (instancetype)manager
{
/** 如果是 iOS 9.0+ 或 macOS 10.11+，则使用IPv6
 * defined(__IPHONE_OS_VERSION_MIN_REQUIRED) 是一个条件编译预处理宏，用于检查是否定义了 __IPHONE_OS_VERSION_MIN_REQUIRED，以确定编译时的目标最低 iOS 版本
 *
 * 在 iOS 开发中，可以使用这个宏来根据部署目标的最低版本进行条件编译，以确保代码在较旧版本的 iOS 上也能正常运行
 *
 * 如果 __IPHONE_OS_VERSION_MIN_REQUIRED 被定义且大于等于 90000（即 iOS 9.0），则表示目标部署版本是 iOS 9.0 或更高版本
 */
#if (defined(__IPHONE_OS_VERSION_MIN_REQUIRED) && __IPHONE_OS_VERSION_MIN_REQUIRED >= 90000) || (defined(__MAC_OS_X_VERSION_MIN_REQUIRED) && __MAC_OS_X_VERSION_MIN_REQUIRED >= 101100)
    //声明了一个名为 address 的结构体变量，类型为 struct sockaddr_in6，表示 IPv6 地址结构。
    struct sockaddr_in6 address;
    //使用 bzero 函数将 address 变量的内存内容全部置零。这确保了在设置结构体的各个字段之前，结构体的内存是清零的
    bzero(&address, sizeof(address));
    //设置 IPv6 地址结构的长度字段 (sin6_len) 为结构体的大小，以表示该结构体的实际长度。
    address.sin6_len = sizeof(address);
    //设置 IPv6 地址结构的地址簇字段 (sin6_family) 为 AF_INET6，表示这是一个 IPv6 地址
    address.sin6_family = AF_INET6;
#else
    // 否则，使用IPv4
    struct sockaddr_in address;
    bzero(&address, sizeof(address));
    address.sin_len = sizeof(address);
    address.sin_family = AF_INET;
#endif
    // 通过选择的地址结构创建AFHTTPSessionManager对象
    return [self managerForAddress:&address];
}


/// 初始化网络可达性监测器的状态
/// @param reachability <#reachability description#>
- (instancetype)initWithReachability:(SCNetworkReachabilityRef)reachability {
    self = [super init];
    if (!self) {
        return nil;
    }

    //调用 CFRetain 函数对 reachability 对象进行引用计数的增加
    _networkReachability = CFRetain(reachability);
    //AFNetworkReachabilityStatusUnknown 是 AFNetworkReachabilityManager 类中定义的一个枚举值，表示网络可达性状态未知。这是初始状态，因为在初始化时还未进行实际的可达性检测
    self.networkReachabilityStatus = AFNetworkReachabilityStatusUnknown;

    return self;
}

- (instancetype)init
{
    @throw [NSException exceptionWithName:NSGenericException
                                   reason:@"`-init` unavailable. Use `-initWithReachability:` instead"
                                 userInfo:nil];
    return nil;
}

- (void)dealloc {
    [self stopMonitoring];
    
    if (_networkReachability != NULL) {
        CFRelease(_networkReachability);
    }
}

#pragma mark -

- (BOOL)isReachable {
    return [self isReachableViaWWAN] || [self isReachableViaWiFi];
}

- (BOOL)isReachableViaWWAN {
    return self.networkReachabilityStatus == AFNetworkReachabilityStatusReachableViaWWAN;
}

- (BOOL)isReachableViaWiFi {
    return self.networkReachabilityStatus == AFNetworkReachabilityStatusReachableViaWiFi;
}

#pragma mark -

- (void)startMonitoring {
    [self stopMonitoring];

    if (!self.networkReachability) {
        return;
    }

    __weak __typeof(self)weakSelf = self;
    AFNetworkReachabilityStatusCallback callback = ^(AFNetworkReachabilityStatus status) {
        __strong __typeof(weakSelf)strongSelf = weakSelf;

        strongSelf.networkReachabilityStatus = status;
        if (strongSelf.networkReachabilityStatusBlock) {
            strongSelf.networkReachabilityStatusBlock(status);
        }
        
        return strongSelf;
    };

    // 创建一个 SCNetworkReachabilityContext 结构体，用于传递回调函数相关的信息
    SCNetworkReachabilityContext context = {0, (__bridge void *)callback, AFNetworkReachabilityRetainCallback, AFNetworkReachabilityReleaseCallback, NULL};
    //设置网络可达性引用的回调函数.在这里，传递了 AFNetworkReachabilityCallback 作为回调函数，并将 context 作为上下文信息传递给回调函数。这意味着当网络状态发生变化时，会调用 AFNetworkReachabilityCallback 函数，并将 context 中的信息传递给该函数
    SCNetworkReachabilitySetCallback(self.networkReachability, AFNetworkReachabilityCallback, &context);
    
    //在主运行循环上注册回调函数，以便在网络状态发生变化时得到通知
    //CFRunLoopGetMain() 获取主运行循环，kCFRunLoopCommonModes 表示将回调函数添加到主运行循环的通用模式中，以确保在不同的运行循环模式下都能接收到通知
    SCNetworkReachabilityScheduleWithRunLoop(self.networkReachability, CFRunLoopGetMain(), kCFRunLoopCommonModes);

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0),^{
        SCNetworkReachabilityFlags flags;
        if (SCNetworkReachabilityGetFlags(self.networkReachability, &flags)) {
            AFPostReachabilityStatusChange(flags, callback);
        }
    });
}

- (void)stopMonitoring {
    if (!self.networkReachability) {
        return;
    }

    SCNetworkReachabilityUnscheduleFromRunLoop(self.networkReachability, CFRunLoopGetMain(), kCFRunLoopCommonModes);
}

#pragma mark -

- (NSString *)localizedNetworkReachabilityStatusString {
    return AFStringFromNetworkReachabilityStatus(self.networkReachabilityStatus);
}

#pragma mark -

- (void)setReachabilityStatusChangeBlock:(void (^)(AFNetworkReachabilityStatus status))block {
    self.networkReachabilityStatusBlock = block;
}

#pragma mark - NSKeyValueObserving

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
    if ([key isEqualToString:@"reachable"] || [key isEqualToString:@"reachableViaWWAN"] || [key isEqualToString:@"reachableViaWiFi"]) {
        return [NSSet setWithObject:@"networkReachabilityStatus"];
    }

    return [super keyPathsForValuesAffectingValueForKey:key];
}

@end
#endif
