//
//  UIView+Image.m
//  ImageLoadSDK
//
//  Created by Harley Huang on 28/11/2020.
//

#import "UIView+Image.h"
#import "UIImage+ImageFormat.h"
#import "UIView+ImageOperation.h"
#import "UIImage+ImageGIF.h"
#import "Image.h"

@implementation UIView (Image)


- (void)setImageWithURL:(NSString *)url options:(ImageOptions)options progressBlock:(ImageProgressBlock)progressBlock transformBlock:(ImageTransformBlock)transformBlock completionBlock:(ImageCompletionBlock)completionBlock {
    [self setImageWithURL:url options:options placeHolder:[UIImage new] progressBlock:progressBlock transformBlock:transformBlock completionBlock:completionBlock];
}

- (void)setImageWithURL:(NSString *)url options:(ImageOptions)options placeHolder:(UIImage *)placeHolder progressBlock:(ImageProgressBlock)progressBlock transformBlock:(ImageTransformBlock)transformBlock completionBlock:(ImageCompletionBlock)completionBlock {
    safe_dispatch_main_async(^{
        [self internalSetImage:placeHolder];
    });
    __weak typeof(self) weakSelf = self;
    id<ImageOperation> operation = [[ImageManager shareManager] loadImageWithUrl:url options:options progress:progressBlock transform:transformBlock completion:^(UIImage * _Nullable image, NSError * _Nullable error, BOOL finished) {
        if (error) {
            NSLog(@"Image Error:set image fail with url:%@, error:%@", url ? : @"", error.description ? : @"unknown");
        } else if (image) {
            if (!(options & ImageOptionAvoidAutoSetImage)) {
                [weakSelf internalSetImage:image];
            }
        } else {
            if (finished) {
                NSLog(@"Image Error:image is nil");
            }
        }
        completionBlock(image, error, finished);
    }];
    [self setOperation:operation forKey:NSStringFromClass([self class])];
}


- (void)setImageWithURL:(NSString *)url {
    [self setImageWithURL:url options:0];
}

- (void)setImageWithURL:(NSString *)url options:(ImageOptions)options {
    [self setImageWithURL:url options:options placeHolder:nil];
}

- (void)setImageWithURL:(NSString *)url options:(ImageOptions)options placeHolder:(UIImage *)placeHolder {
    safe_dispatch_main_async(^{
        [self internalSetImage:placeHolder];
    });
    
    __weak typeof(self) weakSelf = self;
    id<ImageOperation> operation = [[ImageManager shareManager] loadImageWithUrl:url options:options progress:nil transform:nil completion:^(UIImage * _Nullable image, NSError * _Nullable error, BOOL finished) {
        if (error) {
            NSLog(@"Image Error:set image fail with url:%@, error:%@", url ? : @"" , error.description ? : @"");
        } else if (image) {
            [weakSelf internalSetImage:image];
        } else {
            if (finished) {
                NSLog(@"JImage Error:image is nil");
            }
        }
    }];
    [self setOperation:operation forKey:NSStringFromClass([self class])];
}

- (void)internalSetImage:(UIImage *)image {
    if (!image) {
        return;
    }
    if ([self isKindOfClass:[UIImageView class]]) {
        UIImageView *imageView = (UIImageView *)self;
        if (image.imageFormat == ImageFormatGIF) {
            imageView.animationImages = image.images;
            imageView.animationDuration = image.totalTimes;
            imageView.animationRepeatCount = image.loopCount;
            [imageView startAnimating];
        } else {
            imageView.image = image;
        }
    } else if ([self isKindOfClass:[UIButton class]]) {
        UIButton *button = (UIButton *)self;
        [button setImage:image forState:UIControlStateNormal];
    }
}

- (void)cancelLoadImage {
    [self cancelOperationForKey:NSStringFromClass([self class])];
}


@end
