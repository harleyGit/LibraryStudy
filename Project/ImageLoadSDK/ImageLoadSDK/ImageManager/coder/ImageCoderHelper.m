//
//  ImageCoderHelper.m
//  ImageLoadSDK
//
//  Created by Harley Huang on 27/11/2020.
//

#import "ImageCoderHelper.h"

@implementation ImageCoderHelper

+ (ImageFormat)imageFormatWithData:(NSData *)data {
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

+ (UIImageOrientation)imageOrientationFromEXIFOrientation:(NSInteger)exifOrientation {
    UIImageOrientation imageOrientation = UIImageOrientationUp;
    switch (exifOrientation) {
        case 1:
            imageOrientation = UIImageOrientationUp;
            break;
        case 3:
            imageOrientation = UIImageOrientationDown;
            break;
        case 8:
            imageOrientation = UIImageOrientationLeft;
            break;
        case 6:
            imageOrientation = UIImageOrientationRight;
            break;
        case 2:
            imageOrientation = UIImageOrientationUpMirrored;
            break;
        case 4:
            imageOrientation = UIImageOrientationDownMirrored;
            break;
        case 5:
            imageOrientation = UIImageOrientationLeftMirrored;
            break;
        case 7:
            imageOrientation = UIImageOrientationRightMirrored;
            break;
        default:
            break;
    }
    return imageOrientation;
}


@end
