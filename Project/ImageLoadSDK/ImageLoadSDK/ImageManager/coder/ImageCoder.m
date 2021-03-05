//
//  ImageCoder.m
//  ImageLoadSDK
//
//  Created by Harley Huang on 18/11/2020.
//

#import <MobileCoreServices/MobileCoreServices.h>
#import "ImageCoder.h"
#import "UIImage+ImageFormat.h"
#import "UIImage+ImageGIF.h"
#import "ImageCoderHelper.h"


static const NSTimeInterval kJAnimatedImageDelayTimeIntervalMinimum = 0.02;
static const NSTimeInterval kJAnimatedImageDefaultDelayTimeInterval = 0.1;

//FOUNDATION_EXTERN_INLINE: 声明全局的内联函数
FOUNDATION_EXTERN_INLINE CFStringRef getImageUTType(ImageFormat imageFormat) {
    switch (imageFormat) {
        case ImageFormatPNG:
            return kUTTypePNG;
        case ImageFormatJPEG:
            return kUTTypeJPEG;
        case ImageFormatGIF:
            return kUTTypeGIF;
        default:
            return kUTTypePNG;
    }
}

FOUNDATION_EXTERN_INLINE BOOL CGImageRefContainsAlpha(CGImageRef imageRef) {
    if (!imageRef) {
        return NO;
    }
    //是否有透明度
    CGImageAlphaInfo alphaInfo = CGImageGetAlphaInfo(imageRef);
    BOOL hasAlpha = !(alphaInfo == kCGImageAlphaNone ||
                      alphaInfo == kCGImageAlphaNoneSkipFirst ||
                      alphaInfo == kCGImageAlphaNoneSkipLast);
    return hasAlpha;
}


@interface ImageCoder ()

@property (nonatomic, strong) dispatch_queue_t coderQueue;

@end

@implementation ImageCoder

+ (instancetype)shareCoder {
    static ImageCoder *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[ImageCoder alloc] init];
        [instance setup];
    });
    return instance;
}


- (void)setup {
    self.coderQueue = dispatch_queue_create("com.jimage.coder.queue", DISPATCH_QUEUE_SERIAL);
}


#pragma mark - encode
- (void)encodedDataWithImage:(UIImage *)image WithBlock:(void (^)(NSData * _Nullable))completionBlock {
    dispatch_async(self.coderQueue, ^{
        NSData *data = [self encodedDataSyncWithImage:image];
        completionBlock(data);
    });
}




//图片编码
- (NSData *)encodedDataSyncWithImage:(UIImage *)image {
    if (!image) {
        return nil;
    }
    switch (image.imageFormat) {
        case ImageFormatPNG:
        case ImageFormatJPEG:
            return [self encodedDataWithImage:image imageFormat:image.imageFormat];
            
        case ImageFormatGIF:{
            return [self encodedGIFDataWithImage:image];
        }

        case ImageFormatUndefined:{
            if (CGImageRefContainsAlpha(image.CGImage)) {
                return [self encodedDataWithImage:image imageFormat:ImageFormatPNG];
            } else {
                return [self encodedDataWithImage:image imageFormat:ImageFormatJPEG];
            }
        }
    }
}

//对PNG和JPEG格式图片的处理
- (nullable NSData *)encodedDataWithImage:(UIImage *)image imageFormat:(ImageFormat)imageFormat {
    UIImage *fixedImage = [image normalizedImage];
    //根据不同的图片类型获取到对应的图片data
    if (imageFormat == ImageFormatPNG) {
        return UIImagePNGRepresentation(fixedImage);
    } else {
        return UIImageJPEGRepresentation(fixedImage, 1.0);
    }
}

//NSData转换为image主要是获取loopCount、images和delaytimes，那么我们从image转换为NSData，即反过来，将这些属性写入到数据里即可。
- (nullable NSData *)encodedGIFDataWithImage:(UIImage *)image {
    NSMutableData *gifData = [NSMutableData data];
    
    //指定了图片数据的保存位置、数据类型以及图片的总张数，最后一个参数现需传入 nil
    CGImageDestinationRef imageDestination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)gifData, kUTTypeGIF, image.images.count, NULL);
    if (!imageDestination) {
        return nil;
    }
    if (image.images.count == 0) {
        // 添加图像和元信息
        CGImageDestinationAddImage(imageDestination, image.CGImage, nil);
    } else {
        NSUInteger loopCount = image.loopCount;
        NSDictionary *gifProperties = @{(__bridge NSString *)kCGImagePropertyGIFDictionary : @{(__bridge NSString *)kCGImagePropertyGIFLoopCount : @(loopCount)}};
        //将属性（键值对）的字典（CFDictionaryRef）添加到图像目标中的图像
        CGImageDestinationSetProperties(imageDestination, (__bridge CFDictionaryRef)gifProperties);
        size_t count = MIN(image.images.count, image.delayTimes.count);
        for (size_t i = 0; i < count; i ++) {
            NSDictionary *properties = @{(__bridge NSString *)kCGImagePropertyGIFDictionary : @{(__bridge NSString *)kCGImagePropertyGIFDelayTime : image.images[i]}};
            CGImageDestinationAddImage(imageDestination, image.images[i].CGImage, (__bridge CFDictionaryRef)properties);
        }
    }
    
    //告诉Image I/O我们已经结束添加图像了。一旦结束之后，我们就不能添加任何数据到ImageDestination。
    if (CGImageDestinationFinalize(imageDestination) == NO) {
        gifData = nil;
    }
    CFRelease(imageDestination);
    return [gifData copy];
}



- (UIImage *)decodeImageWithData:(NSData *)data {
    
    ImageFormat format = [self imageFormatWithData:data];
    switch (format) {
        case ImageFormatJPEG:
        case ImageFormatPNG:{
            UIImage *image = [[UIImage alloc] initWithData:data];
            image.imageFormat = format;
            return image;
        }
        case ImageFormatGIF:
            return [self decodeGIFWithData:data];
        default:
            return nil;
    }
}



#pragma mark - decode
- (void)decodeImageWithData:(NSData *)data WithBlock:(void (^)(UIImage * _Nullable))completionBlock {
    dispatch_async(self.coderQueue, ^{
        UIImage *image = [self decodeImageSyncWithData:data];
        completionBlock(image);
    });
}

//图片解码
- (UIImage *)decodeImageSyncWithData:(NSData *)data {
    ImageFormat format = [ImageCoderHelper imageFormatWithData:data];
    switch (format) {
        case ImageFormatJPEG:
        case ImageFormatPNG:{
            UIImage *image = [[UIImage alloc] initWithData:data];
            image.imageFormat = format;
            return image;
        }
        case ImageFormatGIF:
            return [self decodeGIFWithData:data];
        default:
            return nil;
    }
}


- (UIImage *)decodeGIFWithData:(NSData *)data {
    //將GIF圖片轉換成對應的圖片源
    //创建从Core Foundation数据对象读取的图像源:https://www.jianshu.com/p/26e5755b2b64
    //图片信息：https://www.cnblogs.com/YouXianMing/p/3940792.html
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    if (!source) {
        return nil;
    }
    
    //獲取其中圖片源個數，即由多少幀圖片組成
    size_t count = CGImageSourceGetCount(source);
    UIImage *animatedImage;
    if (count <= 1) {
        animatedImage = [[UIImage alloc] initWithData:data];
        animatedImage.imageFormat = ImageFormatGIF;
    } else {
        //獲取循環次數
        NSInteger loopCount = 0;
        CFDictionaryRef properties = CGImageSourceCopyProperties(source, NULL);
        if (properties) {//获取loopcount
            CFDictionaryRef gif = CFDictionaryGetValue(properties, kCGImagePropertyGIFDictionary);
            if (gif) {
                CFTypeRef loop = CFDictionaryGetValue(gif, kCGImagePropertyGIFLoopCount);
                if (loop) {
                    //如果loop == NULL，表示不循環播放，當loopCount  == 0時，表示無限循環；
                    CFNumberGetValue(loop, kCFNumberNSIntegerType, &loopCount);
                }
            }
            CFRelease(properties);
        }

        NSMutableArray<NSNumber *> *delayTimeArray = [NSMutableArray array];//存储每张图片对应的展示时间
        NSMutableArray<UIImage *> *imageArray = [NSMutableArray array];//存储图片
        NSTimeInterval duration = 0;
        for (size_t i = 0; i < count; i ++) {
            CGImageRef imageRef = CGImageSourceCreateImageAtIndex(source, i, NULL);
            if (!imageRef) {
                continue;
            }
            
            //获取图片
            UIImage *image = [[UIImage alloc] initWithCGImage:imageRef];
            [imageArray addObject:image];
            CGImageRelease(imageRef);
            
            //获取delayTime
            float delayTime = kJAnimatedImageDefaultDelayTimeInterval;
            //获取图像的元信息
            CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(source, i, NULL);
            if (properties) {
                //从 CGImageSourceRef 数据源中读到一个帧位的未解码图片数据
                //GIF 的裁剪与展示：https://zhuanlan.zhihu.com/p/31492747
                CFDictionaryRef gif = CFDictionaryGetValue(properties, kCGImagePropertyGIFDictionary);
                NSLog(@"🍎 gif 字典值： %@", gif);
                if (gif) {
                    CFTypeRef value = CFDictionaryGetValue(gif, kCGImagePropertyGIFUnclampedDelayTime);
                    if (!value) {
                        value = CFDictionaryGetValue(gif, kCGImagePropertyGIFDelayTime);
                    }
                    if (value) {
                        CFNumberGetValue(value, kCFNumberFloatType, &delayTime);
                        if (delayTime < ((float)kJAnimatedImageDelayTimeIntervalMinimum - FLT_EPSILON)) {
                            delayTime = kJAnimatedImageDefaultDelayTimeInterval;
                        }
                    }
                }
                CFRelease(properties);
            }
            //gif图片完整周期时长
            duration += delayTime;
            [delayTimeArray addObject:@(delayTime)];
        }
        
        animatedImage = [[UIImage alloc] init];
        animatedImage.imageFormat = ImageFormatGIF;
        animatedImage.images = [imageArray copy];
        animatedImage.delayTimes = [delayTimeArray copy];
        animatedImage.loopCount = loopCount;
        animatedImage.totalTimes = duration;
    }
    CFRelease(source);
    return animatedImage;
}





//根据数据data的第一个字节来判断图片类型
- (ImageFormat)imageFormatWithData:(NSData *)data {
    if (!data) {
        return ImageFormatUndefined;
    }
    uint8_t c;
    [data getBytes:&c length:1];
    switch (c) {
        case 0xFF:
            return ImageFormatJPEG;
        case 0x89:
            return ImageFormatPNG;
        case 0x47:
            return ImageFormatGIF;
        default:
            return ImageFormatUndefined;
    }
}



@end
