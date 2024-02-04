/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "SDImageGraphics.h"
#import "NSImage+Compatibility.h"
#import "objc/runtime.h"

#if SD_MAC
static void *kNSGraphicsContextScaleFactorKey;

static CGContextRef SDCGContextCreateBitmapContext(CGSize size, BOOL opaque, CGFloat scale) {
    if (scale == 0) {
        // Match `UIGraphicsBeginImageContextWithOptions`, reset to the scale factor of the device’s main screen if scale is 0.
        scale = [NSScreen mainScreen].backingScaleFactor;
    }
    size_t width = ceil(size.width * scale);
    size_t height = ceil(size.height * scale);
    if (width < 1 || height < 1) return NULL;
    
    //pre-multiplied BGRA for non-opaque, BGRX for opaque, 8-bits per component, as Apple's doc
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGImageAlphaInfo alphaInfo = kCGBitmapByteOrder32Host | (opaque ? kCGImageAlphaNoneSkipFirst : kCGImageAlphaPremultipliedFirst);
    
    //CGBitmapContextCreate 是 Core Graphics 框架中的一个函数，用于创建一个基于位图的图形上下文（CGContext）。这个函数通常用于在内存中创建一个位图，以便进行图形绘制操作，然后可以将位图转换为图像或其他图形对象
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, 0, space, kCGBitmapByteOrderDefault | alphaInfo);
    CGColorSpaceRelease(space);
    if (!context) {
        return NULL;
    }
    //CGContextScaleCTM 是 Core Graphics 框架中的一个函数，用于在图形上下文中应用缩放变换。这个函数可以缩放图形上下文中绘制的所有内容，包括路径、文本和图像等
    CGContextScaleCTM(context, scale, scale);
    
    return context;
}
#endif

CGContextRef SDGraphicsGetCurrentContext(void) {
#if SD_UIKIT || SD_WATCH
    //用于获取当前图形上下文（CGContext）。这个函数返回一个可选的 CGContext 对象，表示当前正在被绘制的图形上下文
    return UIGraphicsGetCurrentContext();
#else
    return NSGraphicsContext.currentContext.CGContext;
#endif
}

void SDGraphicsBeginImageContext(CGSize size) {
#if SD_UIKIT || SD_WATCH
    UIGraphicsBeginImageContext(size);
#else
    SDGraphicsBeginImageContextWithOptions(size, NO, 1.0);
#endif
}

void SDGraphicsBeginImageContextWithOptions(CGSize size, BOOL opaque, CGFloat scale) {
#if SD_UIKIT || SD_WATCH
    //UIGraphicsBeginImageContextWithOptions 是一个在 UIKit 中用于创建图形上下文的函数。它允许你在指定的大小和配置下，开始一个基于位图的图形上下文，用于进行图形绘制操作
    UIGraphicsBeginImageContextWithOptions(size, opaque, scale);
#else
    //生成一个上下文
    CGContextRef context = SDCGContextCreateBitmapContext(size, opaque, scale);
    if (!context) {
        return;
    }
    //graphicsContextWithCGContext 方法创建一个 UIGraphicsContext 对象，该对象包装了指定的 Core Graphics 上下文（CGContext）
    NSGraphicsContext *graphicsContext = [NSGraphicsContext graphicsContextWithCGContext:context flipped:NO];
    objc_setAssociatedObject(graphicsContext, &kNSGraphicsContextScaleFactorKey, @(scale), OBJC_ASSOCIATION_RETAIN);
    CGContextRelease(context);
    
    //保存图形上下文状态的方法。这个方法会将当前图形上下文的状态保存到一个堆栈中，以便稍后通过 [NSGraphi
    [NSGraphicsContext saveGraphicsState];
    NSGraphicsContext.currentContext = graphicsContext;
#endif
}

void SDGraphicsEndImageContext(void) {
#if SD_UIKIT || SD_WATCH
    //结束图形上下文
    UIGraphicsEndImageContext();
#else
    //[NSGraphicsContext restoreGraphicsState] 是 macOS 开发中用于还原图形上下文状态的方法。它用于恢复之前通过 [NSGraphicsContext saveGraphicsState] 方法保存的图形上下文状态
    [NSGraphicsContext restoreGraphicsState];
#endif
}

UIImage * SDGraphicsGetImageFromCurrentImageContext(void) {
#if SD_UIKIT || SD_WATCH
    //从当前图形上下文（UIGraphicsGetCurrentContext）中获取图像对象
    return UIGraphicsGetImageFromCurrentImageContext();
#else
    NSGraphicsContext *context = NSGraphicsContext.currentContext;
    CGContextRef contextRef = context.CGContext;
    if (!contextRef) {
        return nil;
    }
    //从位图上下文（CGBitmapContext）中创建一个 Core Graphics 图像（CGImage）对象
    CGImageRef imageRef = CGBitmapContextCreateImage(contextRef);
    if (!imageRef) {
        return nil;
    }
    CGFloat scale = 0;
    NSNumber *scaleFactor = objc_getAssociatedObject(context, &kNSGraphicsContextScaleFactorKey);
    if ([scaleFactor isKindOfClass:[NSNumber class]]) {
        scale = scaleFactor.doubleValue;
    }
    if (!scale) {
        // reset to the scale factor of the device’s main screen if scale is 0.
        scale = [NSScreen mainScreen].backingScaleFactor;
    }
    NSImage *image = [[NSImage alloc] initWithCGImage:imageRef scale:scale orientation:kCGImagePropertyOrientationUp];
    CGImageRelease(imageRef);
    return image;
#endif
}
