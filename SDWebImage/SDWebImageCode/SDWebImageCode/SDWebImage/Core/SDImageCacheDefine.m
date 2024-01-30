/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "SDImageCacheDefine.h"
#import "SDImageCodersManager.h"
#import "SDImageCoderHelper.h"
#import "SDAnimatedImage.h"
#import "UIImage+Metadata.h"
#import "SDInternalMacros.h"

//解码：https://zhang759740844.github.io/2018/03/07/sdwebimage4/
UIImage * _Nullable SDImageCacheDecodeImageData(NSData * _Nonnull imageData, NSString * _Nonnull cacheKey, SDWebImageOptions options, SDWebImageContext * _Nullable context) {
    UIImage *image;
    /// 判断是否只要解码第一帧
    BOOL decodeFirstFrame = SD_OPTIONS_CONTAINS(options, SDWebImageDecodeFirstFrameOnly);
    NSNumber *scaleValue = context[SDWebImageContextImageScaleFactor];
    /// 获取解码的 scale(屏幕缩放因子)
    CGFloat scale = scaleValue.doubleValue >= 1 ? scaleValue.doubleValue : SDImageScaleFactorForKey(cacheKey);
    //SDWebImageContextImagePreserveAspectRatio:用于加载图像时保持纵横比（宽高比）的选项。它用于确保图像在显示时不会被拉伸，而是保持原始的纵横比，适应显示区域
    NSNumber *preserveAspectRatioValue = context[SDWebImageContextImagePreserveAspectRatio];
    NSValue *thumbnailSizeValue;
    BOOL shouldScaleDown = SD_OPTIONS_CONTAINS(options, SDWebImageScaleDownLargeImages);
    if (shouldScaleDown) {//是否应该缩小
        //计算缩略图的像素数,
        //这主要涉及到图像的压缩和处理，通常在加载大型图像时用于生成更小的预览图或缩略图，以提高性能和减少内存占用
        //  SDImageCoderHelper.defaultScaleDownLimitBytes：这是 SDWebImage 框架中的一个默认值，表示图像处理器在尝试生成缩略图时的字节限制。
        //  这个值用于控制图像的大小，以确保生成的缩略图不会太大。
        CGFloat thumbnailPixels = SDImageCoderHelper.defaultScaleDownLimitBytes / 4;
        
        //sqrt 平方根,ceil 返回浮点数整数部分（舍弃小数点部分，往个位数进1）
        //计算出一个近似的正方形缩略图的边长（dimension）。这是通过对缩略图像素数开方，然后向上取整得到的。
        CGFloat dimension = ceil(sqrt(thumbnailPixels));
        thumbnailSizeValue = @(CGSizeMake(dimension, dimension));
    }
    if (context[SDWebImageContextImageThumbnailPixelSize]) {
        thumbnailSizeValue = context[SDWebImageContextImageThumbnailPixelSize];
    }
    
    SDImageCoderMutableOptions *mutableCoderOptions = [NSMutableDictionary dictionaryWithCapacity:2];
    mutableCoderOptions[SDImageCoderDecodeFirstFrameOnly] = @(decodeFirstFrame);
    mutableCoderOptions[SDImageCoderDecodeScaleFactor] = @(scale);
    mutableCoderOptions[SDImageCoderDecodePreserveAspectRatio] = preserveAspectRatioValue;
    mutableCoderOptions[SDImageCoderDecodeThumbnailPixelSize] = thumbnailSizeValue;
    mutableCoderOptions[SDImageCoderWebImageContext] = context;
    SDImageCoderOptions *coderOptions = [mutableCoderOptions copy];
    
    // Grab the image coder
    id<SDImageCoder> imageCoder;
    if ([context[SDWebImageContextImageCoder] conformsToProtocol:@protocol(SDImageCoder)]) {
        imageCoder = context[SDWebImageContextImageCoder];
    } else {
        imageCoder = [SDImageCodersManager sharedManager];
    }
    
    /// 如果不仅仅解码第一帧，则从 context 中取出 AnimatedImageClass，默认使用的是 SDAnimatedImage，然后进行图片数据的解码，根据需要还可以预解码所有帧
    if (!decodeFirstFrame) {
        Class animatedImageClass = context[SDWebImageContextAnimatedImageClass];
        // check whether we should use `SDAnimatedImage`
        if ([animatedImageClass isSubclassOfClass:[UIImage class]] && [animatedImageClass conformsToProtocol:@protocol(SDAnimatedImage)]) {
            image = [[animatedImageClass alloc] initWithData:imageData scale:scale options:coderOptions];
            if (image) {
                // Preload frames if supported
                if (options & SDWebImagePreloadAllFrames && [image respondsToSelector:@selector(preloadAllFrames)]) {
                    [((id<SDAnimatedImage>)image) preloadAllFrames];
                }
            } else {
                // Check image class matching
                if (options & SDWebImageMatchAnimatedImageClass) {
                    return nil;
                }
            }
        }
    }
    if (!image) {
        /// 从 data 转为 image, imageCoder是什么类型?? 这个imageData是怎么来的?? 是从.png解压前还是之后的数据
        image = [imageCoder decodedImageWithData:imageData options:coderOptions];
    }
    if (image) {
        /// 查看是否需要解码
        BOOL shouldDecode = !SD_OPTIONS_CONTAINS(options, SDWebImageAvoidDecodeImage);
        if ([image.class conformsToProtocol:@protocol(SDAnimatedImage)]) {
            // `SDAnimatedImage` do not decode
            /// 动图不需要解码
            shouldDecode = NO;
        } else if (image.sd_isAnimated) {
            // animated image do not decode
            shouldDecode = NO;
        }
        /// 需要解码就开始解码，把 image 加载到内存中
        if (shouldDecode) {
            image = [SDImageCoderHelper decodedImageWithImage:image];
        }
    }
    
    return image;
}
