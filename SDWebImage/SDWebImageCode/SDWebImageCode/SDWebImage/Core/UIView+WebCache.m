/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "UIView+WebCache.h"
#import "objc/runtime.h"
#import "UIView+WebCacheOperation.h"
#import "SDWebImageError.h"
#import "SDInternalMacros.h"

const int64_t SDWebImageProgressUnitCountUnknown = 1LL;

@implementation UIView (WebCache)

- (nullable NSURL *)sd_imageURL {
    return objc_getAssociatedObject(self, @selector(sd_imageURL));
}

- (void)setSd_imageURL:(NSURL * _Nullable)sd_imageURL {
    objc_setAssociatedObject(self, @selector(sd_imageURL), sd_imageURL, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (nullable NSString *)sd_latestOperationKey {
    return objc_getAssociatedObject(self, @selector(sd_latestOperationKey));
}

- (void)setSd_latestOperationKey:(NSString * _Nullable)sd_latestOperationKey {
    objc_setAssociatedObject(self, @selector(sd_latestOperationKey), sd_latestOperationKey, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSProgress *)sd_imageProgress {
    NSProgress *progress = objc_getAssociatedObject(self, @selector(sd_imageProgress));
    if (!progress) {
        progress = [[NSProgress alloc] initWithParent:nil userInfo:nil];
        self.sd_imageProgress = progress;
    }
    return progress;
}

- (void)setSd_imageProgress:(NSProgress *)sd_imageProgress {
    objc_setAssociatedObject(self, @selector(sd_imageProgress), sd_imageProgress, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)sd_internalSetImageWithURL:(nullable NSURL *)url
                  placeholderImage:(nullable UIImage *)placeholder
                           options:(SDWebImageOptions)options
                           context:(nullable SDWebImageContext *)context
                     setImageBlock:(nullable SDSetImageBlock)setImageBlock
                          progress:(nullable SDImageLoaderProgressBlock)progressBlock
                         completed:(nullable SDInternalCompletionBlock)completedBlock {
    context = [context copy]; // copy to avoid mutable object
    NSString *validOperationKey = context[SDWebImageContextSetImageOperationKey];
    if (!validOperationKey) {
        validOperationKey = NSStringFromClass([self class]);//获取类对应的字符串
    }
    self.sd_latestOperationKey = validOperationKey;
    [self sd_cancelImageLoadOperationWithKey:validOperationKey];
    self.sd_imageURL = url;
    
    //按位与 & : https://www.jianshu.com/p/1c3f65332a37
    if (!(options & SDWebImageDelayPlaceholder)) {
        dispatch_main_async_safe(^{
            [self sd_setImage:placeholder imageData:nil basedOnClassOrViaCustomSetImageBlock:setImageBlock cacheType:SDImageCacheTypeNone imageURL:url];
        });
    }
    
    if (url) {
        // reset the progress
        //NSProgress 是 Foundation 框架中的一个类，用于表示操作的进度。
        //它提供了一种标准化的方式来跟踪和报告操作的进度，使得应用程序可以更容易地显示和管理长时间运行的任务的进度信息。
        NSProgress *imageProgress = objc_getAssociatedObject(self, @selector(sd_imageProgress));
        if (imageProgress) {
            imageProgress.totalUnitCount = 0;
            imageProgress.completedUnitCount = 0;
        }
//SD_UIKIT 表示 UIKit 框架是否可用。通常，这个宏会在 iOS 或 tvOS 环境下被定义，表示正在编译一个 UIKit 相关的代码。
#if SD_UIKIT || SD_MAC //SD_MAC 表示 macOS（或 OS X）框架是否可用。这个宏会在 macOS 环境下被定义，表示正在编译一个 macOS 相关的代码。
        // check and start image indicator
        [self sd_startImageIndicator];
        id<SDWebImageIndicator> imageIndicator = self.sd_imageIndicator;
#endif
        SDWebImageManager *manager = context[SDWebImageContextCustomManager];
        if (!manager) {
            manager = [SDWebImageManager sharedManager];
        }
        
        SDImageLoaderProgressBlock combinedProgressBlock = ^(NSInteger receivedSize, NSInteger expectedSize, NSURL * _Nullable targetURL) {
            if (imageProgress) {
                imageProgress.totalUnitCount = expectedSize;
                imageProgress.completedUnitCount = receivedSize;
            }
#if SD_UIKIT || SD_MAC
            if ([imageIndicator respondsToSelector:@selector(updateIndicatorProgress:)]) {
                double progress = 0;
                if (expectedSize != 0) {
                    progress = (double)receivedSize / expectedSize;
                }
                progress = MAX(MIN(progress, 1), 0); // 0.0 - 1.0
                dispatch_async(dispatch_get_main_queue(), ^{
                    [imageIndicator updateIndicatorProgress:progress];
                });
            }
#endif
            if (progressBlock) {
                progressBlock(receivedSize, expectedSize, targetURL);
            }
        };
        @weakify(self);//https://xie.infoq.cn/article/903068956d7c2a5952059b16c
        id <SDWebImageOperation> operation = [manager loadImageWithURL:url options:options context:context progress:combinedProgressBlock completed:^(UIImage *image, NSData *data, NSError *error, SDImageCacheType cacheType, BOOL finished, NSURL *imageURL) {
            @strongify(self);
            if (!self) { return; }
            // if the progress not been updated, mark it to complete state
            if (imageProgress && finished && !error && imageProgress.totalUnitCount == 0 && imageProgress.completedUnitCount == 0) {
                imageProgress.totalUnitCount = SDWebImageProgressUnitCountUnknown;
                imageProgress.completedUnitCount = SDWebImageProgressUnitCountUnknown;
            }
            
#if SD_UIKIT || SD_MAC
            // check and stop image indicator
            if (finished) {
                [self sd_stopImageIndicator];
            }
#endif
            
            BOOL shouldCallCompletedBlock = finished || (options & SDWebImageAvoidAutoSetImage);
            BOOL shouldNotSetImage = ((image && (options & SDWebImageAvoidAutoSetImage)) ||
                                      (!image && !(options & SDWebImageDelayPlaceholder)));
            SDWebImageNoParamsBlock callCompletedBlockClojure = ^{
                if (!self) { return; }
                if (!shouldNotSetImage) {
                    [self sd_setNeedsLayout];
                }
                if (completedBlock && shouldCallCompletedBlock) {
                    completedBlock(image, data, error, cacheType, finished, url);
                }
            };
            
            // case 1a: we got an image, but the SDWebImageAvoidAutoSetImage flag is set
            // OR
            // case 1b: we got no image and the SDWebImageDelayPlaceholder is not set
            if (shouldNotSetImage) {
                dispatch_main_async_safe(callCompletedBlockClojure);
                return;
            }
            
            UIImage *targetImage = nil;
            NSData *targetData = nil;
            if (image) {
                // case 2a: we got an image and the SDWebImageAvoidAutoSetImage is not set
                targetImage = image;
                targetData = data;
            } else if (options & SDWebImageDelayPlaceholder) {
                // case 2b: we got no image and the SDWebImageDelayPlaceholder flag is set
                targetImage = placeholder;
                targetData = nil;
            }
            
#if SD_UIKIT || SD_MAC
            // check whether we should use the image transition
            SDWebImageTransition *transition = nil;
            if (finished && (options & SDWebImageForceTransition || cacheType == SDImageCacheTypeNone)) {
                transition = self.sd_imageTransition;
            }
#endif
            dispatch_main_async_safe(^{
#if SD_UIKIT || SD_MAC
                [self sd_setImage:targetImage imageData:targetData basedOnClassOrViaCustomSetImageBlock:setImageBlock transition:transition cacheType:cacheType imageURL:imageURL];
#else
                [self  sd_setImage:targetImage imageData:targetData basedOnClassOrViaCustomSetImageBlock:setImageBlock cacheType:cacheType imageURL:imageURL];
#endif
                callCompletedBlockClojure();
            });
        }];
        [self sd_setImageLoadOperation:operation forKey:validOperationKey];
    } else {
#if SD_UIKIT || SD_MAC
        [self sd_stopImageIndicator];
#endif
        dispatch_main_async_safe(^{
            if (completedBlock) {
                NSError *error = [NSError errorWithDomain:SDWebImageErrorDomain code:SDWebImageErrorInvalidURL userInfo:@{NSLocalizedDescriptionKey : @"Image url is nil"}];
                completedBlock(nil, nil, error, SDImageCacheTypeNone, YES, url);
            }
        });
    }
}

- (void)sd_cancelCurrentImageLoad {
    [self sd_cancelImageLoadOperationWithKey:self.sd_latestOperationKey];
}

- (void)sd_setImage:(UIImage *)image imageData:(NSData *)imageData basedOnClassOrViaCustomSetImageBlock:(SDSetImageBlock)setImageBlock cacheType:(SDImageCacheType)cacheType imageURL:(NSURL *)imageURL {
    //https://www.jianshu.com/p/1d2e4d822732
#if SD_UIKIT || SD_MAC
    [self sd_setImage:image imageData:imageData basedOnClassOrViaCustomSetImageBlock:setImageBlock transition:nil cacheType:cacheType imageURL:imageURL];
#else
    // watchOS does not support view transition. Simplify the logic
    if (setImageBlock) {
        setImageBlock(image, imageData, cacheType, imageURL);
    } else if ([self isKindOfClass:[UIImageView class]]) {
        UIImageView *imageView = (UIImageView *)self;
        [imageView setImage:image];
    }
#endif
}

#if SD_UIKIT || SD_MAC
- (void)sd_setImage:(UIImage *)image imageData:(NSData *)imageData basedOnClassOrViaCustomSetImageBlock:(SDSetImageBlock)setImageBlock transition:(SDWebImageTransition *)transition cacheType:(SDImageCacheType)cacheType imageURL:(NSURL *)imageURL {
    UIView *view = self;
    SDSetImageBlock finalSetImageBlock;
    if (setImageBlock) {
        finalSetImageBlock = setImageBlock;
    } else if ([view isKindOfClass:[UIImageView class]]) {
        UIImageView *imageView = (UIImageView *)view;
        finalSetImageBlock = ^(UIImage *setImage, NSData *setImageData, SDImageCacheType setCacheType, NSURL *setImageURL) {
            imageView.image = setImage;
        };
    }
#if SD_UIKIT
    else if ([view isKindOfClass:[UIButton class]]) {
        UIButton *button = (UIButton *)view;
        finalSetImageBlock = ^(UIImage *setImage, NSData *setImageData, SDImageCacheType setCacheType, NSURL *setImageURL) {
            [button setImage:setImage forState:UIControlStateNormal];
        };
    }
#endif
#if SD_MAC
    else if ([view isKindOfClass:[NSButton class]]) {
        NSButton *button = (NSButton *)view;
        finalSetImageBlock = ^(UIImage *setImage, NSData *setImageData, SDImageCacheType setCacheType, NSURL *setImageURL) {
            button.image = setImage;
        };
    }
#endif
    
    if (transition) {
#if SD_UIKIT
        //是 UIView 类中的一个类方法，用于在视图层次结构中进行过渡动画。这个方法允许你在视图层次结构中添加或移除子视图，并在这些改变发生时应用动画效果
        [UIView transitionWithView:view duration:0 options:0 animations:^{
            // 0 duration to let UIKit render placeholder and prepares block
            if (transition.prepares) {
                transition.prepares(view, image, imageData, cacheType, imageURL);
            }
        } completion:^(BOOL finished) {
            [UIView transitionWithView:view duration:transition.duration options:transition.animationOptions animations:^{
                if (finalSetImageBlock && !transition.avoidAutoSetImage) {
                    finalSetImageBlock(image, imageData, cacheType, imageURL);
                }
                if (transition.animations) {
                    transition.animations(view, image);
                }
            } completion:transition.completion];
        }];
#elif SD_MAC
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull prepareContext) {
            // 0 duration to let AppKit render placeholder and prepares block
            prepareContext.duration = 0;
            if (transition.prepares) {
                transition.prepares(view, image, imageData, cacheType, imageURL);
            }
        } completionHandler:^{
            [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
                context.duration = transition.duration;
                context.timingFunction = transition.timingFunction;
                context.allowsImplicitAnimation = SD_OPTIONS_CONTAINS(transition.animationOptions, SDWebImageAnimationOptionAllowsImplicitAnimation);
                if (finalSetImageBlock && !transition.avoidAutoSetImage) {
                    finalSetImageBlock(image, imageData, cacheType, imageURL);
                }
                if (transition.animations) {
                    transition.animations(view, image);
                }
            } completionHandler:^{
                if (transition.completion) {
                    transition.completion(YES);
                }
            }];
        }];
#endif
    } else {
        if (finalSetImageBlock) {
            finalSetImageBlock(image, imageData, cacheType, imageURL);
        }
    }
}
#endif

- (void)sd_setNeedsLayout {
#if SD_UIKIT
    [self setNeedsLayout];
#elif SD_MAC
    [self setNeedsLayout:YES];
#elif SD_WATCH
    // Do nothing because WatchKit automatically layout the view after property change
#endif
}

#if SD_UIKIT || SD_MAC

#pragma mark - Image Transition
- (SDWebImageTransition *)sd_imageTransition {
    return objc_getAssociatedObject(self, @selector(sd_imageTransition));
}

- (void)setSd_imageTransition:(SDWebImageTransition *)sd_imageTransition {
    objc_setAssociatedObject(self, @selector(sd_imageTransition), sd_imageTransition, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - Indicator
- (id<SDWebImageIndicator>)sd_imageIndicator {
    return objc_getAssociatedObject(self, @selector(sd_imageIndicator));
}

- (void)setSd_imageIndicator:(id<SDWebImageIndicator>)sd_imageIndicator {
    // Remove the old indicator view
    id<SDWebImageIndicator> previousIndicator = self.sd_imageIndicator;
    [previousIndicator.indicatorView removeFromSuperview];
    
    objc_setAssociatedObject(self, @selector(sd_imageIndicator), sd_imageIndicator, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // Add the new indicator view
    UIView *view = sd_imageIndicator.indicatorView;
    if (CGRectEqualToRect(view.frame, CGRectZero)) {
        view.frame = self.bounds;
    }
    // Center the indicator view
#if SD_MAC
    [view setFrameOrigin:CGPointMake(round((NSWidth(self.bounds) - NSWidth(view.frame)) / 2), round((NSHeight(self.bounds) - NSHeight(view.frame)) / 2))];
#else
    view.center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
#endif
    view.hidden = NO;
    [self addSubview:view];
}

- (void)sd_startImageIndicator {
    id<SDWebImageIndicator> imageIndicator = self.sd_imageIndicator;
    if (!imageIndicator) {
        return;
    }
    dispatch_main_async_safe(^{
        [imageIndicator startAnimatingIndicator];
    });
}

- (void)sd_stopImageIndicator {
    id<SDWebImageIndicator> imageIndicator = self.sd_imageIndicator;
    if (!imageIndicator) {
        return;
    }
    dispatch_main_async_safe(^{
        [imageIndicator stopAnimatingIndicator];
    });
}

#endif

@end
