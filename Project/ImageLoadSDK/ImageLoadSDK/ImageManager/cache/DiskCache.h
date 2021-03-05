//
//  DiskCache.h
//  ImageLoadSDK
//
//  Created by Harley Huang on 26/11/2020.
//
/**
 *磁盘缓存
 */

#import <Foundation/Foundation.h>
#import "DiskCacheDelegate.h"
#import "ImageCacheConfig.h"

NS_ASSUME_NONNULL_BEGIN

@interface DiskCache : NSObject<DiskCacheDelegate>

- (instancetype)initWithPath:(nullable NSString *)path withConfig:(nullable ImageCacheConfig *)config;

@end

NS_ASSUME_NONNULL_END
