// UIKit+AFNetworking.h
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

/**
 * TargetConditionals.h 是一个包含在 macOS 和 iOS 等 Apple 平台上的头文件，用于提供一些宏和条件编译的相关定义，以便在编写跨平台的代码时进行条件判断。这个头文件定义了一系列用于判断目标平台和体系结构的宏。
 
 在这个头文件中，有一些常见的宏定义，如 TARGET_OS_IPHONE、TARGET_OS_MAC、TARGET_OS_IOS、TARGET_OS_TV 等，它们用于标识当前代码所编译的目标平台。

 例如，TARGET_OS_IPHONE 是在 iOS 设备上编译时定义的，而 TARGET_OS_MAC 是在 macOS 上编译时定义的。通过检查这些宏，可以在代码中执行与平台相关的条件编译，使得相同的源代码在不同的平台上可以有不同的实现。

 一些常见的 TargetConditionals.h 中的宏：

 TARGET_OS_MAC：表示目标平台是 macOS。
 TARGET_OS_IPHONE：表示目标平台是 iOS。
 TARGET_OS_IOS：表示目标平台是 iOS。
 TARGET_OS_TV：表示目标平台是 tvOS。
 TARGET_OS_WATCH：表示目标平台是 watchOS。
 通过使用这些宏，开发者可以根据目标平台的不同来选择性地包含或排除某些代码，以满足不同平台的特定需求。
 */
//引入 TargetConditionals 头文件的预处理指令，用于根据目标平台（iOS、macOS、tvOS 等）进行条件编译
#import <TargetConditionals.h>

#ifndef _UIKIT_AFNETWORKING_ //这是一个条件编译指令，表示如果 _UIKIT_AFNETWORKING_ 未定义（即没有被之前的代码或其他地方定义过），则执行以下的导入操作。
    #define _UIKIT_AFNETWORKING_ //在进入条件编译块之前，定义了一个宏 _UIKIT_AFNETWORKING_，以防止在同一编译单元中多次导入

#if TARGET_OS_IOS || TARGET_OS_TV
    #import "AFAutoPurgingImageCache.h"
    #import "AFImageDownloader.h"
    #import "UIActivityIndicatorView+AFNetworking.h"
    #import "UIButton+AFNetworking.h"
    #import "UIImageView+AFNetworking.h"
    #import "UIProgressView+AFNetworking.h"
#endif

#if TARGET_OS_IOS
    #import "AFNetworkActivityIndicatorManager.h"
    #import "UIRefreshControl+AFNetworking.h"
    #import "WKWebView+AFNetworking.h"
#endif

#endif /* _UIKIT_AFNETWORKING_ */
