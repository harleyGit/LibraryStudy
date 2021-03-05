//
//  ImageProgressiveCoder.m
//  ImageLoadSDK
//
//  Created by Harley Huang on 27/11/2020.
//

#import "ImageProgressiveCoder.h"
#import "UIImage+ImageFormat.h"
#import "ImageCoderHelper.h"

@implementation ImageProgressiveCoder{
    size_t _width, _height;
    UIImageOrientation _orientation;
    CGImageSourceRef _imageSource;
}

//析购方法
- (void)dealloc {
    if (_imageSource) {
        CFRelease(_imageSource);
        _imageSource = NULL;
    }
}

- (UIImage *)progressiveDecodedImageWithData:(NSData *)data finished:(BOOL)finished {
    
    if (!_imageSource) {
        //创建图片源
        _imageSource = CGImageSourceCreateIncremental(NULL);
    }
    
    UIImage *image;
    //更新图片数据
    CGImageSourceUpdateData(_imageSource, (__bridge CFDataRef)data, finished);
    if (_width + _height == 0) {
        //获取了照片的元数据
        CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(_imageSource, 0, NULL);
        NSLog(@"🍎 照片的元数据: %@", properties);
        if (properties) {
            NSInteger orientationValue = 1;
            //獲取KEY對應的value, 这里 properties 是 Key
            CFTypeRef val = CFDictionaryGetValue(properties, kCGImagePropertyPixelHeight);
            if (val) CFNumberGetValue(val, kCFNumberLongType, &_height);
            val = CFDictionaryGetValue(properties, kCGImagePropertyPixelWidth);
            if (val) CFNumberGetValue(val, kCFNumberLongType, &_width);
            val = CFDictionaryGetValue(properties, kCGImagePropertyOrientation);
            if (val) CFNumberGetValue(val, kCFNumberNSIntegerType, &orientationValue);
            CFRelease(properties);
            _orientation = [ImageCoderHelper imageOrientationFromEXIFOrientation:orientationValue];
        }
    }
    
    if (_width + _height > 0) {
        //创建图片显示
        CGImageRef partialImageRef = CGImageSourceCreateImageAtIndex(_imageSource, 0, NULL);
        if (partialImageRef) {
            image = [[UIImage alloc] initWithCGImage:partialImageRef scale:1 orientation:_orientation];
            CFRelease(partialImageRef);
            image.imageFormat = [ImageCoderHelper imageFormatWithData:data];
        }
    }
    
    if (finished) {
        if (_imageSource) {
            CFRelease(_imageSource);
            _imageSource = NULL;
        }
    }
    return image;
}




@end
