//
//  ImageCoderHelper.h
//  ImageLoadSDK
//
//  Created by Harley Huang on 27/11/2020.
//

#import <Foundation/Foundation.h>
#import "UIImage+ImageFormat.h"

NS_ASSUME_NONNULL_BEGIN

@interface ImageCoderHelper : NSObject

+ (ImageFormat)imageFormatWithData:(NSData *)data;

+ (UIImageOrientation)imageOrientationFromEXIFOrientation:(NSInteger)exifOrientation;

@end

NS_ASSUME_NONNULL_END
