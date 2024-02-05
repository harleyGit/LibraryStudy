/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "UIImage+Transform.h"
#import "NSImage+Compatibility.h"
#import "SDImageGraphics.h"
#import "SDGraphicsImageRenderer.h"
#import "NSBezierPath+SDRoundedCorners.h"
#import <Accelerate/Accelerate.h>
#if SD_UIKIT || SD_MAC
#import <CoreImage/CoreImage.h>
#endif

//用于根据给定的 SDImageScaleMode 缩放模式，将一个矩形 rect 适应到目标大小 size
static inline CGRect SDCGRectFitWithScaleMode(CGRect rect, CGSize size, SDImageScaleMode scaleMode) {
    rect = CGRectStandardize(rect);
    size.width = size.width < 0 ? -size.width : size.width;
    size.height = size.height < 0 ? -size.height : size.height;
    CGPoint center = CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
    switch (scaleMode) {
        case SDImageScaleModeAspectFit:
        case SDImageScaleModeAspectFill: {
            if (rect.size.width < 0.01 || rect.size.height < 0.01 ||
                size.width < 0.01 || size.height < 0.01) {
                rect.origin = center;
                rect.size = CGSizeZero;
            } else {
                CGFloat scale;
                if (scaleMode == SDImageScaleModeAspectFit) {
                    if (size.width / size.height < rect.size.width / rect.size.height) {
                        scale = rect.size.height / size.height;
                    } else {
                        scale = rect.size.width / size.width;
                    }
                } else {
                    if (size.width / size.height < rect.size.width / rect.size.height) {
                        scale = rect.size.width / size.width;
                    } else {
                        scale = rect.size.height / size.height;
                    }
                }
                size.width *= scale;
                size.height *= scale;
                rect.size = size;
                rect.origin = CGPointMake(center.x - size.width * 0.5, center.y - size.height * 0.5);
            }
        } break;
        case SDImageScaleModeFill:
        default: {
            rect = rect;
        }
    }
    return rect;
}

static inline UIColor * SDGetColorFromPixel(Pixel_8888 pixel, CGBitmapInfo bitmapInfo) {
    // Get alpha info, byteOrder info
    //alpha 的信息由枚举值 CGImageAlphaInfo 来表示:https://www.cnblogs.com/dins/p/ios-tu-pian.html
    CGImageAlphaInfo alphaInfo = bitmapInfo & kCGBitmapAlphaInfoMask;
    CGBitmapInfo byteOrderInfo = bitmapInfo & kCGBitmapByteOrderMask;
    CGFloat r = 0, g = 0, b = 0, a = 1;
    
    BOOL byteOrderNormal = NO;
    switch (byteOrderInfo) {
        case kCGBitmapByteOrderDefault: {
            byteOrderNormal = YES;
        } break;
        case kCGBitmapByteOrder32Little: {
        } break;
        case kCGBitmapByteOrder32Big: {
            byteOrderNormal = YES;
        } break;
        default: break;
    }
    switch (alphaInfo) {
        case kCGImageAlphaPremultipliedFirst:
        case kCGImageAlphaFirst: {
            if (byteOrderNormal) {
                // ARGB8888
                a = pixel[0] / 255.0;
                r = pixel[1] / 255.0;
                g = pixel[2] / 255.0;
                b = pixel[3] / 255.0;
            } else {
                // BGRA8888
                b = pixel[0] / 255.0;
                g = pixel[1] / 255.0;
                r = pixel[2] / 255.0;
                a = pixel[3] / 255.0;
            }
        }
            break;
        case kCGImageAlphaPremultipliedLast:
        case kCGImageAlphaLast: {
            if (byteOrderNormal) {
                // RGBA8888
                r = pixel[0] / 255.0;
                g = pixel[1] / 255.0;
                b = pixel[2] / 255.0;
                a = pixel[3] / 255.0;
            } else {
                // ABGR8888
                a = pixel[0] / 255.0;
                b = pixel[1] / 255.0;
                g = pixel[2] / 255.0;
                r = pixel[3] / 255.0;
            }
        }
            break;
        case kCGImageAlphaNone: {
            if (byteOrderNormal) {
                // RGB
                r = pixel[0] / 255.0;
                g = pixel[1] / 255.0;
                b = pixel[2] / 255.0;
            } else {
                // BGR
                b = pixel[0] / 255.0;
                g = pixel[1] / 255.0;
                r = pixel[2] / 255.0;
            }
        }
            break;
        case kCGImageAlphaNoneSkipLast: {
            if (byteOrderNormal) {
                // RGBX
                r = pixel[0] / 255.0;
                g = pixel[1] / 255.0;
                b = pixel[2] / 255.0;
            } else {
                // XBGR
                b = pixel[1] / 255.0;
                g = pixel[2] / 255.0;
                r = pixel[3] / 255.0;
            }
        }
            break;
        case kCGImageAlphaNoneSkipFirst: {
            if (byteOrderNormal) {
                // XRGB
                r = pixel[1] / 255.0;
                g = pixel[2] / 255.0;
                b = pixel[3] / 255.0;
            } else {
                // BGRX
                b = pixel[0] / 255.0;
                g = pixel[1] / 255.0;
                r = pixel[2] / 255.0;
            }
        }
            break;
        case kCGImageAlphaOnly: {
            // A
            a = pixel[0] / 255.0;
        }
            break;
        default:
            break;
    }
    
    return [UIColor colorWithRed:r green:g blue:b alpha:a];
}

#if SD_UIKIT || SD_MAC
// Create-Rule, caller should call CGImageRelease
static inline CGImageRef _Nullable SDCreateCGImageFromCIImage(CIImage * _Nonnull ciImage) {
    CGImageRef imageRef = NULL;
    if (@available(iOS 10, macOS 10.12, tvOS 10, *)) {
        imageRef = ciImage.CGImage;
    }
    if (!imageRef) {
        CIContext *context = [CIContext context];
        imageRef = [context createCGImage:ciImage fromRect:ciImage.extent];
    } else {
        CGImageRetain(imageRef);
    }
    return imageRef;
}
#endif

@implementation UIImage (Transform)

- (void)sd_drawInRect:(CGRect)rect context:(CGContextRef)context scaleMode:(SDImageScaleMode)scaleMode clipsToBounds:(BOOL)clips {
    CGRect drawRect = SDCGRectFitWithScaleMode(rect, self.size, scaleMode);
    if (drawRect.size.width == 0 || drawRect.size.height == 0) return;
    if (clips) {
        if (context) {
            //保存 CGContext 的当前图形状态。它主要用于在进行图形绘制时保存当前图形上下文的状态，以便后续能够还原到保存的状态
            CGContextSaveGState(context);
            //向当前的图形上下文（CGContext）添加一个矩形路径。这个函数通常用于准备要绘制的图形的路径
            CGContextAddRect(context, rect);
            //在当前图形上下文中创建一个裁剪区域。通过调用 CGContextClip，您可以将当前图形上下文的绘制限制在指定的区域内，超出该区域的内容将不再被绘制
            CGContextClip(context);
            //在指定的矩形区域内绘制图像，可以指定其他参数来控制绘制操作
            [self drawInRect:drawRect];
            CGContextRestoreGState(context);
        }
    } else {
        [self drawInRect:drawRect];
    }
}

- (nullable UIImage *)sd_resizedImageWithSize:(CGSize)size scaleMode:(SDImageScaleMode)scaleMode {
    if (size.width <= 0 || size.height <= 0) return nil;
    SDGraphicsImageRendererFormat *format = [[SDGraphicsImageRendererFormat alloc] init];
    format.scale = self.scale;
    SDGraphicsImageRenderer *renderer = [[SDGraphicsImageRenderer alloc] initWithSize:size format:format];
    UIImage *image = [renderer imageWithActions:^(CGContextRef  _Nonnull context) {
        [self sd_drawInRect:CGRectMake(0, 0, size.width, size.height) context:context scaleMode:scaleMode clipsToBounds:NO];
    }];
    return image;
}

- (nullable UIImage *)sd_croppedImageWithRect:(CGRect)rect {
    rect.origin.x *= self.scale;
    rect.origin.y *= self.scale;
    rect.size.width *= self.scale;
    rect.size.height *= self.scale;
    if (rect.size.width <= 0 || rect.size.height <= 0) return nil;
    
#if SD_UIKIT || SD_MAC
    // CIImage shortcut
    if (self.CIImage) {
        CGRect croppingRect = CGRectMake(rect.origin.x, self.size.height - CGRectGetMaxY(rect), rect.size.width, rect.size.height);
        CIImage *ciImage = [self.CIImage imageByCroppingToRect:croppingRect];
#if SD_UIKIT
        UIImage *image = [UIImage imageWithCIImage:ciImage scale:self.scale orientation:self.imageOrientation];
#else
        UIImage *image = [[UIImage alloc] initWithCIImage:ciImage scale:self.scale orientation:kCGImagePropertyOrientationUp];
#endif
        return image;
    }
#endif
    
    CGImageRef imageRef = self.CGImage;
    if (!imageRef) {
        return nil;
    }
    
    //CGImageCreateWithImageInRect 是 Core Graphics 框架中的一个函数，用于从另一个 CGImage 中创建一个新的图像，该图像是原始图像中指定矩形区域的副本
    CGImageRef croppedImageRef = CGImageCreateWithImageInRect(imageRef, rect);
    if (!croppedImageRef) {
        return nil;
    }
#if SD_UIKIT || SD_WATCH
    UIImage *image = [UIImage imageWithCGImage:croppedImageRef scale:self.scale orientation:self.imageOrientation];
#else
    UIImage *image = [[UIImage alloc] initWithCGImage:croppedImageRef scale:self.scale orientation:kCGImagePropertyOrientationUp];
#endif
    CGImageRelease(croppedImageRef);
    return image;
}

- (nullable UIImage *)sd_roundedCornerImageWithRadius:(CGFloat)cornerRadius corners:(SDRectCorner)corners borderWidth:(CGFloat)borderWidth borderColor:(nullable UIColor *)borderColor {
    //SDGraphicsImageRendererFormat 是 SDWebImage 中的一个类，用于配置 SDGraphicsImageRenderer 的渲染格式。
    //SDGraphicsImageRenderer 用于在指定大小和配置的上下文中渲染图像
    SDGraphicsImageRendererFormat *format = [[SDGraphicsImageRendererFormat alloc] init];
    //scale 属性表示图像渲染的缩放因子。缩放因子用于指定上下文的缩放级别，从而影响渲染的图像质量和精度。
    format.scale = self.scale;
    
    //SDGraphicsImageRenderer 是 SDWebImage 中的一个类，用于在指定的上下文中执行图像渲染操作。
    //它提供了一个简单的接口，使开发者能够方便地创建和执行图形绘制操作，生成最终的图像
    SDGraphicsImageRenderer *renderer = [[SDGraphicsImageRenderer alloc] initWithSize:self.size format:format];
    UIImage *image = [renderer imageWithActions:^(CGContextRef  _Nonnull context) {
        CGRect rect = CGRectMake(0, 0, self.size.width, self.size.height);
        
        CGFloat minSize = MIN(self.size.width, self.size.height);
        if (borderWidth < minSize / 2) {
#if SD_UIKIT || SD_WATCH
            UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(rect, borderWidth, borderWidth) byRoundingCorners:corners cornerRadii:CGSizeMake(cornerRadius, cornerRadius)];
#else
            NSBezierPath *path = [NSBezierPath sd_bezierPathWithRoundedRect:CGRectInset(rect, borderWidth, borderWidth) byRoundingCorners:corners cornerRadius:cornerRadius];
#endif
            [path closePath];
            
            //CGContextSaveGState 是 Core Graphics 框架中的一个函数，用于保存图形上下文的当前图形状态（graphics state）。这个函数会将当前图形状态压入图形状态堆栈，以便稍后通过 CGContextRestoreGState 来还原这个状态。
            CGContextSaveGState(context);
            //addClip用于将当前图形上下文的剪裁区域（clipping area）修改为指定的路径区域。这意味着在调用 addClip 之后，只有位于指定路径区域内的绘制内容会被保留，超出该区域的内容将被裁剪掉
            [path addClip];
            [self drawInRect:rect];
            CGContextRestoreGState(context);
        }
        
        if (borderColor && borderWidth < minSize / 2 && borderWidth > 0) {
            CGFloat strokeInset = (floor(borderWidth * self.scale) + 0.5) / self.scale;
            CGRect strokeRect = CGRectInset(rect, strokeInset, strokeInset);
            CGFloat strokeRadius = cornerRadius > self.scale / 2 ? cornerRadius - self.scale / 2 : 0;
#if SD_UIKIT || SD_WATCH
            UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:strokeRect byRoundingCorners:corners cornerRadii:CGSizeMake(strokeRadius, strokeRadius)];
#else
            NSBezierPath *path = [NSBezierPath sd_bezierPathWithRoundedRect:strokeRect byRoundingCorners:corners cornerRadius:strokeRadius];
#endif
            [path closePath];
            
            path.lineWidth = borderWidth;
            [borderColor setStroke];
            [path stroke];
        }
    }];
    return image;
}

///旋转变换、改变大小图片
- (nullable UIImage *)sd_rotatedImageWithAngle:(CGFloat)angle fitSize:(BOOL)fitSize {
    size_t width = self.size.width;
    size_t height = self.size.height;
    
    // 用于将矩形按照指定的仿射变换矩阵进行变换。这个函数可以帮助你计算矩形在应用变换后的新位置和大小。
    // CGAffineTransformMakeRotation 是 Core Graphics 框架中的一个函数，用于创建一个表示旋转变换的仿射矩阵
    CGRect newRect = CGRectApplyAffineTransform(CGRectMake(0, 0, width, height),
                                                fitSize ? CGAffineTransformMakeRotation(angle) : CGAffineTransformIdentity);

#if SD_UIKIT || SD_MAC
    // CIImage shortcut
    if (self.CIImage) {
        CIImage *ciImage = self.CIImage;
        if (fitSize) {
            //CGAffineTransformMakeRotation 用于创建一个旋转矩阵，rotationAngle 表示旋转的角度，这里是45度。rotationTransform 就是表示这个旋转变换的矩阵。
            CGAffineTransform transform = CGAffineTransformMakeRotation(angle);
            //imageByApplyingTransform 是 Core Graphics 框架中的一个方法，用于在 Core Image 中对图像应用仿射变换。这个方法属于 CIImage 类，而不是直接属于 Core Graphics。
            ciImage = [ciImage imageByApplyingTransform:transform];
        } else {
            //CIFilter 是 Core Image 框架中的一个类，表示图像处理滤镜。滤镜可以用于执行各种图像操作、增强或修改
            //使用 Core Image 框架中的 CIFilter 类创建一个名为 "CIStraightenFilter" 的滤镜实例
            //CIStraightenFilter 是 Core Image 中的一个特定滤镜，用于使图像变直。它接受输入图像和一个角度参数，然后输出经过直线变换后的图像。
            CIFilter *filter = [CIFilter filterWithName:@"CIStraightenFilter"];
            //设置输入图像
            [filter setValue:ciImage forKey:kCIInputImageKey];
            //设置直线变换的角度
            [filter setValue:@(angle) forKey:kCIInputAngleKey];
            //应用滤镜并获取输出图像
            ciImage = filter.outputImage;
        }
#if SD_UIKIT || SD_WATCH
        UIImage *image = [UIImage imageWithCIImage:ciImage scale:self.scale orientation:self.imageOrientation];
#else
        UIImage *image = [[UIImage alloc] initWithCIImage:ciImage scale:self.scale orientation:kCGImagePropertyOrientationUp];
#endif
        return image;
    }
#endif
    
    SDGraphicsImageRendererFormat *format = [[SDGraphicsImageRendererFormat alloc] init];
    format.scale = self.scale;
    SDGraphicsImageRenderer *renderer = [[SDGraphicsImageRenderer alloc] initWithSize:newRect.size format:format];
    UIImage *image = [renderer imageWithActions:^(CGContextRef  _Nonnull context) {
        //设置是否应启用抗锯齿
        CGContextSetShouldAntialias(context, true);
        
        //设置是否允许抗锯齿
        CGContextSetAllowsAntialiasing(context, true);
        
        //设置图形上下文的插值质量，影响图像的缩放和变换过程中的插值算法。kCGInterpolationHigh 表示使用高质量的插值算法，以获得更平滑的缩放效果
        CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
       
        //通过调整图形上下文的坐标系统，将坐标原点平移到 newRect 的中心。这是通过平移坐标变换矩阵（CTM）来实现的
        CGContextTranslateCTM(context, +(newRect.size.width * 0.5), +(newRect.size.height * 0.5));
        
//这里的条件编译部分（#if SD_UIKIT || SD_WATCH）表明这段代码可能与 UIKit 或 WatchKit 相关。在 UIKit 中，坐标系统是逆时针方向的，因此下面的旋转会使用 UIKit 的坐标系
#if SD_UIKIT || SD_WATCH
        // Use UIKit coordinate system counterclockwise (⟲)
        //通过旋转坐标变换矩阵（CTM），对绘制进行旋转。旋转的角度是 -angle，负号表示逆时针旋转。具体的旋转方向和角度可能与 UIKit 坐标系相关，因为在 UIKit 中，逆时针方向是正方向
        CGContextRotateCTM(context, -angle);
#else
        CGContextRotateCTM(context, angle);
#endif
        
        [self drawInRect:CGRectMake(-(width * 0.5), -(height * 0.5), width, height)];
    }];
    return image;
}

- (nullable UIImage *)sd_flippedImageWithHorizontal:(BOOL)horizontal vertical:(BOOL)vertical {
    size_t width = self.size.width;
    size_t height = self.size.height;

#if SD_UIKIT || SD_MAC
    // CIImage shortcut
    if (self.CIImage) {
        // CGAffineTransformIdentity 是 Core Graphics 框架中的一个常量，表示一个不进行任何变换的仿射矩阵。这个矩阵是一个特殊的矩阵，当应用于图形上下文或视图的变换时，不会对图形产生任何影响，即图形保持原样
        CGAffineTransform transform = CGAffineTransformIdentity;
        // Use UIKit coordinate system
        if (horizontal) {
            //// 创建一个水平翻转的仿射变换矩阵
            CGAffineTransform flipHorizontal = CGAffineTransformMake(-1, 0, 0, 1, width, 0);
            //// 将水平翻转矩阵与现有的变换矩阵连接在一起
            transform = CGAffineTransformConcat(transform, flipHorizontal);
        }
        if (vertical) {
            CGAffineTransform flipVertical = CGAffineTransformMake(1, 0, 0, -1, 0, height);
            transform = CGAffineTransformConcat(transform, flipVertical);
        }
        //对该图像应用了一个仿射变换，变换矩阵为 transform
        CIImage *ciImage = [self.CIImage imageByApplyingTransform:transform];
#if SD_UIKIT
        //将 CIImage 对象 ciImage 转换为一个 UIImage 对象，同时指定了缩放因子和方向信息。这在 Core Image 和 UIKit 之间进行图像处理和显示时很常见
        UIImage *image = [UIImage imageWithCIImage:ciImage scale:self.scale orientation:self.imageOrientation];
#else
        UIImage *image = [[UIImage alloc] initWithCIImage:ciImage scale:self.scale orientation:kCGImagePropertyOrientationUp];
#endif
        return image;
    }
#endif
    
    SDGraphicsImageRendererFormat *format = [[SDGraphicsImageRendererFormat alloc] init];
    format.scale = self.scale;
    SDGraphicsImageRenderer *renderer = [[SDGraphicsImageRenderer alloc] initWithSize:self.size format:format];
    UIImage *image = [renderer imageWithActions:^(CGContextRef  _Nonnull context) {
        // Use UIKit coordinate system
        if (horizontal) {
            CGAffineTransform flipHorizontal = CGAffineTransformMake(-1, 0, 0, 1, width, 0);
            CGContextConcatCTM(context, flipHorizontal);
        }
        if (vertical) {
            CGAffineTransform flipVertical = CGAffineTransformMake(1, 0, 0, -1, 0, height);
            CGContextConcatCTM(context, flipVertical);
        }
        [self drawInRect:CGRectMake(0, 0, width, height)];
    }];
    return image;
}

#pragma mark - Image Blending

- (nullable UIImage *)sd_tintedImageWithColor:(nonnull UIColor *)tintColor {
    //判断指定颜色 tintColor 是否具有透明度（alpha 值是否大于零），并将结果存储在 BOOL 类型的变量 hasTint 中
    //__FLT_EPSILON__ 是一个浮点数常量，表示浮点数精度的最小正数。在这里，它用于作为一个很小的阈值，用来判断颜色的 alpha 值是否大于零
    BOOL hasTint = CGColorGetAlpha(tintColor.CGColor) > __FLT_EPSILON__;
    if (!hasTint) {
        return self;
    }
    
#if SD_UIKIT || SD_MAC
    //这段代码使用 Core Image 框架和 UIKit（或 Core Graphics）创建一个新的 UIImage 对象。它通过将两个 CIImage 进行合成和裁剪，然后将结果转换为 UIImage 对象
    // CIImage shortcut
    if (self.CIImage) {
        CIImage *ciImage = self.CIImage;
        //使用 tintColor 创建一个纯色的 CIImage 对象，用于表示颜色图像
        CIImage *colorImage = [CIImage imageWithColor:[[CIColor alloc] initWithColor:tintColor]];
        //将纯色图像裁剪为与原始图像相同的大小，确保两个图像的大小一致
        colorImage = [colorImage imageByCroppingToRect:ciImage.extent];
        //创建一个合成滤镜，使用 CISourceAtopCompositing 滤镜将两个图像合成在一起
        CIFilter *filter = [CIFilter filterWithName:@"CISourceAtopCompositing"];
        //将颜色图像和原始图像分别设置为滤镜的输入图像和背景图像
        [filter setValue:colorImage forKey:kCIInputImageKey];
        [filter setValue:ciImage forKey:kCIInputBackgroundImageKey];
        //获取滤镜处理后的输出图像，并将其赋值给 ciImage。
        ciImage = filter.outputImage;
#if SD_UIKIT
        //使用前面处理后的 ciImage，并设置适当的缩放因子和方向
        UIImage *image = [UIImage imageWithCIImage:ciImage scale:self.scale orientation:self.imageOrientation];
#else
        UIImage *image = [[UIImage alloc] initWithCIImage:ciImage scale:self.scale orientation:kCGImagePropertyOrientationUp];
#endif
        return image;
    }
#endif
    
    CGSize size = self.size;
    CGRect rect = { CGPointZero, size };
    CGFloat scale = self.scale;
    
    // blend mode, see https://en.wikipedia.org/wiki/Alpha_compositing
    //CGBlendMode 是 Core Graphics 框架中表示图形混合模式的枚举类型
    //kCGBlendModeSourceAtop 是 CGBlendMode 中的一个混合模式，表示源图形仅在目标图形的上方绘制，且仅在目标图形的不透明部分。这种模式常用于将一个图像放置在另一个图像的上方，但仅覆盖目标图形的不透明部分。
    //这个混合模式在图形处理中常用于各种合成效果的实现，可以通过设置这个混合模式来影响绘制操作的效果。在这个特定的情况下，kCGBlendModeSourceAtop 会影响到之后的图形绘制，具体的效果会依赖于之后的绘制操作和颜色信息。
    CGBlendMode blendMode = kCGBlendModeSourceAtop;
    
    SDGraphicsImageRendererFormat *format = [[SDGraphicsImageRendererFormat alloc] init];
    format.scale = scale;
    SDGraphicsImageRenderer *renderer = [[SDGraphicsImageRenderer alloc] initWithSize:size format:format];
    UIImage *image = [renderer imageWithActions:^(CGContextRef  _Nonnull context) {
        [self drawInRect:rect];
        //设置图形上下文的混合模式。blendMode 是一个 CGBlendMode 枚举类型，它控制了图形的混合方式。在这里，blendMode 的值是之前设置的 kCGBlendModeSourceAtop，表示源图形仅在目标图形的上方绘制，且仅在目标图形的不透明部分
        CGContextSetBlendMode(context, blendMode);
        //设置绘制的填充颜色。
        CGContextSetFillColorWithColor(context, tintColor.CGColor);
        //使用当前的填充颜色和混合模式，在图形上下文中绘制一个矩形。rect 是一个 CGRect 类型的参数，表示要绘制的矩形
        CGContextFillRect(context, rect);
    }];
    return image;
}

//作用是获取图像指定点的颜色
- (nullable UIColor *)sd_colorAtPoint:(CGPoint)point {
    CGImageRef imageRef = NULL;
    // CIImage compatible
#if SD_UIKIT || SD_MAC
    if (self.CIImage) {
        imageRef = SDCreateCGImageFromCIImage(self.CIImage);
    }
#endif
    if (!imageRef) {
        imageRef = self.CGImage;
        CGImageRetain(imageRef);
    }
    if (!imageRef) {
        return nil;
    }
    
    // Check point
    CGFloat width = CGImageGetWidth(imageRef);
    CGFloat height = CGImageGetHeight(imageRef);
    if (point.x < 0 || point.y < 0 || point.x >= width || point.y >= height) {
        CGImageRelease(imageRef);
        return nil;
    }
    
    // Get pixels
    //获取这个图片的数据源
    CGDataProviderRef provider = CGImageGetDataProvider(imageRef);
    if (!provider) {
        CGImageRelease(imageRef);
        return nil;
    }
    //从数据源获取直接解码的数据
    CFDataRef data = CGDataProviderCopyData(provider);
    if (!data) {
        CGImageRelease(imageRef);
        return nil;
    }
    
    // Get pixel at point
    size_t bytesPerRow = CGImageGetBytesPerRow(imageRef);
    size_t components = CGImageGetBitsPerPixel(imageRef) / CGImageGetBitsPerComponent(imageRef);
    CGBitmapInfo bitmapInfo = CGImageGetBitmapInfo(imageRef);
    
    CFRange range = CFRangeMake(bytesPerRow * point.y + components * point.x, 4);
    if (CFDataGetLength(data) < range.location + range.length) {
        CFRelease(data);
        CGImageRelease(imageRef);
        return nil;
    }
    Pixel_8888 pixel = {0};
    CFDataGetBytes(data, range, pixel);
    CFRelease(data);
    CGImageRelease(imageRef);
    // Convert to color
    return SDGetColorFromPixel(pixel, bitmapInfo);
}

///获取图像指定矩形区域内的所有颜色，并以 UIColor 数组的形式返回
- (nullable NSArray<UIColor *> *)sd_colorsWithRect:(CGRect)rect {
    CGImageRef imageRef = NULL;
    // CIImage compatible
#if SD_UIKIT || SD_MAC
    if (self.CIImage) {
        imageRef = SDCreateCGImageFromCIImage(self.CIImage);
    }
#endif
    if (!imageRef) {
        imageRef = self.CGImage;
        CGImageRetain(imageRef);
    }
    if (!imageRef) {
        return nil;
    }
    
    // Check rect
    CGFloat width = CGImageGetWidth(imageRef);
    CGFloat height = CGImageGetHeight(imageRef);
    if (CGRectGetWidth(rect) <= 0 || CGRectGetHeight(rect) <= 0 || CGRectGetMinX(rect) < 0 || CGRectGetMinY(rect) < 0 || CGRectGetMaxX(rect) > width || CGRectGetMaxY(rect) > height) {
        CGImageRelease(imageRef);
        return nil;
    }
    
    // Get pixels
    //获取这个图片的数据源
    CGDataProviderRef provider = CGImageGetDataProvider(imageRef);
    if (!provider) {
        CGImageRelease(imageRef);
        return nil;
    }
    //从数据源获取直接解码的数据
    CFDataRef data = CGDataProviderCopyData(provider);
    if (!data) {
        CGImageRelease(imageRef);
        return nil;
    }
    
    // Get pixels with rect
    size_t bytesPerRow = CGImageGetBytesPerRow(imageRef);
    size_t components = CGImageGetBitsPerPixel(imageRef) / CGImageGetBitsPerComponent(imageRef);
    
    size_t start = bytesPerRow * CGRectGetMinY(rect) + components * CGRectGetMinX(rect);
    size_t end = bytesPerRow * (CGRectGetMaxY(rect) - 1) + components * CGRectGetMaxX(rect);
    if (CFDataGetLength(data) < (CFIndex)end) {
        CFRelease(data);
        CGImageRelease(imageRef);
        return nil;
    }
    
    const UInt8 *pixels = CFDataGetBytePtr(data);
    size_t row = CGRectGetMinY(rect);
    size_t col = CGRectGetMaxX(rect);
    
    // Convert to color
    CGBitmapInfo bitmapInfo = CGImageGetBitmapInfo(imageRef);
    NSMutableArray<UIColor *> *colors = [NSMutableArray arrayWithCapacity:CGRectGetWidth(rect) * CGRectGetHeight(rect)];
    for (size_t index = start; index < end; index += 4) {
        if (index >= row * bytesPerRow + col * components) {
            // Index beyond the end of current row, go next row
            row++;
            index = row * bytesPerRow + CGRectGetMinX(rect) * components;
            index -= 4;
            continue;
        }
        Pixel_8888 pixel = {pixels[index], pixels[index+1], pixels[index+2], pixels[index+3]};
        UIColor *color = SDGetColorFromPixel(pixel, bitmapInfo);
        [colors addObject:color];
    }
    CFRelease(data);
    CGImageRelease(imageRef);
    
    return [colors copy];
}

#pragma mark - Image Effect

// We use vImage to do box convolve for performance and support for watchOS. However, you can just use `CIFilter.CIGaussianBlur`. For other blur effect, use any filter in `CICategoryBlur`
///生成一个具有指定模糊半径的模糊图像
- (nullable UIImage *)sd_blurredImageWithRadius:(CGFloat)blurRadius {
    if (self.size.width < 1 || self.size.height < 1) {
        return nil;
    }
    BOOL hasBlur = blurRadius > __FLT_EPSILON__;
    if (!hasBlur) {
        return self;
    }
    
    CGFloat scale = self.scale;
    CGFloat inputRadius = blurRadius * scale;
#if SD_UIKIT || SD_MAC
    if (self.CIImage) {
        CIFilter *filter = [CIFilter filterWithName:@"CIGaussianBlur"];
        [filter setValue:self.CIImage forKey:kCIInputImageKey];
        [filter setValue:@(inputRadius) forKey:kCIInputRadiusKey];
        CIImage *ciImage = filter.outputImage;
        ciImage = [ciImage imageByCroppingToRect:CGRectMake(0, 0, self.size.width, self.size.height)];
#if SD_UIKIT
        UIImage *image = [UIImage imageWithCIImage:ciImage scale:self.scale orientation:self.imageOrientation];
#else
        UIImage *image = [[UIImage alloc] initWithCIImage:ciImage scale:self.scale orientation:kCGImagePropertyOrientationUp];
#endif
        return image;
    }
#endif
    
    CGImageRef imageRef = self.CGImage;
    
    //convert to BGRA if it isn't
    if (CGImageGetBitsPerPixel(imageRef) != 32 ||
        CGImageGetBitsPerComponent(imageRef) != 8 ||
        !((CGImageGetBitmapInfo(imageRef) & kCGBitmapAlphaInfoMask))) {
        SDGraphicsBeginImageContextWithOptions(self.size, NO, self.scale);
        [self drawInRect:CGRectMake(0, 0, self.size.width, self.size.height)];
        imageRef = SDGraphicsGetImageFromCurrentImageContext().CGImage;
        SDGraphicsEndImageContext();
    }
    
    vImage_Buffer effect = {}, scratch = {};
    vImage_Buffer *input = NULL, *output = NULL;
    
    vImage_CGImageFormat format = {
        .bitsPerComponent = 8,
        .bitsPerPixel = 32,
        .colorSpace = NULL,
        .bitmapInfo = kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host, //requests a BGRA buffer.
        .version = 0,
        .decode = NULL,
        .renderingIntent = kCGRenderingIntentDefault
    };
    
    vImage_Error err;
    err = vImageBuffer_InitWithCGImage(&effect, &format, NULL, imageRef, kvImageNoFlags);
    if (err != kvImageNoError) {
        NSLog(@"UIImage+Transform error: vImageBuffer_InitWithCGImage returned error code %zi for inputImage: %@", err, self);
        return nil;
    }
    err = vImageBuffer_Init(&scratch, effect.height, effect.width, format.bitsPerPixel, kvImageNoFlags);
    if (err != kvImageNoError) {
        NSLog(@"UIImage+Transform error: vImageBuffer_Init returned error code %zi for inputImage: %@", err, self);
        return nil;
    }
    
    input = &effect;
    output = &scratch;
    
    if (hasBlur) {
        // A description of how to compute the box kernel width from the Gaussian
        // radius (aka standard deviation) appears in the SVG spec:
        // http://www.w3.org/TR/SVG/filters.html#feGaussianBlurElement
        //
        // For larger values of 's' (s >= 2.0), an approximation can be used: Three
        // successive box-blurs build a piece-wise quadratic convolution kernel, which
        // approximates the Gaussian kernel to within roughly 3%.
        //
        // let d = floor(s * 3*sqrt(2*pi)/4 + 0.5)
        //
        // ... if d is odd, use three box-blurs of size 'd', centered on the output pixel.
        //
        if (inputRadius - 2.0 < __FLT_EPSILON__) inputRadius = 2.0;
        uint32_t radius = floor(inputRadius * 3.0 * sqrt(2 * M_PI) / 4 + 0.5);
        radius |= 1; // force radius to be odd so that the three box-blur methodology works.
        int iterations;
        if (blurRadius * scale < 0.5) iterations = 1;
        else if (blurRadius * scale < 1.5) iterations = 2;
        else iterations = 3;
        NSInteger tempSize = vImageBoxConvolve_ARGB8888(input, output, NULL, 0, 0, radius, radius, NULL, kvImageGetTempBufferSize | kvImageEdgeExtend);
        void *temp = malloc(tempSize);
        for (int i = 0; i < iterations; i++) {
            vImageBoxConvolve_ARGB8888(input, output, temp, 0, 0, radius, radius, NULL, kvImageEdgeExtend);
            vImage_Buffer *tmp = input;
            input = output;
            output = tmp;
        }
        free(temp);
    }
    
    CGImageRef effectCGImage = NULL;
    effectCGImage = vImageCreateCGImageFromBuffer(input, &format, NULL, NULL, kvImageNoAllocate, NULL);
    if (effectCGImage == NULL) {
        effectCGImage = vImageCreateCGImageFromBuffer(input, &format, NULL, NULL, kvImageNoFlags, NULL);
        free(input->data);
    }
    free(output->data);
#if SD_UIKIT || SD_WATCH
    UIImage *outputImage = [UIImage imageWithCGImage:effectCGImage scale:self.scale orientation:self.imageOrientation];
#else
    UIImage *outputImage = [[UIImage alloc] initWithCGImage:effectCGImage scale:self.scale orientation:kCGImagePropertyOrientationUp];
#endif
    CGImageRelease(effectCGImage);
    
    return outputImage;
}

#if SD_UIKIT || SD_MAC
- (nullable UIImage *)sd_filteredImageWithFilter:(nonnull CIFilter *)filter {
    CIImage *inputImage;
    if (self.CIImage) {
        inputImage = self.CIImage;
    } else {
        CGImageRef imageRef = self.CGImage;
        if (!imageRef) {
            return nil;
        }
        inputImage = [CIImage imageWithCGImage:imageRef];
    }
    if (!inputImage) return nil;
    
    CIContext *context = [CIContext context];
    [filter setValue:inputImage forKey:kCIInputImageKey];
    CIImage *outputImage = filter.outputImage;
    if (!outputImage) return nil;
    
    CGImageRef imageRef = [context createCGImage:outputImage fromRect:outputImage.extent];
    if (!imageRef) return nil;
    
#if SD_UIKIT
    UIImage *image = [UIImage imageWithCGImage:imageRef scale:self.scale orientation:self.imageOrientation];
#else
    UIImage *image = [[UIImage alloc] initWithCGImage:imageRef scale:self.scale orientation:kCGImagePropertyOrientationUp];
#endif
    CGImageRelease(imageRef);
    
    return image;
}
#endif

@end
