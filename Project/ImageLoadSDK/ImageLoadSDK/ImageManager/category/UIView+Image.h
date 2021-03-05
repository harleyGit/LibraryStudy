//
//  UIView+Image.h
//  ImageLoadSDK
//
//  Created by Harley Huang on 28/11/2020.
//

#import <UIKit/UIKit.h>
//在其文件夹的外面，但是在同一个父文件下固用 "" 号
#import "ImageManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface UIView (Image)


- (void)setImageWithURL:(nullable NSString *)url
                options:(ImageOptions)options
          progressBlock:(nullable ImageProgressBlock)progressBlock
         transformBlock:(nullable ImageTransformBlock)transformBlock
        completionBlock:(nullable ImageCompletionBlock)completionBlock;

- (void)setImageWithURL:(nullable NSString *)url
                options:(ImageOptions)options
            placeHolder:(nullable UIImage *)placeHolder
          progressBlock:(nullable ImageProgressBlock)progressBlock
         transformBlock:(nullable ImageTransformBlock)transformBlock
        completionBlock:(nullable ImageCompletionBlock)completionBlock;

- (void)setImageWithURL:(NSString *)url;

- (void)setImageWithURL:(nullable NSString *)url options:(ImageOptions)options;

- (void)setImageWithURL:(nullable NSString *)url options:(ImageOptions)options placeHolder:(nullable UIImage *)placeHolder;

- (void)cancelLoadImage;

@end

NS_ASSUME_NONNULL_END
