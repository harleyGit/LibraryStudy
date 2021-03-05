//
//  ImageDownloadOperation.h
//  ImageLoadSDK
//
//  Created by Harley Huang on 27/11/2020.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "ImageManager.h"


NS_ASSUME_NONNULL_BEGIN

typedef void(^ImageDownloadProgressBlock)(NSInteger receivedSize, NSInteger expectedSize, NSURL *_Nullable targetURL);

typedef void(^ImageDownloadCompletionBlock)(UIImage *_Nullable image, NSData *_Nullable imageData, NSError *_Nullable error, BOOL finished);

@interface ImageDownloadOperation : NSOperation


- (instancetype)initWithRequest:(NSURLRequest *)request options:(ImageOptions)options;

- (id)addProgressHandler:(ImageDownloadProgressBlock)progressBlock withCompletionBlock:(ImageDownloadCompletionBlock)completionBlock;

- (BOOL)cancelWithToken:(id)token;

@end

NS_ASSUME_NONNULL_END
