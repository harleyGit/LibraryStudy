/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import <Foundation/Foundation.h>
#import "SDWebImageCompat.h"

typedef NSURLRequest * _Nullable (^SDWebImageDownloaderRequestModifierBlock)(NSURLRequest * _Nonnull request);

/**
 This is the protocol for downloader request modifier.
 We can use a block to specify the downloader request modifier. But Using protocol can make this extensible, and allow Swift user to use it easily instead of using `@convention(block)` to store a block into context options.
 
 * 用于自定义修改图像下载请求的行为。这个选项允许开发者提供一个遵循 SDWebImageDownloaderRequestModifier 协议的自定义对象，以在发出图像下载请求之前对请求进行修改
 */
@protocol SDWebImageDownloaderRequestModifier <NSObject>

/// Modify the original URL request and return a new one instead. You can modify the HTTP header, cachePolicy, etc for this URL.
/// @param request The original URL request for image loading
/// @note If return nil, the URL request will be cancelled.
- (nullable NSURLRequest *)modifiedRequestWithRequest:(nonnull NSURLRequest *)request;

@end

/**
 A downloader request modifier class with block.
 */
@interface SDWebImageDownloaderRequestModifier : NSObject <SDWebImageDownloaderRequestModifier>

- (nonnull instancetype)initWithBlock:(nonnull SDWebImageDownloaderRequestModifierBlock)block;
+ (nonnull instancetype)requestModifierWithBlock:(nonnull SDWebImageDownloaderRequestModifierBlock)block;

@end
