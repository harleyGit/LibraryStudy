//
//  UIImage+ImageFormat.m
//  ImageLoadSDK
//
//  Created by Harley Huang on 26/11/2020.
//

#import "UIImage+ImageFormat.h"
#import <objc/runtime.h>


FOUNDATION_STATIC_INLINE NSUInteger ImageMemoryCost(UIImage *image){
    NSUInteger imageSize = image.size.width * image.size.height * image.scale;
    return image.images ? imageSize * image.images.count : imageSize;
}

@implementation UIImage (ImageFormat)


- (void)setImages:(NSArray *)images {
    
    //https://www.jianshu.com/p/29fd2359ab08
    objc_setAssociatedObject(self, @selector(images), images, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSArray *)images {
    NSArray *images = objc_getAssociatedObject(self, @selector(images));
    if ([images isKindOfClass:[NSArray class]]) {
        return images;
    }
    return nil;
}

- (void)setImageFormat:(ImageFormat)imageFormat {
    objc_setAssociatedObject(self, @selector(imageFormat), @(imageFormat), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (ImageFormat)imageFormat {
    ImageFormat imageFormat = ImageFormatUndefined;
    NSNumber *value = objc_getAssociatedObject(self, @selector(imageFormat));
    if ([value isKindOfClass:[NSNumber class]]) {
        imageFormat = value.integerValue;
        return imageFormat;
    }
    return imageFormat;
}


//图片角度的处理
//由于拍摄角度和拍摄设备的不同，如果不对图片进行角度处理，那么很有可能出现图片倒过来或侧过来的情况。为了避免这一情况，那么我们在对图片存储时需要将图片“摆正”，然后再存储。
- (UIImage *)normalizedImage {
    if (self.imageOrientation == UIImageOrientationUp) {//图片方向是正确的
        return self;
    }
    UIGraphicsBeginImageContextWithOptions(self.size, NO, self.scale);
    //当图片方向不正确是，利用drawInRect方法对图像进行重新绘制，这样可以保证绘制之后的图片方向是正确的。
    [self drawInRect:CGRectMake(0, 0, self.size.width, self.size.height)];
    UIImage *normalizedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return normalizedImage;
}

- (NSUInteger)memoryCost {
    NSNumber *value = objc_getAssociatedObject(self, @selector(memoryCost));
    if (value) {
        return [value unsignedIntegerValue];
    } else {
        NSUInteger memoryCost = ImageMemoryCost(self);
        [self setMemoryCost:memoryCost];
        return memoryCost;
    }
}

- (void)setMemoryCost:(NSUInteger)memoryCost {
    objc_setAssociatedObject(self, @selector(memoryCost), @(memoryCost), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}



@end
