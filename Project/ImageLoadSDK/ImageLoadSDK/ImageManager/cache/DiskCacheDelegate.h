//
//  DiskCacheDelegate.h
//  ImageLoadSDK
//
//  Created by Harley Huang on 26/11/2020.
//

/**
 * 文件增删查改操作协议
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol DiskCacheDelegate <NSObject>

- (void)storeImageData:(nullable NSData *)imageData
                forKey:(nullable NSString *)key;
- (nullable NSData *)queryImageDataForKey:(nullable NSString *)key;
- (BOOL)removeImageDataForKey:(nullable NSString *)key;
- (BOOL)containImageDataForKey:(nullable NSString *)key;
- (void)clearDiskCache;

@optional
/// 后台更新文件
- (void)deleteOldFiles;

@end

NS_ASSUME_NONNULL_END
