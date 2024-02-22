// WkWebView+AFNetworking.m
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

#import "WKWebView+AFNetworking.h"

#import <objc/runtime.h>

#if TARGET_OS_IOS

#import "AFHTTPSessionManager.h"
#import "AFURLResponseSerialization.h"
#import "AFURLRequestSerialization.h"

@interface WKWebView (_AFNetworking)

//setter=af_setURLSessionTask:: 这是使用自定义的 setter 方法名，将属性的设置方法命名为 af_setURLSessionTask:。默认情况下，编译器会生成一个 setter 方法的名称为 setPropertyName:，但在这里通过指定 setter 选项，我们指定了一个自定义的 setter 方法名
@property (readwrite, nonatomic, strong, setter = af_setURLSessionTask:) NSURLSessionDataTask *af_URLSessionTask;
@end

@implementation WKWebView (_AFNetworking)

- (NSURLSessionDataTask *)af_URLSessionTask {
    // @selector(af_URLSessionTask) 是一个方法选择器,在objc_getAssociatedObject这个方法中.第二个参数必须是一个在编译时可识别的方法选择器，而不是任意的字符串。@selector 是一个编译时指令，它将方法名转换为在运行时唯一的选择器。在 Objective-C 中，选择器是一种特定的数据类型，用于标识方法
    //objc_getAssociatedObject的第二个参数如果你使用一个字符串而不是选择器，例如 @"af_URLSessionTask"，那么它不会被识别为一个选择器，而是一个普通的字符串。在这种情况下，objc_getAssociatedObject 将无法正确地识别关联对象，因为它期望的是一个选择器而不是一个字符串
    return (NSURLSessionDataTask *)objc_getAssociatedObject(self, @selector(af_URLSessionTask));
}

- (void)af_setURLSessionTask:(NSURLSessionDataTask *)af_URLSessionTask {
    objc_setAssociatedObject(self, @selector(af_URLSessionTask), af_URLSessionTask, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

#pragma mark -

@implementation WKWebView (AFNetworking)

- (AFHTTPSessionManager *)sessionManager {
    static AFHTTPSessionManager *_af_defaultHTTPSessionManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _af_defaultHTTPSessionManager = [[AFHTTPSessionManager alloc] initWithSessionConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
        _af_defaultHTTPSessionManager.requestSerializer = [AFHTTPRequestSerializer serializer];
        _af_defaultHTTPSessionManager.responseSerializer = [AFHTTPResponseSerializer serializer];
    });
    
    return objc_getAssociatedObject(self, @selector(sessionManager)) ?: _af_defaultHTTPSessionManager;
}

- (void)setSessionManager:(AFHTTPSessionManager *)sessionManager {
    objc_setAssociatedObject(self, @selector(sessionManager), sessionManager, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (AFHTTPResponseSerializer <AFURLResponseSerialization> *)responseSerializer {
    static AFHTTPResponseSerializer <AFURLResponseSerialization> *_af_defaultResponseSerializer = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _af_defaultResponseSerializer = [AFHTTPResponseSerializer serializer];
    });
    
    return objc_getAssociatedObject(self, @selector(responseSerializer)) ?: _af_defaultResponseSerializer;
}

- (void)setResponseSerializer:(AFHTTPResponseSerializer<AFURLResponseSerialization> *)responseSerializer {
    objc_setAssociatedObject(self, @selector(responseSerializer), responseSerializer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark -

- (void)loadRequest:(NSURLRequest *)request
         navigation:(WKNavigation * _Nonnull)navigation
           progress:(NSProgress * _Nullable __autoreleasing * _Nullable)progress
            success:(nullable NSString * (^)(NSHTTPURLResponse *response, NSString *HTML))success
            failure:(nullable void (^)(NSError *error))failure {
    [self loadRequest:request navigation:navigation MIMEType:nil textEncodingName:nil progress:progress success:^NSData * _Nonnull(NSHTTPURLResponse * _Nonnull response, NSData * _Nonnull data) {
        NSStringEncoding stringEncoding = NSUTF8StringEncoding;
        if (response.textEncodingName) {//将服务器返回的文本编码名称转换为可用于处理字符串的 NSStringEncoding。在处理网络请求时，确保正确的字符编码非常重要，以确保正确地解析和显示文本数据。
            
            //CFStringConvertIANACharSetNameToEncoding((CFStringRef)response.textEncodingName)：将 IANA 字符集名称（例如"UTF-8"、"ISO-8859-1"等）转换为 Core Foundation 中的字符编码
            CFStringEncoding encoding = CFStringConvertIANACharSetNameToEncoding((CFStringRef)response.textEncodingName);
            if (encoding != kCFStringEncodingInvalidId) {
                //转换为对应的 NSStringEncoding
                stringEncoding = CFStringConvertEncodingToNSStringEncoding(encoding);
            }
        }
        
        NSString *string = [[NSString alloc] initWithData:data encoding:stringEncoding];
        if (success) {
            string = success(response, string);
        }
        
        return [string dataUsingEncoding:stringEncoding];
    } failure:failure];
}

- (void)loadRequest:(NSURLRequest *)request
         navigation:(WKNavigation * _Nonnull)navigation
           MIMEType:(nullable NSString *)MIMEType
   textEncodingName:(nullable NSString *)textEncodingName
           progress:(NSProgress * _Nullable __autoreleasing * _Nullable)progress
            success:(nullable NSData * (^)(NSHTTPURLResponse *response, NSData *data))success
            failure:(nullable void (^)(NSError *error))failure {
    NSParameterAssert(request);
    
    //NSURLSessionTaskStateRunning：检查 self.af_URLSessionTask 的状态是否为运行中（NSURLSessionTaskStateRunning）。这表示任务当前正在执行。
    //NSURLSessionTaskStateSuspended：检查 self.af_URLSessionTask 的状态是否为暂停（NSURLSessionTaskStateSuspended）。这表示任务当前被暂停，即处于非运行状态
    if (self.af_URLSessionTask.state == NSURLSessionTaskStateRunning || self.af_URLSessionTask.state == NSURLSessionTaskStateSuspended) {
        [self.af_URLSessionTask cancel];
    }
    self.af_URLSessionTask = nil;
    
    __weak __typeof(self)weakSelf = self;
    __block NSURLSessionDataTask *dataTask;
    __strong __typeof(weakSelf) strongSelf = weakSelf;
    __strong __typeof(weakSelf.navigationDelegate) strongSelfDelegate = strongSelf.navigationDelegate;
    dataTask = [self.sessionManager dataTaskWithRequest:request uploadProgress:nil downloadProgress:nil completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
        if (error) {
            if (failure) {
                failure(error);
            }
        } else {
            if (success) {
                success((NSHTTPURLResponse *)response, responseObject);
            }
            //将指定的数据加载到 WKWebView 中，并根据提供的 MIME 类型、字符编码和基本 URL 进行解释和显示。这种方式适用于加载一些动态生成的 HTML 内容或者其他类型的数据，而不是直接加载 URL
            //loadData:: 这是方法的名称，表示加载数据到 WebView 中
            //MIMEType: 这是数据的 MIME 类型（Multipurpose Internet Mail Extensions）。MIME 类型是一种标识数据类型的方式，例如，text/html 表示 HTML 数据，image/jpeg 表示 JPEG 图像等
            //baseURL: 这是一个 NSURL 对象，用于指定加载数据时的基本 URL。如果在数据中有相对路径的引用，将会以该基本 URL 为基础进行解析
            [strongSelf loadData:responseObject MIMEType:MIMEType characterEncodingName:textEncodingName baseURL:[dataTask.currentRequest URL]];
            
            if ([strongSelfDelegate respondsToSelector:@selector(webView:didFinishNavigation:)]) {
                [strongSelfDelegate webView:strongSelf didFinishNavigation:navigation];
            }
        }
    }];
    self.af_URLSessionTask = dataTask;
    if (progress != nil) {
        *progress = [self.sessionManager downloadProgressForTask:dataTask];
    }
    [self.af_URLSessionTask resume];
    
    if ([strongSelfDelegate respondsToSelector:@selector(webView:didStartProvisionalNavigation:)]) {
        //该方法的作用是在 WKWebView 开始加载新页面的时候通知代理。这可能是用户点击链接、通过 JavaScript 触发导航，或者通过编程方式调用 loadRequest: 或 loadHTMLString:baseURL: 等方法导致的导航
        [strongSelfDelegate webView:self didStartProvisionalNavigation:navigation];
    }
}

@end

#endif
