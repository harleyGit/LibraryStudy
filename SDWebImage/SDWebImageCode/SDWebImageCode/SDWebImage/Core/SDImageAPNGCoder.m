/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "SDImageAPNGCoder.h"
#if SD_MAC
#import <CoreServices/CoreServices.h>
#else
//MobileCoreServices 是 iOS 中的一个框架，提供了一系列与移动平台相关的核心服务。这个框架定义了许多与文件类型、统一类型标识符（UTI）以及与文件和数据相关的其他服务相关的常量和函数
#import <MobileCoreServices/MobileCoreServices.h>
#endif

// iOS 8 Image/IO framework binary does not contains these APNG contants, so we define them. Thanks Apple :)
// We can not use runtime @available check for this issue, because it's a global symbol and should be loaded during launch time by dyld. So hack if the min deployment target version < iOS 9.0, whatever it running on iOS 9+ or not.
// __IPHONE_OS_VERSION_MIN_REQUIRED 是一个宏，表示当前项目的最小支持的 iOS 版本
// __IPHONE_9_0 是一个宏，表示 iOS 9.0 的版本号
//这个条件编译的语句意味着：如果最小支持的 iOS 版本小于 iOS 9.0，那么就执行相应的代码块
#if (__IPHONE_OS_VERSION_MIN_REQUIRED && __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_9_0)
const CFStringRef kCGImagePropertyAPNGLoopCount = (__bridge CFStringRef)@"LoopCount";
const CFStringRef kCGImagePropertyAPNGDelayTime = (__bridge CFStringRef)@"DelayTime";
const CFStringRef kCGImagePropertyAPNGUnclampedDelayTime = (__bridge CFStringRef)@"UnclampedDelayTime";
#endif

@implementation SDImageAPNGCoder

+ (instancetype)sharedCoder {
    static SDImageAPNGCoder *coder;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        coder = [[SDImageAPNGCoder alloc] init];
    });
    return coder;
}

#pragma mark - Subclass Override

+ (SDImageFormat)imageFormat {
    return SDImageFormatPNG;
}

+ (NSString *)imageUTType {
    return (__bridge NSString *)kUTTypePNG;
}

+ (NSString *)dictionaryProperty {
    return (__bridge NSString *)kCGImagePropertyPNGDictionary;
}

+ (NSString *)unclampedDelayTimeProperty {
    return (__bridge NSString *)kCGImagePropertyAPNGUnclampedDelayTime;
}

+ (NSString *)delayTimeProperty {
    return (__bridge NSString *)kCGImagePropertyAPNGDelayTime;
}

+ (NSString *)loopCountProperty {
    return (__bridge NSString *)kCGImagePropertyAPNGLoopCount;
}

+ (NSUInteger)defaultLoopCount {
    return 0;
}

@end
