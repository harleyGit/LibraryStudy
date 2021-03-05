//
//  UIImage+ImageOperation.h
//  ImageLoadSDK
//
//  Created by Harley Huang on 27/11/2020.
//

#import <UIKit/UIKit.h>


@protocol ImageOperation <NSObject>

- (void)cancelOperation;

@end


NS_ASSUME_NONNULL_BEGIN

@interface UIView (ImageOperation)


- (void)setOperation:(id<ImageOperation>)operation forKey:(nullable NSString *)key;

- (void)cancelOperationForKey:(nullable NSString *)key;

- (void)removeOperationForKey:(nullable NSString *)key;


@end

NS_ASSUME_NONNULL_END
