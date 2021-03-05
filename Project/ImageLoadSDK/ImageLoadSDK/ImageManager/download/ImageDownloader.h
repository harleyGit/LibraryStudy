//
//  ImageDownloader.h
//  ImageLoadSDK
//
//  Created by Harley Huang on 17/11/2020.
//
/**
 *图片内存缓存
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "ImageDownloadOperation.h"

NS_ASSUME_NONNULL_BEGIN

@interface ImageDownloadToken : NSObject

@property (nonatomic, strong, nullable) id downloadToken;

@property (nonatomic, strong, nullable) NSURL *url;

@end


@interface ImageDownloader : NSObject

+ (instancetype)shareInstance;

- (nullable ImageDownloadToken *)fetchImageWithURL:(NSString *)url
                                           options:(ImageOptions)options
                                     progressBlock:(nullable ImageDownloadProgressBlock)progressBlock
                                   completionBlock:(nullable ImageDownloadCompletionBlock)completionBlock;

- (void)cancelWithToken:(ImageDownloadToken *)token;

- (void)fetchImageWithURL1:(NSString *)url completion:(void (^)(UIImage * _Nullable, NSError * _Nullable))completionBlock DEPRECATED_MSG_ATTRIBUTE("please use fetchImageWithURL: completion:");

- (void)fetchImageWithURL2:(NSString *)url completion:(void (^)(UIImage * _Nullable, NSError * _Nullable))completionBlock DEPRECATED_MSG_ATTRIBUTE("please use fetchImageWithURL: completion:");

- (void)fetchImageWithURL3:(NSString *)url completion:(void (^)(UIImage * _Nullable, NSError * _Nullable))completionBlock DEPRECATED_MSG_ATTRIBUTE("please use fetchImageWithURL: completion:");

//获取图片




@end

NS_ASSUME_NONNULL_END
