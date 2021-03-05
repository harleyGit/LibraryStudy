//
//  ImageProgressiveCoder.h
//  ImageLoadSDK
//
//  Created by Harley Huang on 27/11/2020.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ImageProgressiveCoder : NSObject


- (UIImage *)progressiveDecodedImageWithData:(NSData *)data finished:(BOOL)finished;

@end

NS_ASSUME_NONNULL_END
