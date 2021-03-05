//
//  ImageCoder.h
//  ImageLoadSDK
//
//  Created by Harley Huang on 18/11/2020.
//
/**
 * 图片解析
 */


#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ImageCoder : NSObject


+ (instancetype)shareCoder;

- (UIImage *)decodeImageWithData:(NSData *)data DEPRECATED_MSG_ATTRIBUTE("please use decodeImageSyncWithData:");

- (nullable UIImage *)decodeImageSyncWithData:(nullable NSData *)data;

- (nullable NSData *)encodedDataSyncWithImage:(nullable UIImage *)image;

- (void)decodeImageWithData:(NSData *)data WithBlock:(void(^)(UIImage *_Nullable image))completionBlock;

- (void)encodedDataWithImage:(UIImage *)image WithBlock:(void(^)(NSData *_Nullable data))completionBlock;


@end

NS_ASSUME_NONNULL_END
