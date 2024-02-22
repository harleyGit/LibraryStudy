// UIRefreshControl+AFNetworking.m
//
// Copyright (c) 2011–2016 Alamofire Software Foundation ( http://alamofire.org/ )
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import <Foundation/Foundation.h>

#import <TargetConditionals.h>

#if TARGET_OS_IOS

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 This category adds methods to the UIKit framework's `UIRefreshControl` class. The methods in this category provide support for automatically beginning and ending refreshing depending on the loading state of a session task.
 * UIRefreshControl 是 iOS 中的一个用户界面控件，通常用于在 UIScrollView（比如 UITableView 或 UICollectionView）中添加下拉刷新功能。下拉刷新是指用户可以通过下拉内容视图，触发刷新操作，以更新显示的数据
 */
@interface UIRefreshControl (AFNetworking)

///-----------------------------------
/// @name Refreshing for Session Tasks
///-----------------------------------

/**
 Binds the refreshing state to the state of the specified task.
 
 @param task The task. If `nil`, automatic updating from any previously specified operation will be disabled.
 */
- (void)setRefreshingWithStateOfTask:(NSURLSessionTask *)task;

@end

NS_ASSUME_NONNULL_END

#endif
