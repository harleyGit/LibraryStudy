//
//  UIImage+ImageGIF.h
//  ImageLoadSDK
//
//  Created by Harley Huang on 27/11/2020.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIImage (ImageGIF)

@property (nonatomic, copy) NSArray<UIImage *> *images;
@property (nonatomic, assign) NSInteger loopCount;
@property (nonatomic, copy) NSArray<NSNumber *> *delayTimes;
@property (nonatomic, assign) NSTimeInterval totalTimes;

@end

NS_ASSUME_NONNULL_END
