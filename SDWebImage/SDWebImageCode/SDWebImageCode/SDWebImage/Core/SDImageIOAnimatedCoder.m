/*
* This file is part of the SDWebImage package.
* (c) Olivier Poitrey <rs@dailymotion.com>
*
* For the full copyright and license information, please view the LICENSE
* file that was distributed with this source code.
*/

#import "SDImageIOAnimatedCoder.h"
#import "NSImage+Compatibility.h"
#import "UIImage+Metadata.h"
#import "NSData+ImageContentType.h"
#import "SDImageCoderHelper.h"
#import "SDAnimatedImageRep.h"
#import "UIImage+ForceDecode.h"

// Specify DPI for vector format in CGImageSource, like PDF
static NSString * kSDCGImageSourceRasterizationDPI = @"kCGImageSourceRasterizationDPI";
// Specify File Size for lossy format encoding, like JPEG
static NSString * kSDCGImageDestinationRequestedFileSize = @"kCGImageDestinationRequestedFileSize";

@interface SDImageIOCoderFrame : NSObject

@property (nonatomic, assign) NSUInteger index; // Frame index (zero based)
@property (nonatomic, assign) NSTimeInterval duration; // Frame duration in seconds

@end

@implementation SDImageIOCoderFrame
@end

@implementation SDImageIOAnimatedCoder {
    size_t _width, _height;
    CGImageSourceRef _imageSource;
    NSData *_imageData;
    CGFloat _scale;
    NSUInteger _loopCount;
    NSUInteger _frameCount;
    NSArray<SDImageIOCoderFrame *> *_frames;
    BOOL _finished;
    BOOL _preserveAspectRatio;
    CGSize _thumbnailSize;
}

- (void)dealloc
{
    if (_imageSource) {
        CFRelease(_imageSource);
        _imageSource = NULL;
    }
#if SD_UIKIT
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
#endif
}

- (void)didReceiveMemoryWarning:(NSNotification *)notification
{
    if (_imageSource) {
        for (size_t i = 0; i < _frameCount; i++) {
            CGImageSourceRemoveCacheAtIndex(_imageSource, i);
        }
    }
}

#pragma mark - Subclass Override

+ (SDImageFormat)imageFormat {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"For `SDImageIOAnimatedCoder` subclass, you must override %@ method", NSStringFromSelector(_cmd)]
                                 userInfo:nil];
}

+ (NSString *)imageUTType {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"For `SDImageIOAnimatedCoder` subclass, you must override %@ method", NSStringFromSelector(_cmd)]
                                 userInfo:nil];
}

+ (NSString *)dictionaryProperty {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"For `SDImageIOAnimatedCoder` subclass, you must override %@ method", NSStringFromSelector(_cmd)]
                                 userInfo:nil];
}

+ (NSString *)unclampedDelayTimeProperty {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"For `SDImageIOAnimatedCoder` subclass, you must override %@ method", NSStringFromSelector(_cmd)]
                                 userInfo:nil];
}

+ (NSString *)delayTimeProperty {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"For `SDImageIOAnimatedCoder` subclass, you must override %@ method", NSStringFromSelector(_cmd)]
                                 userInfo:nil];
}

+ (NSString *)loopCountProperty {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"For `SDImageIOAnimatedCoder` subclass, you must override %@ method", NSStringFromSelector(_cmd)]
                                 userInfo:nil];
}

+ (NSUInteger)defaultLoopCount {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"For `SDImageIOAnimatedCoder` subclass, you must override %@ method", NSStringFromSelector(_cmd)]
                                 userInfo:nil];
}

#pragma mark - Utils

/// 返回图片循环次数
/// @param source 图片源
+ (NSUInteger)imageLoopCountWithSource:(CGImageSourceRef)source {
    NSUInteger loopCount = self.defaultLoopCount;
    
    ///CGImageSourceCopyProperties 获取图片原信息,其返回一个字典,字典包含图片、相机等信息: https://developer.aliyun.com/article/800011
    //CGImageSourceCopyProperties 函数是 Core Graphics 框架中用于获取图像属性的函数。具体来说，它返回一个包含图像属性的不可变字典（CFDictionary），该字典包含有关图像的各种信息，例如尺寸、颜色空间、方向、压缩格式等
    NSDictionary *imageProperties = (__bridge_transfer NSDictionary *)CGImageSourceCopyProperties(source, nil);
    
    //self.dictionaryProperty 是什么?
    NSDictionary *containerProperties = imageProperties[self.dictionaryProperty];
    if (containerProperties) {
        NSNumber *containerLoopCount = containerProperties[self.loopCountProperty];
        if (containerLoopCount != nil) {
            loopCount = containerLoopCount.unsignedIntegerValue;
        }
    }
    return loopCount;
}

+ (NSTimeInterval)frameDurationAtIndex:(NSUInteger)index source:(CGImageSourceRef)source {
    NSDictionary *options = @{
        (__bridge NSString *)kCGImageSourceShouldCacheImmediately : @(YES),
        (__bridge NSString *)kCGImageSourceShouldCache : @(YES) // Always cache to reduce CPU usage
    };
    NSTimeInterval frameDuration = 0.1;
    CFDictionaryRef cfFrameProperties = CGImageSourceCopyPropertiesAtIndex(source, index, (__bridge CFDictionaryRef)options);
    if (!cfFrameProperties) {
        return frameDuration;
    }
    NSDictionary *frameProperties = (__bridge NSDictionary *)cfFrameProperties;
    NSDictionary *containerProperties = frameProperties[self.dictionaryProperty];
    
    NSNumber *delayTimeUnclampedProp = containerProperties[self.unclampedDelayTimeProperty];
    if (delayTimeUnclampedProp != nil) {
        frameDuration = [delayTimeUnclampedProp doubleValue];
    } else {
        NSNumber *delayTimeProp = containerProperties[self.delayTimeProperty];
        if (delayTimeProp != nil) {
            frameDuration = [delayTimeProp doubleValue];
        }
    }
    
    // Many annoying ads specify a 0 duration to make an image flash as quickly as possible.
    // We follow Firefox's behavior and use a duration of 100 ms for any frames that specify
    // a duration of <= 10 ms. See <rdar://problem/7689300> and <http://webkit.org/b/36082>
    // for more information.
    
    if (frameDuration < 0.011) {
        frameDuration = 0.1;
    }
    
    CFRelease(cfFrameProperties);
    return frameDuration;
}

//创建一个指定索引的图像帧，并可选地对其进行缩放和裁剪，同时保持纵横比
+ (UIImage *)createFrameAtIndex:(NSUInteger)index source:(CGImageSourceRef)source scale:(CGFloat)scale preserveAspectRatio:(BOOL)preserveAspectRatio thumbnailSize:(CGSize)thumbnailSize options:(NSDictionary *)options {
    // Some options need to pass to `CGImageSourceCopyPropertiesAtIndex` before `CGImageSourceCreateImageAtIndex`, or ImageIO will ignore them because they parse once :)
    // Parse the image properties
    //用于获取指定索引处图像源中图像帧的属性信息。这个函数通常用于获取图像的一些基本信息，例如宽度、高度、颜色空间等
    NSDictionary *properties = (__bridge_transfer NSDictionary *)CGImageSourceCopyPropertiesAtIndex(source, index, (__bridge CFDictionaryRef)options);
    
    //// 在这里使用 properties 中的属性信息，例如获取图像的宽度和高度
    NSUInteger pixelWidth = [properties[(__bridge NSString *)kCGImagePropertyPixelWidth] unsignedIntegerValue];
    NSUInteger pixelHeight = [properties[(__bridge NSString *)kCGImagePropertyPixelHeight] unsignedIntegerValue];
    
    CGImagePropertyOrientation exifOrientation = (CGImagePropertyOrientation)[properties[(__bridge NSString *)kCGImagePropertyOrientation] unsignedIntegerValue];
    if (!exifOrientation) {
        exifOrientation = kCGImagePropertyOrientationUp;
    }
    //图片类型:https://www.jianshu.com/p/0b52298bb2db
    CFStringRef uttype = CGImageSourceGetType(source);
    // Check vector format
    BOOL isVector = NO;
    //sd_imageFormatFromUTType 返回图片类型
    if ([NSData sd_imageFormatFromUTType:uttype] == SDImageFormatPDF) {
        isVector = YES;
    }

    NSMutableDictionary *decodingOptions;
    if (options) {
        decodingOptions = [NSMutableDictionary dictionaryWithDictionary:options];
    } else {
        decodingOptions = [NSMutableDictionary dictionary];
    }
    CGImageRef imageRef;
    if (thumbnailSize.width == 0 || thumbnailSize.height == 0 || pixelWidth == 0 || pixelHeight == 0 || (pixelWidth <= thumbnailSize.width && pixelHeight <= thumbnailSize.height)) {
        if (isVector) {
            if (thumbnailSize.width == 0 || thumbnailSize.height == 0) {
                // Provide the default pixel count for vector images, simply just use the screen size
#if SD_WATCH
                thumbnailSize = WKInterfaceDevice.currentDevice.screenBounds.size;
#elif SD_UIKIT
                thumbnailSize = UIScreen.mainScreen.bounds.size;
#elif SD_MAC
                thumbnailSize = NSScreen.mainScreen.frame.size;
#endif
            }
            CGFloat maxPixelSize = MAX(thumbnailSize.width, thumbnailSize.height);
            NSUInteger DPIPerPixel = 2;
            NSUInteger rasterizationDPI = maxPixelSize * DPIPerPixel;
            decodingOptions[kSDCGImageSourceRasterizationDPI] = @(rasterizationDPI);
        }
        //创建一个未解码的 CGImage
        //只能返回索引值的图片，丢失了其他的图片信息。因此，我们只获取到了其中的一帧图片 https://www.jianshu.com/p/5c870860c187
        //CGImageSourceCreateImageAtIndex用于在给定的图像源 (CGImageSourceRef) 中获取指定索引处的图像帧并创建 CGImageRef 对象。
        //该函数通常用于解码图像帧，以便在应用程序中进行显示或进一步处理
        imageRef = CGImageSourceCreateImageAtIndex(source, index, (__bridge CFDictionaryRef)decodingOptions);
    } else {
        //kCGImageSourceCreateThumbnailWithTransform 是 Core Graphics 框架中用于创建缩略图的选项键
        decodingOptions[(__bridge NSString *)kCGImageSourceCreateThumbnailWithTransform] = @(preserveAspectRatio);
        CGFloat maxPixelSize;
        if (preserveAspectRatio) {
            CGFloat pixelRatio = pixelWidth / pixelHeight;
            CGFloat thumbnailRatio = thumbnailSize.width / thumbnailSize.height;
            if (pixelRatio > thumbnailRatio) {
                maxPixelSize = thumbnailSize.width;
            } else {
                maxPixelSize = thumbnailSize.height;
            }
        } else {
            maxPixelSize = MAX(thumbnailSize.width, thumbnailSize.height);
        }
        
        //使用 kCGImageSourceThumbnailMaxPixelSize 选项键的主要目的是控制生成的缩略图的尺寸，限制其在宽度和高度上的最大像素数。
        decodingOptions[(__bridge NSString *)kCGImageSourceThumbnailMaxPixelSize] = @(maxPixelSize);
        
        //kCGImageSourceCreateThumbnailFromImageIfAbsent 是一个常量字符串，表示在创建缩略图时是否尝试从原始图像创建缩略图
        decodingOptions[(__bridge NSString *)kCGImageSourceCreateThumbnailFromImageIfAbsent] = @(YES);
        
        //CGImageSourceCreateThumbnailAtIndex 是 Core Graphics 框架中的一个函数，用于在给定的图像源 (CGImageSourceRef) 中获取指定索引处的图像帧并创建缩略图 (CGImageRef)。
        //这个函数通常用于生成缩略图，以减小内存占用或加快加载速度。
        imageRef = CGImageSourceCreateThumbnailAtIndex(source, index, (__bridge CFDictionaryRef)decodingOptions);
    }
    if (!imageRef) {
        return nil;
    }
    
    if (thumbnailSize.width > 0 && thumbnailSize.height > 0) {
        if (preserveAspectRatio) {
            // kCGImageSourceCreateThumbnailWithTransform will apply EXIF transform as well, we should not apply twice
            exifOrientation = kCGImagePropertyOrientationUp;
        } else {
            // `CGImageSourceCreateThumbnailAtIndex` take only pixel dimension, if not `preserveAspectRatio`, we should manual scale to the target size
            //生成对应尺寸的图片数据对象
            CGImageRef scaledImageRef = [SDImageCoderHelper CGImageCreateScaled:imageRef size:thumbnailSize];
            CGImageRelease(imageRef);
            imageRef = scaledImageRef;
        }
    }
    
#if SD_UIKIT || SD_WATCH
    UIImageOrientation imageOrientation = [SDImageCoderHelper imageOrientationFromEXIFOrientation:exifOrientation];
    
    //imageRef实例对象是CGImageRef 类型的，它包含了图像的像素数据、颜色空间等信息。
    UIImage *image = [[UIImage alloc] initWithCGImage:imageRef scale:scale orientation:imageOrientation];
#else
    UIImage *image = [[UIImage alloc] initWithCGImage:imageRef scale:scale orientation:exifOrientation];
#endif
    CGImageRelease(imageRef);
    return image;
}

#pragma mark - Decode
- (BOOL)canDecodeFromData:(nullable NSData *)data {
    return ([NSData sd_imageFormatForImageData:data] == self.class.imageFormat);
}


/// 解码图片二进制压缩数据生成图片
/// @param data 压缩图片二进制数据
/// @param options 可选配置
- (UIImage *)decodedImageWithData:(NSData *)data options:(nullable SDImageCoderOptions *)options {
    if (!data) {
        return nil;
    }
    CGFloat scale = 1;
    NSNumber *scaleFactor = options[SDImageCoderDecodeScaleFactor];
    if (scaleFactor != nil) {
        scale = MAX([scaleFactor doubleValue], 1);
    }
    
    CGSize thumbnailSize = CGSizeZero;
    NSValue *thumbnailSizeValue = options[SDImageCoderDecodeThumbnailPixelSize];
    if (thumbnailSizeValue != nil) {
#if SD_MAC
        thumbnailSize = thumbnailSizeValue.sizeValue;
#else
        thumbnailSize = thumbnailSizeValue.CGSizeValue;
#endif
    }
    
    //保持纵横比
    BOOL preserveAspectRatio = YES;
    NSNumber *preserveAspectRatioValue = options[SDImageCoderDecodePreserveAspectRatio];
    if (preserveAspectRatioValue != nil) {
        preserveAspectRatio = preserveAspectRatioValue.boolValue;
    }
    
#if SD_MAC
    // If don't use thumbnail, prefers the built-in generation of frames (GIF/APNG)
    // Which decode frames in time and reduce memory usage
    if (thumbnailSize.width == 0 || thumbnailSize.height == 0) {
        SDAnimatedImageRep *imageRep = [[SDAnimatedImageRep alloc] initWithData:data];
        NSSize size = NSMakeSize(imageRep.pixelsWide / scale, imageRep.pixelsHigh / scale);
        imageRep.size = size;
        NSImage *animatedImage = [[NSImage alloc] initWithSize:size];
        [animatedImage addRepresentation:imageRep];
        return animatedImage;
    }
#endif
    
    //用于创建一个图像源对象 (CGImageSourceRef)，该对象可以用于读取图像数据。
    //这个函数通常用于在不将整个图像加载到内存中的情况下获取图像的信息或进行部分图像的解码
    //如获取图像的:宽度、高度、帧数等
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    if (!source) {
        return nil;
    }
    //用于获取图像源中包含的图像帧
    size_t count = CGImageSourceGetCount(source);
    UIImage *animatedImage;
    
    BOOL decodeFirstFrame = [options[SDImageCoderDecodeFirstFrameOnly] boolValue];
    if (decodeFirstFrame || count <= 1) {
        //根据图像源信息、比例、尺寸获取图片
        animatedImage = [self.class createFrameAtIndex:0 source:source scale:scale preserveAspectRatio:preserveAspectRatio thumbnailSize:thumbnailSize options:nil];
    } else {
        NSMutableArray<SDImageFrame *> *frames = [NSMutableArray array];
        
        for (size_t i = 0; i < count; i++) {
            UIImage *image = [self.class createFrameAtIndex:i source:source scale:scale preserveAspectRatio:preserveAspectRatio thumbnailSize:thumbnailSize options:nil];
            if (!image) {
                continue;
            }
            
            NSTimeInterval duration = [self.class frameDurationAtIndex:i source:source];
            
            SDImageFrame *frame = [SDImageFrame frameWithImage:image duration:duration];
            [frames addObject:frame];
        }
        
        NSUInteger loopCount = [self.class imageLoopCountWithSource:source];
        
        //根据帧数生成一个动画图片
        animatedImage = [SDImageCoderHelper animatedImageWithFrames:frames];
        animatedImage.sd_imageLoopCount = loopCount;
    }
    animatedImage.sd_imageFormat = self.class.imageFormat;
    CFRelease(source);
    
    return animatedImage;
}

#pragma mark - Progressive Decode

- (BOOL)canIncrementalDecodeFromData:(NSData *)data {
    return ([NSData sd_imageFormatForImageData:data] == self.class.imageFormat);
}

- (instancetype)initIncrementalWithOptions:(nullable SDImageCoderOptions *)options {
    self = [super init];
    if (self) {
        NSString *imageUTType = self.class.imageUTType;
        _imageSource = CGImageSourceCreateIncremental((__bridge CFDictionaryRef)@{(__bridge NSString *)kCGImageSourceTypeIdentifierHint : imageUTType});
        CGFloat scale = 1;
        NSNumber *scaleFactor = options[SDImageCoderDecodeScaleFactor];
        if (scaleFactor != nil) {
            scale = MAX([scaleFactor doubleValue], 1);
        }
        _scale = scale;
        CGSize thumbnailSize = CGSizeZero;
        NSValue *thumbnailSizeValue = options[SDImageCoderDecodeThumbnailPixelSize];
        if (thumbnailSizeValue != nil) {
    #if SD_MAC
            thumbnailSize = thumbnailSizeValue.sizeValue;
    #else
            thumbnailSize = thumbnailSizeValue.CGSizeValue;
    #endif
        }
        _thumbnailSize = thumbnailSize;
        BOOL preserveAspectRatio = YES;
        NSNumber *preserveAspectRatioValue = options[SDImageCoderDecodePreserveAspectRatio];
        if (preserveAspectRatioValue != nil) {
            preserveAspectRatio = preserveAspectRatioValue.boolValue;
        }
        _preserveAspectRatio = preserveAspectRatio;
#if SD_UIKIT
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveMemoryWarning:) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
#endif
    }
    return self;
}

- (void)updateIncrementalData:(NSData *)data finished:(BOOL)finished {
    if (_finished) {
        return;
    }
    _imageData = data;
    _finished = finished;
    
    // The following code is from http://www.cocoaintheshell.com/2011/05/progressive-images-download-imageio/
    // Thanks to the author @Nyx0uf
    
    // Update the data source, we must pass ALL the data, not just the new bytes
    CGImageSourceUpdateData(_imageSource, (__bridge CFDataRef)data, finished);
    
    if (_width + _height == 0) {
        NSDictionary *options = @{
            (__bridge NSString *)kCGImageSourceShouldCacheImmediately : @(YES),
            (__bridge NSString *)kCGImageSourceShouldCache : @(YES) // Always cache to reduce CPU usage
        };
        CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(_imageSource, 0, (__bridge CFDictionaryRef)options);
        if (properties) {
            CFTypeRef val = CFDictionaryGetValue(properties, kCGImagePropertyPixelHeight);
            if (val) CFNumberGetValue(val, kCFNumberLongType, &_height);
            val = CFDictionaryGetValue(properties, kCGImagePropertyPixelWidth);
            if (val) CFNumberGetValue(val, kCFNumberLongType, &_width);
            CFRelease(properties);
        }
    }
    
    // For animated image progressive decoding because the frame count and duration may be changed.
    [self scanAndCheckFramesValidWithImageSource:_imageSource];
}

- (UIImage *)incrementalDecodedImageWithOptions:(SDImageCoderOptions *)options {
    UIImage *image;
    
    if (_width + _height > 0) {
        // Create the image
        CGFloat scale = _scale;
        NSNumber *scaleFactor = options[SDImageCoderDecodeScaleFactor];
        if (scaleFactor != nil) {
            scale = MAX([scaleFactor doubleValue], 1);
        }
        image = [self.class createFrameAtIndex:0 source:_imageSource scale:scale preserveAspectRatio:_preserveAspectRatio thumbnailSize:_thumbnailSize options:nil];
        if (image) {
            image.sd_imageFormat = self.class.imageFormat;
        }
    }
    
    return image;
}

#pragma mark - Encode
- (BOOL)canEncodeToFormat:(SDImageFormat)format {
    return (format == self.class.imageFormat);
}

- (NSData *)encodedDataWithImage:(UIImage *)image format:(SDImageFormat)format options:(nullable SDImageCoderOptions *)options {
    if (!image) {
        return nil;
    }
    CGImageRef imageRef = image.CGImage;
    if (!imageRef) {
        // Earily return, supports CGImage only
        return nil;
    }
    
    if (format != self.class.imageFormat) {
        return nil;
    }
    
    NSMutableData *imageData = [NSMutableData data];
    CFStringRef imageUTType = [NSData sd_UTTypeFromImageFormat:format];
    NSArray<SDImageFrame *> *frames = [SDImageCoderHelper framesFromAnimatedImage:image];
    
    // Create an image destination. Animated Image does not support EXIF image orientation TODO
    // The `CGImageDestinationCreateWithData` will log a warning when count is 0, use 1 instead.
    CGImageDestinationRef imageDestination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)imageData, imageUTType, frames.count ?: 1, NULL);//创建转换者对象, 进行质量压缩和转换
    if (!imageDestination) {
        // Handle failure.
        return nil;
    }
    NSMutableDictionary *properties = [NSMutableDictionary dictionary];
    // Encoding Options
    double compressionQuality = 1;
    if (options[SDImageCoderEncodeCompressionQuality]) {
        compressionQuality = [options[SDImageCoderEncodeCompressionQuality] doubleValue];
    }
    properties[(__bridge NSString *)kCGImageDestinationLossyCompressionQuality] = @(compressionQuality);
    CGColorRef backgroundColor = [options[SDImageCoderEncodeBackgroundColor] CGColor];
    if (backgroundColor) {
        properties[(__bridge NSString *)kCGImageDestinationBackgroundColor] = (__bridge id)(backgroundColor);
    }
    CGSize maxPixelSize = CGSizeZero;
    NSValue *maxPixelSizeValue = options[SDImageCoderEncodeMaxPixelSize];
    if (maxPixelSizeValue != nil) {
#if SD_MAC
        maxPixelSize = maxPixelSizeValue.sizeValue;
#else
        maxPixelSize = maxPixelSizeValue.CGSizeValue;
#endif
    }
    NSUInteger pixelWidth = CGImageGetWidth(imageRef);
    NSUInteger pixelHeight = CGImageGetHeight(imageRef);
    CGFloat finalPixelSize = 0;
    if (maxPixelSize.width > 0 && maxPixelSize.height > 0 && pixelWidth > 0 && pixelHeight > 0) {
        CGFloat pixelRatio = pixelWidth / pixelHeight;
        CGFloat maxPixelSizeRatio = maxPixelSize.width / maxPixelSize.height;
        if (pixelRatio > maxPixelSizeRatio) {
            finalPixelSize = maxPixelSize.width;
        } else {
            finalPixelSize = maxPixelSize.height;
        }
    }
    NSUInteger maxFileSize = [options[SDImageCoderEncodeMaxFileSize] unsignedIntegerValue];
    if (maxFileSize > 0) {
        properties[kSDCGImageDestinationRequestedFileSize] = @(maxFileSize);
        // Remove the quality if we have file size limit
        properties[(__bridge NSString *)kCGImageDestinationLossyCompressionQuality] = nil;
    }
    
    BOOL encodeFirstFrame = [options[SDImageCoderEncodeFirstFrameOnly] boolValue];
    if (encodeFirstFrame || frames.count == 0) {
        // for static single images
        if (finalPixelSize > 0) {
            properties[(__bridge NSString *)kCGImageDestinationImageMaxPixelSize] = @(finalPixelSize);
        }
        CGImageDestinationAddImage(imageDestination, imageRef, (__bridge CFDictionaryRef)properties);//向转换者对象添加图片数据和参数数据
    } else {
        // for animated images
        NSUInteger loopCount = image.sd_imageLoopCount;
        NSDictionary *containerProperties = @{self.class.loopCountProperty : @(loopCount)};
        properties[self.class.dictionaryProperty] = containerProperties;
        CGImageDestinationSetProperties(imageDestination, (__bridge CFDictionaryRef)properties);
        
        for (size_t i = 0; i < frames.count; i++) {
            SDImageFrame *frame = frames[i];
            NSTimeInterval frameDuration = frame.duration;
            CGImageRef frameImageRef = frame.image.CGImage;
            NSMutableDictionary *frameProperties = [NSMutableDictionary dictionary];
            frameProperties[self.class.dictionaryProperty] = @{self.class.delayTimeProperty : @(frameDuration)};
            if (finalPixelSize > 0) {
                frameProperties[(__bridge NSString *)kCGImageDestinationImageMaxPixelSize] = @(finalPixelSize);
            }
            CGImageDestinationAddImage(imageDestination, frameImageRef, (__bridge CFDictionaryRef)frameProperties);
        }
    }
    // Finalize the destination.
    if (CGImageDestinationFinalize(imageDestination) == NO) {
        // Handle failure.
        imageData = nil;
    }
    
    CFRelease(imageDestination);
    
    return [imageData copy];
}

#pragma mark - SDAnimatedImageCoder
- (nullable instancetype)initWithAnimatedImageData:(nullable NSData *)data options:(nullable SDImageCoderOptions *)options {
    if (!data) {
        return nil;
    }
    self = [super init];
    if (self) {
        ///创建图像源(創建CGImageSource對象)
        ///https://www.cnblogs.com/feng9exe/p/8857506.html
        ///ImageIO框架应用与分析: https://developer.aliyun.com/article/800012,
        ///https://www.itread01.com/articles/1487115508.html, https://www.itread01.com/articles/1487115508.html
        CGImageSourceRef imageSource = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
        if (!imageSource) {
            return nil;
        }
        BOOL framesValid = [self scanAndCheckFramesValidWithImageSource:imageSource];
        if (!framesValid) {
            CFRelease(imageSource);
            return nil;
        }
        CGFloat scale = 1;
        NSNumber *scaleFactor = options[SDImageCoderDecodeScaleFactor];
        if (scaleFactor != nil) {
            scale = MAX([scaleFactor doubleValue], 1);
        }
        _scale = scale;
        CGSize thumbnailSize = CGSizeZero;
        NSValue *thumbnailSizeValue = options[SDImageCoderDecodeThumbnailPixelSize];
        if (thumbnailSizeValue != nil) {
    #if SD_MAC
            thumbnailSize = thumbnailSizeValue.sizeValue;
    #else
            thumbnailSize = thumbnailSizeValue.CGSizeValue;
    #endif
        }
        _thumbnailSize = thumbnailSize;
        BOOL preserveAspectRatio = YES;
        NSNumber *preserveAspectRatioValue = options[SDImageCoderDecodePreserveAspectRatio];
        if (preserveAspectRatioValue != nil) {
            preserveAspectRatio = preserveAspectRatioValue.boolValue;
        }
        _preserveAspectRatio = preserveAspectRatio;
        _imageSource = imageSource;
        _imageData = data;
#if SD_UIKIT
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveMemoryWarning:) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
#endif
    }
    return self;
}

- (BOOL)scanAndCheckFramesValidWithImageSource:(CGImageSourceRef)imageSource {
    if (!imageSource) {
        return NO;
    }
    //获取图片帧数
    NSUInteger frameCount = CGImageSourceGetCount(imageSource);
    NSUInteger loopCount = [self.class imageLoopCountWithSource:imageSource];
    NSMutableArray<SDImageIOCoderFrame *> *frames = [NSMutableArray array];
    
    for (size_t i = 0; i < frameCount; i++) {
        SDImageIOCoderFrame *frame = [[SDImageIOCoderFrame alloc] init];
        frame.index = i;
        frame.duration = [self.class frameDurationAtIndex:i source:imageSource];
        [frames addObject:frame];
    }
    
    _frameCount = frameCount;
    _loopCount = loopCount;
    _frames = [frames copy];
    
    return YES;
}

- (NSData *)animatedImageData {
    return _imageData;
}

- (NSUInteger)animatedImageLoopCount {
    return _loopCount;
}

- (NSUInteger)animatedImageFrameCount {
    return _frameCount;
}

- (NSTimeInterval)animatedImageDurationAtIndex:(NSUInteger)index {
    if (index >= _frameCount) {
        return 0;
    }
    return _frames[index].duration;
}

- (UIImage *)animatedImageFrameAtIndex:(NSUInteger)index {
    if (index >= _frameCount) {
        return nil;
    }
    // Animated Image should not use the CGContext solution to force decode. Prefers to use Image/IO built in method, which is safer and memory friendly, see https://github.com/SDWebImage/SDWebImage/issues/2961
    NSDictionary *options = @{
        (__bridge NSString *)kCGImageSourceShouldCacheImmediately : @(YES),
        (__bridge NSString *)kCGImageSourceShouldCache : @(YES) // Always cache to reduce CPU usage
    };
    UIImage *image = [self.class createFrameAtIndex:index source:_imageSource scale:_scale preserveAspectRatio:_preserveAspectRatio thumbnailSize:_thumbnailSize options:options];
    if (!image) {
        return nil;
    }
    image.sd_imageFormat = self.class.imageFormat;
    image.sd_isDecoded = YES;;
    return image;
}

@end

