//
//  ImageCache.h
//  ImageLoadSDK
//
//  Created by Harley Huang on 18/11/2020.
//
/**
 *图片磁盘缓存
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "DiskCacheDelegate.h"
#import "ImageCacheConfig.h"


typedef NS_ENUM(NSUInteger, ImageCacheType) {
    ImageCacheTypeNone = 0,
    ImageCacheTypeMemory = 1 << 0,
    ImageCacheTypeDisk = 1 << 1,
    ImageCacheTypeAll = ImageCacheTypeMemory | ImageCacheTypeDisk

};

typedef NSCache MemoryCache;

NS_ASSUME_NONNULL_BEGIN

@interface ImageCache : NSObject

@property (nonatomic, strong) id<DiskCacheDelegate> diskCache;
@property (nonatomic, strong) MemoryCache *memoryCache;
@property (nonatomic, strong) ImageCacheConfig *cacheConfig;


+ (instancetype)shareManager;

- (instancetype)initWithNameSpace:(nullable NSString *)nameSpace;

- (instancetype)initWithNameSpace:(NSString *)nameSpace diskDirectoryPath:(NSString *)directory;


//DEPRECATED_MSG_ATTRIBUTE 替换方法警告说明
- (UIImage *)queryImageCacheForKey:(NSString *)key DEPRECATED_MSG_ATTRIBUTE("please use queryImageCacheForKey: completionBlock:");

- (void)queryImageCacheForKey:(NSString *)key completionBlock:(void(^)(UIImage *_Nullable image, ImageCacheType cacheType))completionBlock DEPRECATED_MSG_ATTRIBUTE("please use queryImageForKey: cacheType: completion:");

- (nullable NSOperation *)queryImageForKey:(nullable NSString *)key
              cacheType:(ImageCacheType)cacheType
             completion:(nullable void(^)(UIImage *_Nullable image, ImageCacheType cacheType))completionBlock;

- (void)containImageWithKey:(nullable NSString *)key
                  cacheType:(ImageCacheType)cacheType
                 completion:(nullable void(^)(BOOL contained))completionBlock;

- (void)removeImageForKey:(nullable NSString *)key
               cacheType:(ImageCacheType)cacheType
              completion:(nullable void(^)(void))completionBlock;

- (void)clearAllWithCacheType:(ImageCacheType)cacheType
                  completion:(nullable void(^)(void))completionBlock;

- (void)storeImage:(nullable UIImage *)image
         imageData:(nullable NSData *)imageData
            forKey:(nullable NSString *)key
        completion:(nullable void(^)(void))completionBlock;

- (void)storeImage1:(UIImage *_Nullable)image forKey:(NSString *)key DEPRECATED_MSG_ATTRIBUTE("please use storeImage: imageData: forKey: completion:");

- (void)storeImage2:(UIImage *_Nullable)image forKey:(NSString *)key DEPRECATED_MSG_ATTRIBUTE("please use storeImage: imageData: forKey: completion:");


@end

NS_ASSUME_NONNULL_END
