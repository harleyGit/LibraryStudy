//
//  ImageManager.h
//  ImageLoadSDK
//
//  Created by Harley Huang on 26/11/2020.
//
/**
 *图片管理
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "UIView+ImageOperation.h"
#import "ImageCacheConfig.h"
#import "DiskCacheDelegate.h"

NS_ASSUME_NONNULL_BEGIN

typedef void(^ImageProgressBlock)(NSInteger receivedSize, NSInteger expectedSize, NSURL *_Nullable targetURL);
typedef void(^ImageCompletionBlock)(UIImage * _Nullable image, NSError * _Nullable error, BOOL finished);
typedef UIImage *_Nullable(^ImageTransformBlock)(UIImage *image, NSString *_Nullable url);

typedef NS_ENUM(NSUInteger, ImageOptions) {
    ImageOptionProgressive = 1 << 0,
    ImageOptionIgnoreCache = 1 << 1,
    ImageOptionAvoidAutoSetImage = 1 << 2,
};

@interface ImageManager : NSObject

+ (instancetype)shareManager;

- (id<ImageOperation>)loadImageWithUrl:(NSString *)url
                               options:(ImageOptions)options
                              progress:(nullable ImageProgressBlock)progressBlock
                             transform:(nullable ImageTransformBlock)transformBlock
                            completion:(nullable ImageCompletionBlock)completionBlock;

- (void)setCacheConfig:(ImageCacheConfig *)cacheConfig;

- (void)setMemoryCache:(NSCache *)memoryCache;

- (void)setDiskCache:(id<DiskCacheDelegate>)diskCache;


- (void)clearMemoryCache;

- (void)clearDiskCache;

@end

NS_ASSUME_NONNULL_END
