//
//  ImageCacheConfig.h
//  ImageLoadSDK
//
//  Created by Harley Huang on 26/11/2020.
//
/**
 *磁盘缓存管理
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ImageCacheConfig : NSObject

@property (nonatomic, assign) BOOL shouldCacheImagesInMemory; //是否使用内存缓存
@property (nonatomic, assign) BOOL shouldCacheImagesInDisk; //是否使用磁盘缓存
@property (nonatomic, assign) NSInteger maxCacheAge; //文件最大缓存时间
@property (nonatomic, assign) NSInteger maxCacheSize; //文件缓存最大限制

@end

NS_ASSUME_NONNULL_END
