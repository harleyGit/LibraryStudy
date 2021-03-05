//
//  ImageManager.m
//  ImageLoadSDK
//
//  Created by Harley Huang on 26/11/2020.
//

#import "ImageManager.h"
#import "download/UIView+ImageOperation.h"
#import "download/ImageDownloader.h"
#import "ImageCache.h"
#import "Image.h"
#import "cache/DiskCacheDelegate.h"
#import "cache/ImageCacheConfig.h"
#import "cache/ImageCache.h"
#import "ImageCoder.h"


#define SAFE_CALL_BLOCK(blockFunc, ...)    \
    if (blockFunc) {                        \
        blockFunc(__VA_ARGS__);              \
    }



#pragma mark -- ImageCombineOperation

@interface ImageCombineOperation : NSObject <ImageOperation>

@property (nonatomic, strong) NSOperation *cacheOperation;

@property (nonatomic, strong) ImageDownloadToken* downloadToken;

@property (nonatomic, copy) NSString *url;

@end


@implementation ImageCombineOperation

- (void)cancelOperation {
    NSLog(@"cancel operation for url:%@", self.url ? : @"");
    if (self.cacheOperation) {
        //取消当前缓存的operation
        [self.cacheOperation cancel];
    }
    if (self.downloadToken) {
        [[ImageDownloader shareInstance] cancelWithToken:self.downloadToken];
    }
}

@end




#pragma mark -- ImageManager

@interface ImageManager ()

@property (nonatomic, strong) ImageCache *imageCache;

@end

@implementation ImageManager

+ (instancetype)shareManager {
    static dispatch_once_t onceToken;
    static ImageManager *instance;
    dispatch_once(&onceToken, ^{
        instance = [[ImageManager alloc] init];
        [instance setup];
    });
    return instance;
}

- (void)setup {
    self.imageCache = [[ImageCache alloc] init];
}

- (id<ImageOperation>)loadImageWithUrl:(NSString *)url options:(ImageOptions)options progress:(ImageProgressBlock)progressBlock transform:(ImageTransformBlock)transformBlock completion:(ImageCompletionBlock)completionBlock {
    
    __block ImageCombineOperation *combineOperation = [ImageCombineOperation new];
    combineOperation.url = url;
    
    if (options & ImageOptionIgnoreCache) {//忽略缓存，自动从网络进行下载
        combineOperation.downloadToken = [self fetchImageWithUrl:url options:options progressBlock:progressBlock transformBlock:transformBlock completionBlock:completionBlock];
    } else {
        //从缓存或者磁盘是否能查到图片
        combineOperation.cacheOperation =  [self.imageCache queryImageForKey:url cacheType:ImageCacheTypeAll completion:^(UIImage * _Nullable image, ImageCacheType cacheType) {
            if (image) {//从缓存或者磁盘能查到图片
                safe_dispatch_main_async(^{
                    SAFE_CALL_BLOCK(completionBlock, image, nil, YES);
                });
                NSLog(@"fetch image from %@", (cacheType == ImageCacheTypeMemory) ? @"memory" : @"disk");
            } else {//从缓存或者磁盘不能查到图片，开始下载
                combineOperation.downloadToken = [self fetchImageWithUrl:url options:options progressBlock:progressBlock transformBlock:transformBlock completionBlock:completionBlock];
            }
        }];
    }
    return combineOperation;
}


- (ImageDownloadToken *)fetchImageWithUrl:(NSString *)url options:(ImageOptions)options progressBlock:(ImageProgressBlock)progressBlock transformBlock:(ImageTransformBlock)transformBlock completionBlock:(ImageCompletionBlock)completionBlock {
    __weak typeof(self) weakSelf = self;
    ImageDownloadToken *downloadToken = [[ImageDownloader shareInstance] fetchImageWithURL:url options:options progressBlock:^(NSInteger receivedSize, NSInteger expectedSize, NSURL * _Nullable targetURL) {
        safe_dispatch_main_async(^{
            SAFE_CALL_BLOCK(progressBlock, receivedSize, expectedSize, targetURL);
        });
    } completionBlock:^(UIImage *_Nullable image, NSData * _Nullable imageData, NSError * _Nullable error, BOOL finished) {
        if (!finished) {
            safe_dispatch_main_async(^{
                SAFE_CALL_BLOCK(completionBlock, image, error, NO);
            });
        } else {
            if (!imageData || error) {
                safe_dispatch_main_async(^{
                    SAFE_CALL_BLOCK(completionBlock, nil, error, YES);
                });
                return;
            }
            [[ImageCoder shareCoder] decodeImageWithData:imageData WithBlock:^(UIImage * _Nullable image) {
                __strong typeof(weakSelf) strongSelf = weakSelf;
                UIImage *transformImage = image;
                NSData *cacheData = imageData;
                if (transformBlock) {
                    transformImage = transformBlock(image, url);
                    BOOL imageWasTransformed = ![transformImage isEqual:image];
                    cacheData = imageWasTransformed ? nil : imageData;
                }
                [strongSelf.imageCache storeImage:transformImage imageData:cacheData forKey:url completion:nil];
                safe_dispatch_main_async(^{
                    NSLog(@">>>>>> %@", transformImage);
                    SAFE_CALL_BLOCK(completionBlock, transformImage, nil, YES);
                });
            }];
        }
    }];
    return downloadToken;
}

- (void)clearDiskCache {
    [self.imageCache clearAllWithCacheType:ImageCacheTypeDisk completion:nil];
}

- (void)clearMemoryCache {
    [self.imageCache clearAllWithCacheType:ImageCacheTypeMemory completion:nil];
}

#pragma mark - setter
- (void)setCacheConfig:(ImageCacheConfig *)cacheConfig {
    self.imageCache.cacheConfig = cacheConfig;
}

- (void)setMemoryCache:(NSCache *)memoryCache {
    self.imageCache.memoryCache = memoryCache;
}

- (void)setDiskCache:(id<DiskCacheDelegate>)diskCache {
    self.imageCache.diskCache = diskCache;
}


@end
