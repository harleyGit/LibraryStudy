//
//  UIImage+ImageFormat.h
//  ImageLoadSDK
//
//  Created by Harley Huang on 26/11/2020.
//

#import <UIKit/UIKit.h>

//图片类型枚举
typedef NS_ENUM(NSInteger,ImageFormat) {
    ImageFormatUndefined = -1,
    ImageFormatJPEG = 0,
    ImageFormatPNG = 1,
    ImageFormatGIF = 2,
};



NS_ASSUME_NONNULL_BEGIN

@interface UIImage (ImageFormat)

@property (nonatomic, assign) ImageFormat imageFormat;
@property (nonatomic, assign) NSUInteger memoryCost;
@property (nonatomic, copy) NSArray *images;

- (UIImage *)normalizedImage;

@end

NS_ASSUME_NONNULL_END
