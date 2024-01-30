/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "SDImageCoderHelper.h"
#import "SDImageFrame.h"
#import "NSImage+Compatibility.h"
#import "NSData+ImageContentType.h"
#import "SDAnimatedImageRep.h"
#import "UIImage+ForceDecode.h"
#import "SDAssociatedObject.h"
#import "UIImage+Metadata.h"
#import "SDInternalMacros.h"
#import <Accelerate/Accelerate.h>

//这是一个用于将字节大小进行对齐的内联函数（inline function）。这样的函数通常用于确保数据在内存中按照特定的对齐方式进行分配，以提高内存访问的性能。
static inline size_t SDByteAlign(size_t size, size_t alignment) {
    return ((size + (alignment - 1)) / alignment) * alignment;
}

// 每个像素占用的字节数
static const size_t kBytesPerPixel = 4;
// 色彩空间占用的字节数
static const size_t kBitsPerComponent = 8;

static const CGFloat kBytesPerMB = 1024.0f * 1024.0f;
// 1MB可以存储多少像素
static const CGFloat kPixelsPerMB = kBytesPerMB / kBytesPerPixel;
/*
 * Defines the maximum size in MB of the decoded image when the flag `SDWebImageScaleDownLargeImages` is set
 * Suggested value for iPad1 and iPhone 3GS: 60.
 * Suggested value for iPad2 and iPhone 4: 120.
 * Suggested value for iPhone 3G and iPod 2 and earlier devices: 30.
 */
#if SD_MAC
static CGFloat kDestImageLimitBytes = 90.f * kBytesPerMB;
#elif SD_UIKIT
static CGFloat kDestImageLimitBytes = 60.f * kBytesPerMB;
#elif SD_WATCH
static CGFloat kDestImageLimitBytes = 30.f * kBytesPerMB;
#endif

static const CGFloat kDestSeemOverlap = 2.0f;   // the numbers of pixels to overlap the seems where tiles meet.

@implementation SDImageCoderHelper

/// 用于创建一个动画图像。这个方法接受一个包含多个图像帧的数组，然后将这些帧组合成一个 UIImage 对象，从而形成一个动画。
/// @param frames 帧数
+ (UIImage *)animatedImageWithFrames:(NSArray<SDImageFrame *> *)frames {
    NSUInteger frameCount = frames.count;
    if (frameCount == 0) {
        return nil;
    }
    
    UIImage *animatedImage;
    
#if SD_UIKIT || SD_WATCH
    NSUInteger durations[frameCount];
    for (size_t i = 0; i < frameCount; i++) {
        durations[i] = frames[i].duration * 1000;
    }
    NSUInteger const gcd = gcdArray(frameCount, durations);
    __block NSUInteger totalDuration = 0;
    NSMutableArray<UIImage *> *animatedImages = [NSMutableArray arrayWithCapacity:frameCount];
    [frames enumerateObjectsUsingBlock:^(SDImageFrame * _Nonnull frame, NSUInteger idx, BOOL * _Nonnull stop) {
        UIImage *image = frame.image;
        NSUInteger duration = frame.duration * 1000;
        totalDuration += duration;
        NSUInteger repeatCount;
        if (gcd) {
            repeatCount = duration / gcd;
        } else {
            repeatCount = 1;
        }
        for (size_t i = 0; i < repeatCount; ++i) {
            [animatedImages addObject:image];
        }
    }];
    
    //用于创建动画图像的一个辅助方法。这个方法接受一个包含多个 UIImage 对象的数组，然后将这些帧组合成一个 UIImage 对象，从而形成一个动画
    animatedImage = [UIImage animatedImageWithImages:animatedImages duration:totalDuration / 1000.f];
    
#else
    
    NSMutableData *imageData = [NSMutableData data];
    CFStringRef imageUTType = [NSData sd_UTTypeFromImageFormat:SDImageFormatGIF];
    // Create an image destination. GIF does not support EXIF image orientation
    CGImageDestinationRef imageDestination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)imageData, imageUTType, frameCount, NULL);
    if (!imageDestination) {
        // Handle failure.
        return nil;
    }
    
    for (size_t i = 0; i < frameCount; i++) {
        @autoreleasepool {
            SDImageFrame *frame = frames[i];
            NSTimeInterval frameDuration = frame.duration;
            CGImageRef frameImageRef = frame.image.CGImage;
            NSDictionary *frameProperties = @{(__bridge NSString *)kCGImagePropertyGIFDictionary : @{(__bridge NSString *)kCGImagePropertyGIFDelayTime : @(frameDuration)}};
            CGImageDestinationAddImage(imageDestination, frameImageRef, (__bridge CFDictionaryRef)frameProperties);
        }
    }
    // Finalize the destination.
    if (CGImageDestinationFinalize(imageDestination) == NO) {
        // Handle failure.
        CFRelease(imageDestination);
        return nil;
    }
    CFRelease(imageDestination);
    CGFloat scale = MAX(frames.firstObject.image.scale, 1);
    
    SDAnimatedImageRep *imageRep = [[SDAnimatedImageRep alloc] initWithData:imageData];
    NSSize size = NSMakeSize(imageRep.pixelsWide / scale, imageRep.pixelsHigh / scale);
    imageRep.size = size;
    animatedImage = [[NSImage alloc] initWithSize:size];
    [animatedImage addRepresentation:imageRep];
#endif
    
    return animatedImage;
}

+ (NSArray<SDImageFrame *> *)framesFromAnimatedImage:(UIImage *)animatedImage {
    if (!animatedImage) {
        return nil;
    }
    
    NSMutableArray<SDImageFrame *> *frames = [NSMutableArray array];
    NSUInteger frameCount = 0;
    
#if SD_UIKIT || SD_WATCH
    NSArray<UIImage *> *animatedImages = animatedImage.images;
    frameCount = animatedImages.count;
    if (frameCount == 0) {
        return nil;
    }
    
    NSTimeInterval avgDuration = animatedImage.duration / frameCount;
    if (avgDuration == 0) {
        avgDuration = 0.1; // if it's a animated image but no duration, set it to default 100ms (this do not have that 10ms limit like GIF or WebP to allow custom coder provide the limit)
    }
    
    __block NSUInteger index = 0;
    __block NSUInteger repeatCount = 1;
    __block UIImage *previousImage = animatedImages.firstObject;
    [animatedImages enumerateObjectsUsingBlock:^(UIImage * _Nonnull image, NSUInteger idx, BOOL * _Nonnull stop) {
        // ignore first
        if (idx == 0) {
            return;
        }
        if ([image isEqual:previousImage]) {
            repeatCount++;
        } else {
            SDImageFrame *frame = [SDImageFrame frameWithImage:previousImage duration:avgDuration * repeatCount];
            [frames addObject:frame];
            repeatCount = 1;
            index++;
        }
        previousImage = image;
        // last one
        if (idx == frameCount - 1) {
            SDImageFrame *frame = [SDImageFrame frameWithImage:previousImage duration:avgDuration * repeatCount];
            [frames addObject:frame];
        }
    }];
    
#else
    
    NSRect imageRect = NSMakeRect(0, 0, animatedImage.size.width, animatedImage.size.height);
    NSImageRep *imageRep = [animatedImage bestRepresentationForRect:imageRect context:nil hints:nil];
    NSBitmapImageRep *bitmapImageRep;
    if ([imageRep isKindOfClass:[NSBitmapImageRep class]]) {
        bitmapImageRep = (NSBitmapImageRep *)imageRep;
    }
    if (!bitmapImageRep) {
        return nil;
    }
    frameCount = [[bitmapImageRep valueForProperty:NSImageFrameCount] unsignedIntegerValue];
    if (frameCount == 0) {
        return nil;
    }
    CGFloat scale = animatedImage.scale;
    
    for (size_t i = 0; i < frameCount; i++) {
        @autoreleasepool {
            // NSBitmapImageRep need to manually change frame. "Good taste" API
            [bitmapImageRep setProperty:NSImageCurrentFrame withValue:@(i)];
            NSTimeInterval frameDuration = [[bitmapImageRep valueForProperty:NSImageCurrentFrameDuration] doubleValue];
            NSImage *frameImage = [[NSImage alloc] initWithCGImage:bitmapImageRep.CGImage scale:scale orientation:kCGImagePropertyOrientationUp];
            SDImageFrame *frame = [SDImageFrame frameWithImage:frameImage duration:frameDuration];
            [frames addObject:frame];
        }
    }
#endif
    
    return frames;
}

+ (CGColorSpaceRef)colorSpaceGetDeviceRGB {
#if SD_MAC
    CGColorSpaceRef screenColorSpace = NSScreen.mainScreen.colorSpace.CGColorSpace;
    if (screenColorSpace) {
        return screenColorSpace;
    }
#endif
    static CGColorSpaceRef colorSpace;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
#if SD_UIKIT
        if (@available(iOS 9.0, tvOS 9.0, *)) {
            colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        } else {
            colorSpace = CGColorSpaceCreateDeviceRGB();
        }
#else
        colorSpace = CGColorSpaceCreateDeviceRGB();
#endif
    });
    return colorSpace;
}


/// 是否有alpha通道
/// @param cgImage <#cgImage description#>
/// 拓展: Alpha 通道在图像中表示每个像素的透明度。它是一个额外的通道，存储了每个像素的不透明度信息。Alpha 通道的取值范围通常是 0（完全透明）到 1（完全不透明）。
+ (BOOL)CGImageContainsAlpha:(CGImageRef)cgImage {
    if (!cgImage) {
        return NO;
    }
    //获取image的alpha通道。通过通道获取图片数据
    //https://www.jianshu.com/p/133a0cb40913,
    //CGImageGetAlphaInfo用于检查一个 CGImageRef 对象的 alpha 通道信息，以确定图像是否包含 alpha 通道
    CGImageAlphaInfo alphaInfo = CGImageGetAlphaInfo(cgImage);
    
    //如果 alphaInfo 的值不等于 kCGImageAlphaNone、kCGImageAlphaNoneSkipFirst 或 kCGImageAlphaNoneSkipLast 中的任何一个，那么 hasAlpha 就为 YES，表示图像包含 alpha 通道。否则，hasAlpha 为 NO，表示图像没有 alpha 通道。
    BOOL hasAlpha = !(alphaInfo == kCGImageAlphaNone ||
                      alphaInfo == kCGImageAlphaNoneSkipFirst ||
                      alphaInfo == kCGImageAlphaNoneSkipLast);
    
    return hasAlpha;
}

+ (CGImageRef)CGImageCreateDecoded:(CGImageRef)cgImage {
    return [self CGImageCreateDecoded:cgImage orientation:kCGImagePropertyOrientationUp];
}

+ (CGImageRef)CGImageCreateDecoded:(CGImageRef)cgImage orientation:(CGImagePropertyOrientation)orientation {
    if (!cgImage) {
        return NULL;
    }
    size_t width = CGImageGetWidth(cgImage);
    size_t height = CGImageGetHeight(cgImage);
    if (width == 0 || height == 0) return NULL;
    size_t newWidth;
    size_t newHeight;
    switch (orientation) {
        case kCGImagePropertyOrientationLeft:
        case kCGImagePropertyOrientationLeftMirrored:
        case kCGImagePropertyOrientationRight:
        case kCGImagePropertyOrientationRightMirrored: {
            // These orientation should swap width & height
            newWidth = height;
            newHeight = width;
        }
            break;
        default: {
            newWidth = width;
            newHeight = height;
        }
            break;
    }
    
    BOOL hasAlpha = [self CGImageContainsAlpha:cgImage];
    // iOS prefer BGRA8888 (premultiplied) or BGRX8888 bitmapInfo for screen rendering, which is same as `UIGraphicsBeginImageContext()` or `- [CALayer drawInContext:]`
    // Though you can use any supported bitmapInfo (see: https://developer.apple.com/library/content/documentation/GraphicsImaging/Conceptual/drawingwithquartz2d/dq_context/dq_context.html#//apple_ref/doc/uid/TP30001066-CH203-BCIBHHBB ) and let Core Graphics reorder it when you call `CGContextDrawImage`
    // But since our build-in coders use this bitmapInfo, this can have a little performance benefit
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrder32Host;
    bitmapInfo |= hasAlpha ? kCGImageAlphaPremultipliedFirst : kCGImageAlphaNoneSkipFirst;
    
    ////强制解压缩的原理就是对图片进行重新绘制，得到一张新的解压缩后的位图。其中，用到的最核心的函数是CGBitmapContextCreate() 方法，
    ///这个方法生成一个空白的图片绘制上下文，我们传入了上述的一些参数，指定了图片的大小、颜色空间、像素排列等等属性
    ///https://blog.csdn.net/hlllmr1314/article/details/8198543
    CGContextRef context = CGBitmapContextCreate(NULL, newWidth, newHeight, 8, 0, [self colorSpaceGetDeviceRGB], bitmapInfo);
    if (!context) {
        return NULL;
    }
    
    // Apply transform 矩阵转换: https://www.cnblogs.com/xiongwj0910/p/15421646.html
    CGAffineTransform transform = SDCGContextTransformFromOrientation(orientation, CGSizeMake(newWidth, newHeight));
    CGContextConcatCTM(context, transform);//使用 transform 变换矩阵对CGContextRef坐标系统进行变换,通过坐标矩阵可以对坐标系统任意变换
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), cgImage); // The rect is bounding box of CGImage, don't swap width & height
    //从 context 上下文中创建一个新的 imageRef，这是解码后的图片了
    CGImageRef newImageRef = CGBitmapContextCreateImage(context);//绘制图片
    CGContextRelease(context);
    
    return newImageRef;
}

/// CGImageRef 是 Core Graphics 框架中表示图像的数据类型之一。
/// 在 macOS 和 iOS 等苹果平台的图形处理中，CGImageRef 用于表示图像数据的引用，它是一个指向图像数据的不透明指针类型。
/// 根据指定size生成一个关于包含图像信息的CGImageRef的实例
/// @param cgImage <#cgImage description#>
/// @param size <#size description#>
+ (CGImageRef)CGImageCreateScaled:(CGImageRef)cgImage size:(CGSize)size {
    if (!cgImage) {
        return NULL;
    }
    //获取 CGImageRef 对象宽度的函数。它返回一个整数，表示图像的像素宽度。
    size_t width = CGImageGetWidth(cgImage);
    size_t height = CGImageGetHeight(cgImage);
    if (width == size.width && height == size.height) {
        // 使用 CGImageRetain 增加引用计数
        CGImageRetain(cgImage);
        return cgImage;
    }
    
    //vImage_Buffer 是 Accelerate 框架中的结构体，用于表示一个二维图像的缓冲区。Accelerate 框架是苹果提供的用于高性能数学和图像处理的框架，其中 vImage_Buffer 结构体在图像处理中经常用于表示图像数据的存储。
    __block vImage_Buffer input_buffer = {}, output_buffer = {};
    
    //这段代码使用了 @onExit 块，它的作用是在当前作用域结束时自动执行一段代码块。在这个具体的例子中，@onExit 块用于释放两个 vImage_Buffer 结构体对象（input_buffer 和 output_buffer）中的图像数据缓冲区，防止内存泄漏。
    @onExit {
        if (input_buffer.data) free(input_buffer.data);
        if (output_buffer.data) free(output_buffer.data);
    };
    
    BOOL hasAlpha = [self CGImageContainsAlpha:cgImage];//是否有alpha通道
    // iOS display alpha info (BGRA8888/BGRX8888)
    //kCGBitmapByteOrder32Host 是 Core Graphics 框架中用于指定位图字节顺序的常量之一。这个常量表示使用主机的字节顺序来存储每个像素的颜色分量。
    //在计算机中，字节顺序（Byte Order）指的是多字节数据在内存中的存储方式。有两种主要的字节顺序：大端字节序（Big Endian）和小端字节序（Little Endian）。不同的计算机体系结构和处理器可能使用不同的字节顺序。
    //对于 kCGBitmapByteOrder32Host，它的作用是告诉 Core Graphics 在创建位图时，使用主机的字节顺序来存储每个像素的颜色分量。这样可以确保位图数据的字节顺序与当前计算机环境的字节顺序一致，避免了在不同字节序的系统之间发生错误。
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrder32Host;
    
    /**kCGImageAlphaPremultipliedFirst 和 kCGImageAlphaNoneSkipFirst 都是用于指定图像中 alpha 通道信息的 Core Graphics 常量，它们之间的主要区别在于 alpha 通道的处理方式
     *
     *kCGImageAlphaPremultipliedFirst:
     *  这个常量表示图像的 alpha 通道是预乘在颜色分量之前的。预乘是指将 RGB 颜色分量乘以 alpha 通道值，得到新的预乘后的 RGB 值。
     *  常用于图像合成，可以提高图像的渲染效果。但在图像编辑中，如果频繁修改 alpha 通道值，可能会导致颜色损失。
     
     *kCGImageAlphaNoneSkipFirst:
     *  这个常量表示图像中没有 alpha 通道，即每个像素只有 RGB 颜色分量。它同时表示在像素中没有 alpha 通道的存在。
     *  适用于没有透明度要求的图像，不涉及半透明或合成操作。
     */
    bitmapInfo |= hasAlpha ? kCGImageAlphaPremultipliedFirst : kCGImageAlphaNoneSkipFirst;
    
    //vImage_CGImageFormat 是 Accelerate 框架中的一个结构体，用于描述 Core Graphics 图像格式。
    //这个结构体通常用于在 Accelerate 框架的图像处理函数中指定输入和输出图像的格式信息
    vImage_CGImageFormat format = (vImage_CGImageFormat) {
        .bitsPerComponent = 8,// 每个颜色分量的位数
        .bitsPerPixel = 32,// 每个像素的位数
        .colorSpace = NULL,// 颜色空间
        .bitmapInfo = bitmapInfo,// 位图信息
        .version = 0,
        .decode = NULL,
        .renderingIntent = kCGRenderingIntentDefault, //是在图像处理中指定的一个参数，用于定义图像的颜色渲染意图。颜色渲染意图决定了如何将图像的颜色空间映射到显示设备的颜色空间，以及如何处理颜色之间的映射关系。
    };
    
    // 在进行图像处理时，使用 format 描述输入或输出图像的格式
    vImage_Error a_ret = vImageBuffer_InitWithCGImage(&input_buffer, &format, NULL, cgImage, kvImageNoFlags);
    if (a_ret != kvImageNoError) return NULL;
    output_buffer.width = MAX(size.width, 0);
    output_buffer.height = MAX(size.height, 0);
    output_buffer.rowBytes = SDByteAlign(output_buffer.width * 4, 64);//字节对齐
    output_buffer.data = malloc(output_buffer.rowBytes * output_buffer.height);
    if (!output_buffer.data) return NULL;
    
    //vImageScale_ARGB8888 用于在 ARGB8888 格式的图像上执行线性插值缩放，其中图像的每个像素由 32 位表示，包含 Alpha、红、绿、蓝四个通道。
    //在使用 kvImageHighQualityResampling 标志位时，缩放函数将使用一种更为精细的插值算法，以在图像缩放时保持更多的细节和颜色准确性。
    vImage_Error ret = vImageScale_ARGB8888(&input_buffer, &output_buffer, NULL, kvImageHighQualityResampling);
    if (ret != kvImageNoError) return NULL;
    
    //vImageCreateCGImageFromBuffer目的是将 output_buffer 中的像素数据转换为 Core Graphics 图像对象。创建的 CGImage 对象可以用于进一步的图像处理、显示或保存等操作。
    CGImageRef outputImage = vImageCreateCGImageFromBuffer(&output_buffer, &format, NULL, NULL, kvImageNoFlags, &ret);
    if (ret != kvImageNoError) {
        CGImageRelease(outputImage);
        return NULL;
    }
    
    return outputImage;
}

+ (UIImage *)decodedImageWithImage:(UIImage *)image {
    if (![self shouldDecodeImage:image]) {
        return image;
    }
    
    CGImageRef imageRef = [self CGImageCreateDecoded:image.CGImage];
    if (!imageRef) {
        return image;
    }
#if SD_MAC
    UIImage *decodedImage = [[UIImage alloc] initWithCGImage:imageRef scale:image.scale orientation:kCGImagePropertyOrientationUp];
#else
    UIImage *decodedImage = [[UIImage alloc] initWithCGImage:imageRef scale:image.scale orientation:image.imageOrientation];
#endif
    CGImageRelease(imageRef);
    SDImageCopyAssociatedObject(image, decodedImage);
    decodedImage.sd_isDecoded = YES;
    return decodedImage;
}

/// 解压缩图片
+ (UIImage *)decodedAndScaledDownImageWithImage:(UIImage *)image limitBytes:(NSUInteger)bytes {
    if (![self shouldDecodeImage:image]) {
        return image;
    }
    
    if (![self shouldScaleDownImage:image limitBytes:bytes]) {
        return [self decodedImageWithImage:image];
    }
    
    CGFloat destTotalPixels;
    CGFloat tileTotalPixels;
    if (bytes == 0) {
        bytes = kDestImageLimitBytes;
    }
    destTotalPixels = bytes / kBytesPerPixel;
    tileTotalPixels = destTotalPixels / 3;
    CGContextRef destContext;
    
    // autorelease the bitmap context and all vars to help system to free memory when there are memory warning.
    // on iOS7, do not forget to call [[SDImageCache sharedImageCache] clearMemory];
    // 解压缩操作放入一个自动释放池里面，以便自动释放所有的变量
    @autoreleasepool {
        CGImageRef sourceImageRef = image.CGImage;
        
        CGSize sourceResolution = CGSizeZero;
        sourceResolution.width = CGImageGetWidth(sourceImageRef);
        sourceResolution.height = CGImageGetHeight(sourceImageRef);
        CGFloat sourceTotalPixels = sourceResolution.width * sourceResolution.height;
        // Determine the scale ratio to apply to the input image
        // that results in an output image of the defined size.
        // see kDestImageSizeMB, and how it relates to destTotalPixels.
        CGFloat imageScale = sqrt(destTotalPixels / sourceTotalPixels);
        CGSize destResolution = CGSizeZero;
        destResolution.width = (int)(sourceResolution.width * imageScale);
        destResolution.height = (int)(sourceResolution.height * imageScale);
        
        // device color space
        // 获取图片的色彩空间
        CGColorSpaceRef colorspaceRef = [self colorSpaceGetDeviceRGB];
        BOOL hasAlpha = [self CGImageContainsAlpha:sourceImageRef];
        // iOS display alpha info (BGRA8888/BGRX8888)
        CGBitmapInfo bitmapInfo = kCGBitmapByteOrder32Host;
        bitmapInfo |= hasAlpha ? kCGImageAlphaPremultipliedFirst : kCGImageAlphaNoneSkipFirst;
        
        // kCGImageAlphaNone is not supported in CGBitmapContextCreate.
        // Since the original image here has no alpha info, use kCGImageAlphaNoneSkipFirst
        // to create bitmap graphics contexts without alpha info.
        destContext = CGBitmapContextCreate(NULL,
                                            destResolution.width,
                                            destResolution.height,
                                            kBitsPerComponent,
                                            0,
                                            colorspaceRef,
                                            bitmapInfo);
        
        if (destContext == NULL) {
            return image;
        }
        CGContextSetInterpolationQuality(destContext, kCGInterpolationHigh);
        
        // Now define the size of the rectangle to be used for the
        // incremental blits from the input image to the output image.
        // we use a source tile width equal to the width of the source
        // image due to the way that iOS retrieves image data from disk.
        // iOS must decode an image from disk in full width 'bands', even
        // if current graphics context is clipped to a subrect within that
        // band. Therefore we fully utilize all of the pixel data that results
        // from a decoding opertion by achnoring our tile size to the full
        // width of the input image.
        CGRect sourceTile = CGRectZero;
        sourceTile.size.width = sourceResolution.width;
        // The source tile height is dynamic. Since we specified the size
        // of the source tile in MB, see how many rows of pixels high it
        // can be given the input image width.
        sourceTile.size.height = (int)(tileTotalPixels / sourceTile.size.width );
        sourceTile.origin.x = 0.0f;
        // The output tile is the same proportions as the input tile, but
        // scaled to image scale.
        CGRect destTile;
        destTile.size.width = destResolution.width;
        destTile.size.height = sourceTile.size.height * imageScale;
        destTile.origin.x = 0.0f;
        // The source seem overlap is proportionate to the destination seem overlap.
        // this is the amount of pixels to overlap each tile as we assemble the ouput image.
        float sourceSeemOverlap = (int)((kDestSeemOverlap/destResolution.height)*sourceResolution.height);
        CGImageRef sourceTileImageRef;
        // calculate the number of read/write operations required to assemble the
        // output image.
        int iterations = (int)( sourceResolution.height / sourceTile.size.height );
        // If tile height doesn't divide the image height evenly, add another iteration
        // to account for the remaining pixels.
        int remainder = (int)sourceResolution.height % (int)sourceTile.size.height;
        if(remainder) {
            iterations++;
        }
        // Add seem overlaps to the tiles, but save the original tile height for y coordinate calculations.
        float sourceTileHeightMinusOverlap = sourceTile.size.height;
        sourceTile.size.height += sourceSeemOverlap;
        destTile.size.height += kDestSeemOverlap;
        for( int y = 0; y < iterations; ++y ) {
            @autoreleasepool {
                sourceTile.origin.y = y * sourceTileHeightMinusOverlap + sourceSeemOverlap;
                destTile.origin.y = destResolution.height - (( y + 1 ) * sourceTileHeightMinusOverlap * imageScale + kDestSeemOverlap);
                sourceTileImageRef = CGImageCreateWithImageInRect( sourceImageRef, sourceTile );
                if( y == iterations - 1 && remainder ) {
                    float dify = destTile.size.height;
                    destTile.size.height = CGImageGetHeight( sourceTileImageRef ) * imageScale;
                    dify -= destTile.size.height;
                    destTile.origin.y += dify;
                }
                CGContextDrawImage( destContext, destTile, sourceTileImageRef );
                CGImageRelease( sourceTileImageRef );
            }
        }
        
        CGImageRef destImageRef = CGBitmapContextCreateImage(destContext);
        CGContextRelease(destContext);
        if (destImageRef == NULL) {
            return image;
        }
#if SD_MAC
        UIImage *destImage = [[UIImage alloc] initWithCGImage:destImageRef scale:image.scale orientation:kCGImagePropertyOrientationUp];
#else
        UIImage *destImage = [[UIImage alloc] initWithCGImage:destImageRef scale:image.scale orientation:image.imageOrientation];
#endif
        CGImageRelease(destImageRef);
        if (destImage == nil) {
            return image;
        }
        SDImageCopyAssociatedObject(image, destImage);
        destImage.sd_isDecoded = YES;
        return destImage;
    }
}

+ (NSUInteger)defaultScaleDownLimitBytes {
    return kDestImageLimitBytes;
}

+ (void)setDefaultScaleDownLimitBytes:(NSUInteger)defaultScaleDownLimitBytes {
    if (defaultScaleDownLimitBytes < kBytesPerMB) {
        return;
    }
    kDestImageLimitBytes = defaultScaleDownLimitBytes;
}

#if SD_UIKIT || SD_WATCH
// Convert an EXIF image orientation to an iOS one.
+ (UIImageOrientation)imageOrientationFromEXIFOrientation:(CGImagePropertyOrientation)exifOrientation {
    UIImageOrientation imageOrientation = UIImageOrientationUp;
    switch (exifOrientation) {
        case kCGImagePropertyOrientationUp:
            imageOrientation = UIImageOrientationUp;
            break;
        case kCGImagePropertyOrientationDown:
            imageOrientation = UIImageOrientationDown;
            break;
        case kCGImagePropertyOrientationLeft:
            imageOrientation = UIImageOrientationLeft;
            break;
        case kCGImagePropertyOrientationRight:
            imageOrientation = UIImageOrientationRight;
            break;
        case kCGImagePropertyOrientationUpMirrored:
            imageOrientation = UIImageOrientationUpMirrored;
            break;
        case kCGImagePropertyOrientationDownMirrored:
            imageOrientation = UIImageOrientationDownMirrored;
            break;
        case kCGImagePropertyOrientationLeftMirrored:
            imageOrientation = UIImageOrientationLeftMirrored;
            break;
        case kCGImagePropertyOrientationRightMirrored:
            imageOrientation = UIImageOrientationRightMirrored;
            break;
        default:
            break;
    }
    return imageOrientation;
}

// Convert an iOS orientation to an EXIF image orientation.
+ (CGImagePropertyOrientation)exifOrientationFromImageOrientation:(UIImageOrientation)imageOrientation {
    CGImagePropertyOrientation exifOrientation = kCGImagePropertyOrientationUp;
    switch (imageOrientation) {
        case UIImageOrientationUp:
            exifOrientation = kCGImagePropertyOrientationUp;
            break;
        case UIImageOrientationDown:
            exifOrientation = kCGImagePropertyOrientationDown;
            break;
        case UIImageOrientationLeft:
            exifOrientation = kCGImagePropertyOrientationLeft;
            break;
        case UIImageOrientationRight:
            exifOrientation = kCGImagePropertyOrientationRight;
            break;
        case UIImageOrientationUpMirrored:
            exifOrientation = kCGImagePropertyOrientationUpMirrored;
            break;
        case UIImageOrientationDownMirrored:
            exifOrientation = kCGImagePropertyOrientationDownMirrored;
            break;
        case UIImageOrientationLeftMirrored:
            exifOrientation = kCGImagePropertyOrientationLeftMirrored;
            break;
        case UIImageOrientationRightMirrored:
            exifOrientation = kCGImagePropertyOrientationRightMirrored;
            break;
        default:
            break;
    }
    return exifOrientation;
}
#endif

#pragma mark - Helper Fuction
+ (BOOL)shouldDecodeImage:(nullable UIImage *)image {
    // Prevent "CGBitmapContextCreateImage: invalid context 0x0" error
    if (image == nil) {
        return NO;
    }
    // Avoid extra decode
    if (image.sd_isDecoded) {
        return NO;
    }
    // do not decode animated images
    if (image.sd_isAnimated) {
        return NO;
    }
    // do not decode vector images
    if (image.sd_isVector) {
        return NO;
    }
    
    return YES;
}

// 是否需要减少原始图片的大小
+ (BOOL)shouldScaleDownImage:(nonnull UIImage *)image limitBytes:(NSUInteger)bytes {
    BOOL shouldScaleDown = YES;
    
    CGImageRef sourceImageRef = image.CGImage;
    CGSize sourceResolution = CGSizeZero;
    sourceResolution.width = CGImageGetWidth(sourceImageRef);
    sourceResolution.height = CGImageGetHeight(sourceImageRef);
    float sourceTotalPixels = sourceResolution.width * sourceResolution.height;
    if (sourceTotalPixels <= 0) {
        return NO;
    }
    CGFloat destTotalPixels;
    if (bytes == 0) {
        bytes = kDestImageLimitBytes;
    }
    destTotalPixels = bytes / kBytesPerPixel;
    if (destTotalPixels <= kPixelsPerMB) {
        // Too small to scale down
        return NO;
    }
    float imageScale = destTotalPixels / sourceTotalPixels;
    if (imageScale < 1) {
        shouldScaleDown = YES;
    } else {
        shouldScaleDown = NO;
    }
    
    return shouldScaleDown;
}
///类联函数: https://juejin.cn/post/6844903847123484686
static inline CGAffineTransform SDCGContextTransformFromOrientation(CGImagePropertyOrientation orientation, CGSize size) {
    // Inspiration from @libfeihu
    // We need to calculate the proper transformation to make the image upright.
    // We do it in 2 steps: Rotate if Left/Right/Down, and then flip if Mirrored.
    CGAffineTransform transform = CGAffineTransformIdentity;
    
    switch (orientation) {
        case kCGImagePropertyOrientationDown:
        case kCGImagePropertyOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, size.width, size.height);//在已存在的矩阵中使用平移: https://blog.csdn.net/zx6268476/article/details/45173605
            transform = CGAffineTransformRotate(transform, M_PI); //在已存在的矩阵中使用旋转
            break;
            
        case kCGImagePropertyOrientationLeft:
        case kCGImagePropertyOrientationLeftMirrored:
            transform = CGAffineTransformTranslate(transform, size.width, 0);
            transform = CGAffineTransformRotate(transform, M_PI_2);
            break;
            
        case kCGImagePropertyOrientationRight:
        case kCGImagePropertyOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, 0, size.height);
            transform = CGAffineTransformRotate(transform, -M_PI_2);
            break;
        case kCGImagePropertyOrientationUp:
        case kCGImagePropertyOrientationUpMirrored:
            break;
    }
    
    switch (orientation) {
        case kCGImagePropertyOrientationUpMirrored:
        case kCGImagePropertyOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, size.width, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
            
        case kCGImagePropertyOrientationLeftMirrored:
        case kCGImagePropertyOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, size.height, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
        case kCGImagePropertyOrientationUp:
        case kCGImagePropertyOrientationDown:
        case kCGImagePropertyOrientationLeft:
        case kCGImagePropertyOrientationRight:
            break;
    }
    
    return transform;
}

#if SD_UIKIT || SD_WATCH
static NSUInteger gcd(NSUInteger a, NSUInteger b) {
    NSUInteger c;
    while (a != 0) {
        c = a;
        a = b % a;
        b = c;
    }
    return b;
}

static NSUInteger gcdArray(size_t const count, NSUInteger const * const values) {
    if (count == 0) {
        return 0;
    }
    NSUInteger result = values[0];
    for (size_t i = 1; i < count; ++i) {
        result = gcd(values[i], result);
    }
    return result;
}
#endif

@end
