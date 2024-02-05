/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "NSImage+Compatibility.h"

#if SD_MAC

#import "SDImageCoderHelper.h"

@implementation NSImage (Compatibility)

- (nullable CGImageRef)CGImage {
    NSRect imageRect = NSMakeRect(0, 0, self.size.width, self.size.height);
    CGImageRef cgImage = [self CGImageForProposedRect:&imageRect context:nil hints:nil];
    return cgImage;
}

- (nullable CIImage *)CIImage {
    NSRect imageRect = NSMakeRect(0, 0, self.size.width, self.size.height);
    NSImageRep *imageRep = [self bestRepresentationForRect:imageRect context:nil hints:nil];
    if (![imageRep isKindOfClass:NSCIImageRep.class]) {
        return nil;
    }
    return ((NSCIImageRep *)imageRep).CIImage;
}

- (CGFloat)scale {
    CGFloat scale = 1;
    NSRect imageRect = NSMakeRect(0, 0, self.size.width, self.size.height);
    NSImageRep *imageRep = [self bestRepresentationForRect:imageRect context:nil hints:nil];
    CGFloat width = imageRep.size.width;
    CGFloat height = imageRep.size.height;
    NSUInteger pixelWidth = imageRep.pixelsWide;
    NSUInteger pixelHeight = imageRep.pixelsHigh;
    if (width > 0 && height > 0) {
        CGFloat widthScale = pixelWidth / width;
        CGFloat heightScale = pixelHeight / height;
        if (widthScale == heightScale && widthScale >= 1) {
            // Protect because there may be `NSImageRepMatchesDevice` (0)
            scale = widthScale;
        }
    }
    
    return scale;
}

//获取位图,从而修改图片的缩放因子scale、图片方向
- (instancetype)initWithCGImage:(nonnull CGImageRef)cgImage scale:(CGFloat)scale orientation:(CGImagePropertyOrientation)orientation {
    NSBitmapImageRep *imageRep;
    if (orientation != kCGImagePropertyOrientationUp) {
        // AppKit design is different from UIKit. Where CGImage based image rep does not respect to any orientation. Only data based image rep which contains the EXIF metadata can automatically detect orientation.
        // This should be nonnull, until the memory is exhausted cause `CGBitmapContextCreate` failed.
        CGImageRef rotatedCGImage = [SDImageCoderHelper CGImageCreateDecoded:cgImage orientation:orientation];
        //initWithCGImage: 方法用于初始化一个 NSBitmapImageRep 对象，该对象包含了与给定的 CGImage 对象相关联的位图数据。这样的初始化可以方便地将 Core Graphics 的图像对象与 Cocoa 中的图像表示方式相结合
        //NSBitmapImageRep 提供的方法来操作图像数据，比如设置像素、获取图像属性等
        imageRep = [[NSBitmapImageRep alloc] initWithCGImage:rotatedCGImage];
        CGImageRelease(rotatedCGImage);
    } else {
        imageRep = [[NSBitmapImageRep alloc] initWithCGImage:cgImage];
    }
    if (scale < 1) {
        scale = 1;
    }
    CGFloat pixelWidth = imageRep.pixelsWide;
    CGFloat pixelHeight = imageRep.pixelsHigh;
    NSSize size = NSMakeSize(pixelWidth / scale, pixelHeight / scale);
    self = [self initWithSize:size];
    if (self) {
        imageRep.size = size;
        
        //用于向位图图像表示对象中添加另一个表示对象。这个方法允许你将多个图像表示对象合并到同一个位图图像表示中，从而创建一个复合图像
        [self addRepresentation:imageRep];
    }
    return self;
}

//改变图像方向、缩放因子
- (instancetype)initWithCIImage:(nonnull CIImage *)ciImage scale:(CGFloat)scale orientation:(CGImagePropertyOrientation)orientation {
    NSCIImageRep *imageRep;
    if (orientation != kCGImagePropertyOrientationUp) {
        //用于应用指定的方向（orientation）到图像上
        //而 imageByApplyingOrientation: 允许你在不改变图像像素数据的情况下，仅仅改变图像的方向信息
        //需要注意的是，这个方法只是改变了图像的方向属性，而不会对像素数据进行实际的旋转
        CIImage *rotatedCIImage = [ciImage imageByApplyingOrientation:orientation];
        imageRep = [[NSCIImageRep alloc] initWithCIImage:rotatedCIImage];
    } else {
        imageRep = [[NSCIImageRep alloc] initWithCIImage:ciImage];
    }
    if (scale < 1) {
        scale = 1;
    }
    CGFloat pixelWidth = imageRep.pixelsWide;
    CGFloat pixelHeight = imageRep.pixelsHigh;
    NSSize size = NSMakeSize(pixelWidth / scale, pixelHeight / scale);
    self = [self initWithSize:size];
    if (self) {
        imageRep.size = size;
        [self addRepresentation:imageRep];
    }
    return self;
}

- (instancetype)initWithData:(nonnull NSData *)data scale:(CGFloat)scale {
    NSBitmapImageRep *imageRep = [[NSBitmapImageRep alloc] initWithData:data];
    if (!imageRep) {
        return nil;
    }
    if (scale < 1) {
        scale = 1;
    }
    CGFloat pixelWidth = imageRep.pixelsWide;
    CGFloat pixelHeight = imageRep.pixelsHigh;
    NSSize size = NSMakeSize(pixelWidth / scale, pixelHeight / scale);
    self = [self initWithSize:size];
    if (self) {
        imageRep.size = size;
        [self addRepresentation:imageRep];
    }
    return self;
}

@end

#endif
