// AFURLSessionManager.m
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

#import "AFURLSessionManager.h"
#import <objc/runtime.h>

//AF的优化的点，虽然代理回调是串行的(不明白可以见本文最后)。但是数据解析这种费时操作，确是用并行线程来做的。
static dispatch_queue_t url_session_manager_processing_queue() {
    static dispatch_queue_t af_url_session_manager_processing_queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        af_url_session_manager_processing_queue = dispatch_queue_create("com.alamofire.networking.session.manager.processing", DISPATCH_QUEUE_CONCURRENT);
    });
    
    return af_url_session_manager_processing_queue;
}

static dispatch_group_t url_session_manager_completion_group() {
    static dispatch_group_t af_url_session_manager_completion_group;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        af_url_session_manager_completion_group = dispatch_group_create();
    });
    
    return af_url_session_manager_completion_group;
}

NSString * const AFNetworkingTaskDidResumeNotification = @"com.alamofire.networking.task.resume";
NSString * const AFNetworkingTaskDidCompleteNotification = @"com.alamofire.networking.task.complete";
NSString * const AFNetworkingTaskDidSuspendNotification = @"com.alamofire.networking.task.suspend";
NSString * const AFURLSessionDidInvalidateNotification = @"com.alamofire.networking.session.invalidate";
NSString * const AFURLSessionDownloadTaskDidMoveFileSuccessfullyNotification = @"com.alamofire.networking.session.download.file-manager-succeed";
NSString * const AFURLSessionDownloadTaskDidFailToMoveFileNotification = @"com.alamofire.networking.session.download.file-manager-error";

NSString * const AFNetworkingTaskDidCompleteSerializedResponseKey = @"com.alamofire.networking.task.complete.serializedresponse";
NSString * const AFNetworkingTaskDidCompleteResponseSerializerKey = @"com.alamofire.networking.task.complete.responseserializer";
NSString * const AFNetworkingTaskDidCompleteResponseDataKey = @"com.alamofire.networking.complete.finish.responsedata";
NSString * const AFNetworkingTaskDidCompleteErrorKey = @"com.alamofire.networking.task.complete.error";
NSString * const AFNetworkingTaskDidCompleteAssetPathKey = @"com.alamofire.networking.task.complete.assetpath";
NSString * const AFNetworkingTaskDidCompleteSessionTaskMetrics = @"com.alamofire.networking.complete.sessiontaskmetrics";

static NSString * const AFURLSessionManagerLockName = @"com.alamofire.networking.session.manager.lock";

typedef void (^AFURLSessionDidBecomeInvalidBlock)(NSURLSession *session, NSError *error);
typedef NSURLSessionAuthChallengeDisposition (^AFURLSessionDidReceiveAuthenticationChallengeBlock)(NSURLSession *session, NSURLAuthenticationChallenge *challenge, NSURLCredential * __autoreleasing *credential);

typedef NSURLRequest * (^AFURLSessionTaskWillPerformHTTPRedirectionBlock)(NSURLSession *session, NSURLSessionTask *task, NSURLResponse *response, NSURLRequest *request);
typedef NSURLSessionAuthChallengeDisposition (^AFURLSessionTaskDidReceiveAuthenticationChallengeBlock)(NSURLSession *session, NSURLSessionTask *task, NSURLAuthenticationChallenge *challenge, NSURLCredential * __autoreleasing *credential);
typedef id (^AFURLSessionTaskAuthenticationChallengeBlock)(NSURLSession *session, NSURLSessionTask *task, NSURLAuthenticationChallenge *challenge, void (^completionHandler)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential));
typedef void (^AFURLSessionDidFinishEventsForBackgroundURLSessionBlock)(NSURLSession *session);

typedef NSInputStream * (^AFURLSessionTaskNeedNewBodyStreamBlock)(NSURLSession *session, NSURLSessionTask *task);
typedef void (^AFURLSessionTaskDidSendBodyDataBlock)(NSURLSession *session, NSURLSessionTask *task, int64_t bytesSent, int64_t totalBytesSent, int64_t totalBytesExpectedToSend);
typedef void (^AFURLSessionTaskDidCompleteBlock)(NSURLSession *session, NSURLSessionTask *task, NSError *error);
#if AF_CAN_INCLUDE_SESSION_TASK_METRICS
typedef void (^AFURLSessionTaskDidFinishCollectingMetricsBlock)(NSURLSession *session, NSURLSessionTask *task, NSURLSessionTaskMetrics * metrics) AF_API_AVAILABLE(ios(10), macosx(10.12), watchos(3), tvos(10));
#endif

typedef NSURLSessionResponseDisposition (^AFURLSessionDataTaskDidReceiveResponseBlock)(NSURLSession *session, NSURLSessionDataTask *dataTask, NSURLResponse *response);
typedef void (^AFURLSessionDataTaskDidBecomeDownloadTaskBlock)(NSURLSession *session, NSURLSessionDataTask *dataTask, NSURLSessionDownloadTask *downloadTask);
typedef void (^AFURLSessionDataTaskDidReceiveDataBlock)(NSURLSession *session, NSURLSessionDataTask *dataTask, NSData *data);
typedef NSCachedURLResponse * (^AFURLSessionDataTaskWillCacheResponseBlock)(NSURLSession *session, NSURLSessionDataTask *dataTask, NSCachedURLResponse *proposedResponse);

typedef NSURL * (^AFURLSessionDownloadTaskDidFinishDownloadingBlock)(NSURLSession *session, NSURLSessionDownloadTask *downloadTask, NSURL *location);
typedef void (^AFURLSessionDownloadTaskDidWriteDataBlock)(NSURLSession *session, NSURLSessionDownloadTask *downloadTask, int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite);
typedef void (^AFURLSessionDownloadTaskDidResumeBlock)(NSURLSession *session, NSURLSessionDownloadTask *downloadTask, int64_t fileOffset, int64_t expectedTotalBytes);
typedef void (^AFURLSessionTaskProgressBlock)(NSProgress *);

typedef void (^AFURLSessionTaskCompletionHandler)(NSURLResponse *response, id responseObject, NSError *error);

#pragma mark -

@interface AFURLSessionManagerTaskDelegate : NSObject <NSURLSessionTaskDelegate, NSURLSessionDataDelegate, NSURLSessionDownloadDelegate>
- (instancetype)initWithTask:(NSURLSessionTask *)task;
@property (nonatomic, weak) AFURLSessionManager *manager;
@property (nonatomic, strong) NSMutableData *mutableData;
@property (nonatomic, strong) NSProgress *uploadProgress;
@property (nonatomic, strong) NSProgress *downloadProgress;
@property (nonatomic, copy) NSURL *downloadFileURL;
#if AF_CAN_INCLUDE_SESSION_TASK_METRICS
//sessionTaskMetrics 是在 NSURLSession 中用于获取关于网络请求性能和统计信息的属性。它提供了一种方式来检查单个网络请求任务（NSURLSessionTask）的性能参数，如请求开始时间、请求结束时间、重定向次数、传输大小、TLS连接时间等
@property (nonatomic, strong) NSURLSessionTaskMetrics *sessionTaskMetrics AF_API_AVAILABLE(ios(10), macosx(10.12), watchos(3), tvos(10));
#endif
@property (nonatomic, copy) AFURLSessionDownloadTaskDidFinishDownloadingBlock downloadTaskDidFinishDownloading;
@property (nonatomic, copy) AFURLSessionTaskProgressBlock uploadProgressBlock;
@property (nonatomic, copy) AFURLSessionTaskProgressBlock downloadProgressBlock;
@property (nonatomic, copy) AFURLSessionTaskCompletionHandler completionHandler;
@end

@implementation AFURLSessionManagerTaskDelegate

- (instancetype)initWithTask:(NSURLSessionTask *)task {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    _mutableData = [NSMutableData data];
    _uploadProgress = [[NSProgress alloc] initWithParent:nil userInfo:nil];
    _downloadProgress = [[NSProgress alloc] initWithParent:nil userInfo:nil];
    
    __weak __typeof__(task) weakTask = task;
    for (NSProgress *progress in @[ _uploadProgress, _downloadProgress ])
    {
        //表示在 NSURLSessionTaskMetrics 对象中用于表示特定请求或响应的传输大小的未知值
        progress.totalUnitCount = NSURLSessionTransferSizeUnknown;
        progress.cancellable = YES;
        
        //表示与进度相关联的任务被取消时要执行的处理程序
        progress.cancellationHandler = ^{
            [weakTask cancel];
        };
        progress.pausable = YES;
        
        //表示当与进度相关联的任务被暂停时要执行的处理程序。NSProgress 类用于跟踪操作的进度，允许开发者将暂停处理程序（pausing handler）与进度关联起来，以在任务被暂停时执行特定的操作。
        progress.pausingHandler = ^{
            [weakTask suspend];
        };
#if AF_CAN_USE_AT_AVAILABLE
        if (@available(macOS 10.11, *))
#else
            if ([progress respondsToSelector:@selector(setResumingHandler:)])
#endif
            {
                // 设置恢复处理程序
                progress.resumingHandler = ^{
                    [weakTask resume];
                };
            }
        
        //fractionCompleted 是 NSProgress 类的一个属性，表示任务的完成百分比。NSProgress 类用于跟踪操作的进度，提供了一个通用的、可观察的进度模型
        [progress addObserver:self
                   forKeyPath:NSStringFromSelector(@selector(fractionCompleted))
                      options:NSKeyValueObservingOptionNew
                      context:NULL];
    }
    return self;
}

- (void)dealloc {
    [self.downloadProgress removeObserver:self forKeyPath:NSStringFromSelector(@selector(fractionCompleted))];
    [self.uploadProgress removeObserver:self forKeyPath:NSStringFromSelector(@selector(fractionCompleted))];
}

#pragma mark - NSProgress Tracking

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context {
    if ([object isEqual:self.downloadProgress]) {
        if (self.downloadProgressBlock) {
            self.downloadProgressBlock(object);
        }
    }
    else if ([object isEqual:self.uploadProgress]) {
        if (self.uploadProgressBlock) {
            self.uploadProgressBlock(object);
        }
    }
}

static const void * const AuthenticationChallengeErrorKey = &AuthenticationChallengeErrorKey;

#pragma mark - NSURLSessionTaskDelegate

/// 用于在一个网络请求任务完成时被调用。这个方法提供了请求任务的完成状态和可能的错误信息
/// @param session 调用该方法的 NSURLSession 对象
/// @param task 完成的网络请求任务，即调用此方法的任务。
/// @param error 一个可能为 nil 的 NSError 对象，表示请求任务是否完成时是否发生了错误。如果任务成功完成，error 将为 nil；如果发生错误，error 将包含有关错误的详细信息
- (void)URLSession:(__unused NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error
{
    error = objc_getAssociatedObject(task, AuthenticationChallengeErrorKey) ?: error;
    //1）强引用self.manager，防止被提前释放；因为self.manager声明为weak,类似Block
    __strong AFURLSessionManager *manager = self.manager;
    
    __block id responseObject = nil;
    
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    //存储responseSerializer响应解析对象
    userInfo[AFNetworkingTaskDidCompleteResponseSerializerKey] = manager.responseSerializer;
    
    //Performance Improvement from #2672
    //注意这行代码的用法，感觉写的很Nice...把请求到的数据data传出去，然后就不要这个值了释放内存
    NSData *data = nil;
    if (self.mutableData) {
        data = [self.mutableData copy];
        //We no longer need the reference, so nil it out to gain back some memory.
        self.mutableData = nil;
    }
    
#if AF_CAN_USE_AT_AVAILABLE && AF_CAN_INCLUDE_SESSION_TASK_METRICS
    if (@available(iOS 10, macOS 10.12, watchOS 3, tvOS 10, *)) {
        if (self.sessionTaskMetrics) {
            userInfo[AFNetworkingTaskDidCompleteSessionTaskMetrics] = self.sessionTaskMetrics;
        }
    }
#endif
    
    //继续给userinfo填数据
    if (self.downloadFileURL) {
        userInfo[AFNetworkingTaskDidCompleteAssetPathKey] = self.downloadFileURL;
    } else if (data) {
        userInfo[AFNetworkingTaskDidCompleteResponseDataKey] = data;
    }
    
    //错误处理
    if (error) {
        userInfo[AFNetworkingTaskDidCompleteErrorKey] = error;
        
        //可以自己自定义完成组 和自定义完成queue,完成回调
        dispatch_group_async(manager.completionGroup ?: url_session_manager_completion_group(), manager.completionQueue ?: dispatch_get_main_queue(), ^{
            if (self.completionHandler) {
                self.completionHandler(task.response, responseObject, error);
            }
            //主线程中发送完成通知
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkingTaskDidCompleteNotification object:task userInfo:userInfo];
            });
        });
    } else {
        //url_session_manager_processing_queue AF的并行队列
        dispatch_async(url_session_manager_processing_queue(), ^{
            NSError *serializationError = nil;
            /**
             * 解析数据
             * manager 是 AFHTTPSessionManager 或其子类的一个实例，用于管理网络请求的配置和处理
             *
             * responseSerializer 是 AFHTTPResponseSerializer 的一个实例，负责将服务器返回的响应数据解析成所需的格式。例如，可以是 AFJSONResponseSerializer 用于解析 JSON 数据，也可以是 AFXMLParserResponseSerializer 用于解析 XML 数据
             *
             * task 是网络请求任务，其响应信息包含在 task.response 中
             *
             * data 是从服务器收到的原始数据，通常是二进制格式的
             *
             * serializationError 是一个 NSError 指针，用于捕获解析过程中可能发生的错误
             */
            responseObject = [manager.responseSerializer responseObjectForResponse:task.response data:data error:&serializationError];
            
            //如果是下载文件，那么responseObject为下载的路径
            if (self.downloadFileURL) {
                responseObject = self.downloadFileURL;
            }
            
            //写入userInfo
            if (responseObject) {
                userInfo[AFNetworkingTaskDidCompleteSerializedResponseKey] = responseObject;
            }
            
            //如果解析错误
            if (serializationError) {
                userInfo[AFNetworkingTaskDidCompleteErrorKey] = serializationError;
            }
            
            //回调结果
            dispatch_group_async(manager.completionGroup ?: url_session_manager_completion_group(), manager.completionQueue ?: dispatch_get_main_queue(), ^{
                if (self.completionHandler) {
                    self.completionHandler(task.response, responseObject, serializationError);
                }
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkingTaskDidCompleteNotification object:task userInfo:userInfo];
                });
            });
        });
    }
}

///检查是否定义了 AF_CAN_INCLUDE_SESSION_TASK_METRICS 这个宏。如果定义了，那么编译器会处理条件编译块内的代码；如果没有定义，那么这部分代码将被编译器忽略
#if AF_CAN_INCLUDE_SESSION_TASK_METRICS
//这是一个委托方法，用于在请求任务完成时收集性能数据。该方法在支持 iOS 10、macOS 10.12、watchOS 3、tvOS 10 及以上版本的系统上可用
- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics AF_API_AVAILABLE(ios(10), macosx(10.12), watchos(3), tvos(10)) {
    //将收集到的任务性能数据存储在 self.sessionTaskMetrics 中，以便在其他地方使用或记录
    self.sessionTaskMetrics = metrics;
}
#endif

#pragma mark - NSURLSessionDataDelegate

/// 在每次从服务器接收到数据时都会被调用一次
/// @param session 调用该方法的 NSURLSession 对象
/// @param dataTask 接收到数据的数据任务
/// @param data 从服务器接收到的数据块
- (void)URLSession:(__unused NSURLSession *)session
          dataTask:(__unused NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data
{
    self.downloadProgress.totalUnitCount = dataTask.countOfBytesExpectedToReceive;
    self.downloadProgress.completedUnitCount = dataTask.countOfBytesReceived;
    
    // 将接收到的数据追加到可变数据缓冲区
    [self.mutableData appendData:data];
}


/// 这个方法在上传过程中，每次发送数据块时都会被调用一次
/// @param session 调用该方法的 NSURLSession 对象
/// @param task 正在进行的任务，通常是一个上传任务
/// @param bytesSent 当前发送的数据块的字节数
/// @param totalBytesSent 截至目前已经发送的总字节数
/// @param totalBytesExpectedToSend 期望发送的总字节数，通常是上传数据的总大小
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
   didSendBodyData:(int64_t)bytesSent
    totalBytesSent:(int64_t)totalBytesSent
totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend{
    
    self.uploadProgress.totalUnitCount = task.countOfBytesExpectedToSend;
    self.uploadProgress.completedUnitCount = task.countOfBytesSent;
}

#pragma mark - NSURLSessionDownloadDelegate

/// 这个方法在下载过程中，每次接收到数据块时都会被调用一次
/// @param session 调用该方法的 NSURLSession 对象
/// @param downloadTask 正在进行的下载任务
/// @param bytesWritten 当前接收到的数据块的字节数
/// @param totalBytesWritten 截至目前已经接收的总字节数
/// @param totalBytesExpectedToWrite 期望接收的总字节数，通常是下载文件的总大小
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite{
    
    self.downloadProgress.totalUnitCount = totalBytesExpectedToWrite;
    self.downloadProgress.completedUnitCount = totalBytesWritten;
}


/// 这个方法在一个之前暂停的下载任务重新开始时被调用
/// @param session 调用该方法的 NSURLSession 对象
/// @param downloadTask 正在进行的下载任务
/// @param fileOffset  断点续传的偏移量，表示从文件的哪个位置开始续传
/// @param expectedTotalBytes 期望下载的总字节数，通常是下载文件的总大小
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
 didResumeAtOffset:(int64_t)fileOffset
expectedTotalBytes:(int64_t)expectedTotalBytes{
    
    self.downloadProgress.totalUnitCount = expectedTotalBytes;
    self.downloadProgress.completedUnitCount = fileOffset;
}


/// 这个方法在下载任务完成后被调用，提供了包含下载文件的临时文件的本地文件 URL
/// @param session 调用该方法的 NSURLSession 对象
/// @param downloadTask 已完成下载的下载任务
/// @param location 包含下载文件的临时文件的本地文件 URL
- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
didFinishDownloadingToURL:(NSURL *)location
{
    self.downloadFileURL = nil;
    
    //AF代理的自定义Block
    if (self.downloadTaskDidFinishDownloading) {
        //得到自定义下载路径
        self.downloadFileURL = self.downloadTaskDidFinishDownloading(session, downloadTask, location);
        if (self.downloadFileURL) {
            NSError *fileManagerError = nil;
            
            //把下载路径移动到我们自定义的下载路径
            if (![[NSFileManager defaultManager] moveItemAtURL:location toURL:self.downloadFileURL error:&fileManagerError]) {
                //错误发通知
                [[NSNotificationCenter defaultCenter] postNotificationName:AFURLSessionDownloadTaskDidFailToMoveFileNotification object:downloadTask userInfo:fileManagerError.userInfo];
            } else {
                [[NSNotificationCenter defaultCenter] postNotificationName:AFURLSessionDownloadTaskDidMoveFileSuccessfullyNotification object:downloadTask userInfo:nil];
            }
        }
    }
}

@end

#pragma mark -

/**
 *  A workaround for issues related to key-value observing the `state` of an `NSURLSessionTask`.
 *
 *  See:
 *  - https://github.com/AFNetworking/AFNetworking/issues/1477
 *  - https://github.com/AFNetworking/AFNetworking/issues/2638
 *  - https://github.com/AFNetworking/AFNetworking/pull/2702
 */

static inline void af_swizzleSelector(Class theClass, SEL originalSelector, SEL swizzledSelector) {
    Method originalMethod = class_getInstanceMethod(theClass, originalSelector);
    Method swizzledMethod = class_getInstanceMethod(theClass, swizzledSelector);
    method_exchangeImplementations(originalMethod, swizzledMethod);
}

static inline BOOL af_addMethod(Class theClass, SEL selector, Method method) {
    return class_addMethod(theClass, selector,  method_getImplementation(method),  method_getTypeEncoding(method));
}

static NSString * const AFNSURLSessionTaskDidResumeNotification  = @"com.alamofire.networking.nsurlsessiontask.resume";
static NSString * const AFNSURLSessionTaskDidSuspendNotification = @"com.alamofire.networking.nsurlsessiontask.suspend";

@interface _AFURLSessionTaskSwizzling : NSObject

@end

@implementation _AFURLSessionTaskSwizzling

+ (void)load {
    /**
     WARNING: Trouble Ahead
     https://github.com/AFNetworking/AFNetworking/pull/2702
     */
    
    if (NSClassFromString(@"NSURLSessionTask")) {
        /**
         iOS 7 and iOS 8 differ in NSURLSessionTask implementation, which makes the next bit of code a bit tricky.
         Many Unit Tests have been built to validate as much of this behavior has possible.
         Here is what we know:
         - NSURLSessionTasks are implemented with class clusters, meaning the class you request from the API isn't actually the type of class you will get back.
         - Simply referencing `[NSURLSessionTask class]` will not work. You need to ask an `NSURLSession` to actually create an object, and grab the class from there.
         - On iOS 7, `localDataTask` is a `__NSCFLocalDataTask`, which inherits from `__NSCFLocalSessionTask`, which inherits from `__NSCFURLSessionTask`.
         - On iOS 8, `localDataTask` is a `__NSCFLocalDataTask`, which inherits from `__NSCFLocalSessionTask`, which inherits from `NSURLSessionTask`.
         - On iOS 7, `__NSCFLocalSessionTask` and `__NSCFURLSessionTask` are the only two classes that have their own implementations of `resume` and `suspend`, and `__NSCFLocalSessionTask` DOES NOT CALL SUPER. This means both classes need to be swizzled.
         - On iOS 8, `NSURLSessionTask` is the only class that implements `resume` and `suspend`. This means this is the only class that needs to be swizzled.
         - Because `NSURLSessionTask` is not involved in the class hierarchy for every version of iOS, its easier to add the swizzled methods to a dummy class and manage them there.
         
         Some Assumptions:
         - No implementations of `resume` or `suspend` call super. If this were to change in a future version of iOS, we'd need to handle it.
         - No background task classes override `resume` or `suspend`
         
         The current solution:
         1) Grab an instance of `__NSCFLocalDataTask` by asking an instance of `NSURLSession` for a data task.
         2) Grab a pointer to the original implementation of `af_resume`
         3) Check to see if the current class has an implementation of resume. If so, continue to step 4.
         4) Grab the super class of the current class.
         5) Grab a pointer for the current class to the current implementation of `resume`.
         6) Grab a pointer for the super class to the current implementation of `resume`.
         7) If the current class implementation of `resume` is not equal to the super class implementation of `resume` AND the current implementation of `resume` is not equal to the original implementation of `af_resume`, THEN swizzle the methods
         8) Set the current class to the super class, and repeat steps 3-8
         */
        //创建了一个临时会话配置,临时会话配置与默认会话配置有一些区别，主要在于它不会将缓存、cookie 等数据进行持久化，适用于需要一次性使用并不保存任何会话数据的场景
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        //这个会话对象可以用于创建和管理任务，如数据任务、下载任务、上传任务等
        NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wnonnull"
        NSURLSessionDataTask *localDataTask = [session dataTaskWithURL:nil];
#pragma clang diagnostic pop
        IMP originalAFResumeIMP = method_getImplementation(class_getInstanceMethod([self class], @selector(af_resume)));
        Class currentClass = [localDataTask class];
        
        while (class_getInstanceMethod(currentClass, @selector(resume))) {
            Class superClass = [currentClass superclass];
            IMP classResumeIMP = method_getImplementation(class_getInstanceMethod(currentClass, @selector(resume)));
            IMP superclassResumeIMP = method_getImplementation(class_getInstanceMethod(superClass, @selector(resume)));
            if (classResumeIMP != superclassResumeIMP &&
                originalAFResumeIMP != classResumeIMP) {
                [self swizzleResumeAndSuspendMethodForClass:currentClass];
            }
            currentClass = [currentClass superclass];
        }
        
        [localDataTask cancel];
        //该方法无法再向该会话中添加新的任务，但已经正在执行的任务会继续执行直到完成。
        [session finishTasksAndInvalidate];
    }
}

+ (void)swizzleResumeAndSuspendMethodForClass:(Class)theClass {
    Method afResumeMethod = class_getInstanceMethod(self, @selector(af_resume));
    Method afSuspendMethod = class_getInstanceMethod(self, @selector(af_suspend));
    
    if (af_addMethod(theClass, @selector(af_resume), afResumeMethod)) {
        af_swizzleSelector(theClass, @selector(resume), @selector(af_resume));
    }
    
    if (af_addMethod(theClass, @selector(af_suspend), afSuspendMethod)) {
        af_swizzleSelector(theClass, @selector(suspend), @selector(af_suspend));
    }
}

- (NSURLSessionTaskState)state {
    NSAssert(NO, @"State method should never be called in the actual dummy class");
    return NSURLSessionTaskStateCanceling;
}

- (void)af_resume {
    NSAssert([self respondsToSelector:@selector(state)], @"Does not respond to state");
    NSURLSessionTaskState state = [self state];
    [self af_resume];
    
    if (state != NSURLSessionTaskStateRunning) {
        [[NSNotificationCenter defaultCenter] postNotificationName:AFNSURLSessionTaskDidResumeNotification object:self];
    }
}

- (void)af_suspend {
    NSAssert([self respondsToSelector:@selector(state)], @"Does not respond to state");
    NSURLSessionTaskState state = [self state];
    [self af_suspend];
    
    if (state != NSURLSessionTaskStateSuspended) {
        [[NSNotificationCenter defaultCenter] postNotificationName:AFNSURLSessionTaskDidSuspendNotification object:self];
    }
}
@end

#pragma mark -

@interface AFURLSessionManager ()
@property (readwrite, nonatomic, strong) NSURLSessionConfiguration *sessionConfiguration;
@property (readwrite, nonatomic, strong) NSOperationQueue *operationQueue;
@property (readwrite, nonatomic, strong) NSURLSession *session;
@property (readwrite, nonatomic, strong) NSMutableDictionary *mutableTaskDelegatesKeyedByTaskIdentifier;
@property (readonly, nonatomic, copy) NSString *taskDescriptionForSessionTasks;
@property (readwrite, nonatomic, strong) NSLock *lock;
@property (readwrite, nonatomic, copy) AFURLSessionDidBecomeInvalidBlock sessionDidBecomeInvalid;
@property (readwrite, nonatomic, copy) AFURLSessionDidReceiveAuthenticationChallengeBlock sessionDidReceiveAuthenticationChallenge;
@property (readwrite, nonatomic, copy) AFURLSessionDidFinishEventsForBackgroundURLSessionBlock didFinishEventsForBackgroundURLSession AF_API_UNAVAILABLE(macos);
@property (readwrite, nonatomic, copy) AFURLSessionTaskWillPerformHTTPRedirectionBlock taskWillPerformHTTPRedirection;
@property (readwrite, nonatomic, copy) AFURLSessionTaskAuthenticationChallengeBlock authenticationChallengeHandler;
@property (readwrite, nonatomic, copy) AFURLSessionTaskNeedNewBodyStreamBlock taskNeedNewBodyStream;
@property (readwrite, nonatomic, copy) AFURLSessionTaskDidSendBodyDataBlock taskDidSendBodyData;
@property (readwrite, nonatomic, copy) AFURLSessionTaskDidCompleteBlock taskDidComplete;
#if AF_CAN_INCLUDE_SESSION_TASK_METRICS
@property (readwrite, nonatomic, copy) AFURLSessionTaskDidFinishCollectingMetricsBlock taskDidFinishCollectingMetrics AF_API_AVAILABLE(ios(10), macosx(10.12), watchos(3), tvos(10));
#endif
@property (readwrite, nonatomic, copy) AFURLSessionDataTaskDidReceiveResponseBlock dataTaskDidReceiveResponse;
@property (readwrite, nonatomic, copy) AFURLSessionDataTaskDidBecomeDownloadTaskBlock dataTaskDidBecomeDownloadTask;
@property (readwrite, nonatomic, copy) AFURLSessionDataTaskDidReceiveDataBlock dataTaskDidReceiveData;
@property (readwrite, nonatomic, copy) AFURLSessionDataTaskWillCacheResponseBlock dataTaskWillCacheResponse;
@property (readwrite, nonatomic, copy) AFURLSessionDownloadTaskDidFinishDownloadingBlock downloadTaskDidFinishDownloading;
@property (readwrite, nonatomic, copy) AFURLSessionDownloadTaskDidWriteDataBlock downloadTaskDidWriteData;
@property (readwrite, nonatomic, copy) AFURLSessionDownloadTaskDidResumeBlock downloadTaskDidResume;
@end

@implementation AFURLSessionManager

- (instancetype)init {
    return [self initWithSessionConfiguration:nil];
}

- (instancetype)initWithSessionConfiguration:(NSURLSessionConfiguration *)configuration {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    if (!configuration) {
        //这个方法返回一个默认的会话配置对象，该配置对象使用了默认的缓存策略、证书策略和超时时间等设置。默认会话配置通常适用于大多数网络请求场景，但你仍然可以根据需要创建自定义的会话配置对象
        configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    }
    
    self.sessionConfiguration = configuration;
    
    self.operationQueue = [[NSOperationQueue alloc] init];
    //queue并发线程数设置为1
    self.operationQueue.maxConcurrentOperationCount = 1;
    //各种响应转码
    self.responseSerializer = [AFJSONResponseSerializer serializer];
    //设置默认安全策略
    self.securityPolicy = [AFSecurityPolicy defaultPolicy];
    
#if !TARGET_OS_WATCH
    self.reachabilityManager = [AFNetworkReachabilityManager sharedManager];
#endif
    //设置存储NSURL task与AFURLSessionManagerTaskDelegate的词典
    //  （重点，在AFNet中，每一个task都会被匹配一个AFURLSessionManagerTaskDelegate 来做task的delegate事件处理）
    self.mutableTaskDelegatesKeyedByTaskIdentifier = [[NSMutableDictionary alloc] init];
    
    //设置AFURLSessionManagerTaskDelegate 词典的锁，确保词典在多线程访问时的线程安全
    self.lock = [[NSLock alloc] init];
    self.lock.name = AFURLSessionManagerLockName;
    
    //  置空task关联的代理
    //  这个方法用来异步的获取当前session的所有未完成的task
    /**
     * getTasksWithCompletionHandler:用于获取当前会话中的所有任务（data tasks、upload tasks、download tasks），并通过回调返回这些任务的数组
     * 在初始化中调用这个方法应该里面一个task都不会有。我们打断点去看，也确实如此，里面的数组都是空的
     * 原来这是为了防止后台回来，重新初始化这个session，一些之前的后台请求任务，导致程序的crash
     */
    [self.session getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
        for (NSURLSessionDataTask *task in dataTasks) {
            [self addDelegateForDataTask:task uploadProgress:nil downloadProgress:nil completionHandler:nil];
        }
        
        for (NSURLSessionUploadTask *uploadTask in uploadTasks) {
            [self addDelegateForUploadTask:uploadTask progress:nil completionHandler:nil];
        }
        
        for (NSURLSessionDownloadTask *downloadTask in downloadTasks) {
            [self addDelegateForDownloadTask:downloadTask progress:nil destination:nil completionHandler:nil];
        }
    }];
    
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark -

- (NSURLSession *)session {
    
    @synchronized (self) {
        if (!_session) {
            //注意代理，代理的继承，实际上NSURLSession去判断了，你实现了哪个方法会去调用，包括子代理的方法
            /**
             * 创建一个具有自定义配置、代理和操作队列的NSURLSession对象
             *self.operationQueue: 见 509 行
             *self.sessionConfiguration： 见 503 行
             */
            _session = [NSURLSession sessionWithConfiguration:self.sessionConfiguration delegate:self delegateQueue:self.operationQueue];
        }
    }
    return _session;
}

#pragma mark -


- (NSString *)taskDescriptionForSessionTasks {
    return [NSString stringWithFormat:@"%p", self];
}

/// 任务启动
/// @param notification 通知
- (void)taskDidResume:(NSNotification *)notification {
    NSURLSessionTask *task = notification.object;
    if ([task respondsToSelector:@selector(taskDescription)]) {
        if ([task.taskDescription isEqualToString:self.taskDescriptionForSessionTasks]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkingTaskDidResumeNotification object:task];
            });
        }
    }
}

/// 任务暂停
/// @param notification 通知
- (void)taskDidSuspend:(NSNotification *)notification {
    NSURLSessionTask *task = notification.object;
    if ([task respondsToSelector:@selector(taskDescription)]) {
        if ([task.taskDescription isEqualToString:self.taskDescriptionForSessionTasks]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkingTaskDidSuspendNotification object:task];
            });
        }
    }
}

#pragma mark -
/// 通过调用这个方法，AFURLSessionManager将返回与给定任务关联的任务代理对象。任务代理对象的责任是处理任务的进度、完成情况、错误处理等
/// @param task 这是输入参数，表示需要获取任务代理的NSURLSessionTask对象
/// AFURLSessionManagerTaskDelegate：这是一个自定义的类，它是AFURLSessionManager的内部私有类，用于处理NSURLSessionTask的代理方法和其他与任务相关的事件。它的具体实现由AFNetworking库内部进行管理
- (AFURLSessionManagerTaskDelegate *)delegateForTask:(NSURLSessionTask *)task {
    NSParameterAssert(task);
    
    AFURLSessionManagerTaskDelegate *delegate = nil;
    [self.lock lock];
    delegate = self.mutableTaskDelegatesKeyedByTaskIdentifier[@(task.taskIdentifier)];
    [self.lock unlock];
    
    return delegate;
}

/**
 *  这个方法主要就是把AF代理和task建立映射，存在了一个我们事先声明好的字典里
 *  而要加锁的原因是因为本身我们这个字典属性是mutable的，是线程不安全的。
 */
- (void)setDelegate:(AFURLSessionManagerTaskDelegate *)delegate
            forTask:(NSURLSessionTask *)task
{
    NSParameterAssert(task);
    NSParameterAssert(delegate);
    
    //加锁保证字典线程安全
    [self.lock lock];
    // 将AF delegate放入以taskIdentifier标记的词典中（同一个NSURLSession中的taskIdentifier是唯一的）
    self.mutableTaskDelegatesKeyedByTaskIdentifier[@(task.taskIdentifier)] = delegate;
    //  添加task开始和暂停的通知
    [self addNotificationObserverForTask:task];
    [self.lock unlock];
}

- (void)addDelegateForDataTask:(NSURLSessionDataTask *)dataTask
                uploadProgress:(nullable void (^)(NSProgress *uploadProgress)) uploadProgressBlock
              downloadProgress:(nullable void (^)(NSProgress *downloadProgress)) downloadProgressBlock
             completionHandler:(void (^)(NSURLResponse *response, id responseObject, NSError *error))completionHandler
{
    AFURLSessionManagerTaskDelegate *delegate = [[AFURLSessionManagerTaskDelegate alloc] initWithTask:dataTask];
    // AFURLSessionManagerTaskDelegate与AFURLSessionManager建立相互关系
    delegate.manager = self;
    delegate.completionHandler = completionHandler;
    
    //  这个taskDescriptionForSessionTasks用来发送开始和挂起通知的时候会用到,就是用这个值来Post通知，来两者对应
    dataTask.taskDescription = self.taskDescriptionForSessionTasks;
    // ***** 将AF delegate对象与 dataTask建立关系
    [self setDelegate:delegate forTask:dataTask];
    // ***** 将AF delegate对象与 dataTask建立关系
    delegate.uploadProgressBlock = uploadProgressBlock;
    delegate.downloadProgressBlock = downloadProgressBlock;
}

//通过调用这个方法，可以为指定的上传任务添加代理，以便监控上传进度和处理任务完成时的响应
- (void)addDelegateForUploadTask:(NSURLSessionUploadTask *)uploadTask
                        progress:(void (^)(NSProgress *uploadProgress)) uploadProgressBlock
               completionHandler:(void (^)(NSURLResponse *response, id responseObject, NSError *error))completionHandler
{
    AFURLSessionManagerTaskDelegate *delegate = [[AFURLSessionManagerTaskDelegate alloc] initWithTask:uploadTask];
    delegate.manager = self;
    delegate.completionHandler = completionHandler;
    
    uploadTask.taskDescription = self.taskDescriptionForSessionTasks;
    
    [self setDelegate:delegate forTask:uploadTask];
    
    delegate.uploadProgressBlock = uploadProgressBlock;
}

- (void)addDelegateForDownloadTask:(NSURLSessionDownloadTask *)downloadTask
                          progress:(void (^)(NSProgress *downloadProgress)) downloadProgressBlock
                       destination:(NSURL * (^)(NSURL *targetPath, NSURLResponse *response))destination
                 completionHandler:(void (^)(NSURLResponse *response, NSURL *filePath, NSError *error))completionHandler
{
    AFURLSessionManagerTaskDelegate *delegate = [[AFURLSessionManagerTaskDelegate alloc] initWithTask:downloadTask];
    delegate.manager = self;
    delegate.completionHandler = completionHandler;
    
    //返回地址的Block
    if (destination) {
        //有点绕，就是把一个block赋值给我们代理的downloadTaskDidFinishDownloading，这个Block里的内部返回也是调用Block去获取到的，这里面的参数都是AF代理传过去的
        delegate.downloadTaskDidFinishDownloading = ^NSURL * (NSURLSession * __unused session, NSURLSessionDownloadTask *task, NSURL *location) {
            //把Block返回的地址返回
            return destination(location, task.response);
        };
    }
    
    downloadTask.taskDescription = self.taskDescriptionForSessionTasks;
    
    [self setDelegate:delegate forTask:downloadTask];
    
    delegate.downloadProgressBlock = downloadProgressBlock;
}

- (void)removeDelegateForTask:(NSURLSessionTask *)task {
    NSParameterAssert(task);
    
    //移除跟AF代理相关的东西
    [self.lock lock];
    [self removeNotificationObserverForTask:task];
    [self.mutableTaskDelegatesKeyedByTaskIdentifier removeObjectForKey:@(task.taskIdentifier)];
    [self.lock unlock];
}

#pragma mark -

- (NSArray *)tasksForKeyPath:(NSString *)keyPath {
    __block NSArray *tasks = nil;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    [self.session getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
        if ([keyPath isEqualToString:NSStringFromSelector(@selector(dataTasks))]) {
            tasks = dataTasks;
        } else if ([keyPath isEqualToString:NSStringFromSelector(@selector(uploadTasks))]) {
            tasks = uploadTasks;
        } else if ([keyPath isEqualToString:NSStringFromSelector(@selector(downloadTasks))]) {
            tasks = downloadTasks;
        } else if ([keyPath isEqualToString:NSStringFromSelector(@selector(tasks))]) {
            tasks = [@[dataTasks, uploadTasks, downloadTasks] valueForKeyPath:@"@unionOfArrays.self"];
        }
        
        dispatch_semaphore_signal(semaphore);
    }];
    
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
    return tasks;
}

- (NSArray *)tasks {
    //tasksForKeyPath: 方法的作用是根据传入的键路径查找和返回与之关联的任务
    return [self tasksForKeyPath:NSStringFromSelector(_cmd)];
}

- (NSArray *)dataTasks {
    return [self tasksForKeyPath:NSStringFromSelector(_cmd)];
}

- (NSArray *)uploadTasks {
    return [self tasksForKeyPath:NSStringFromSelector(_cmd)];
}

- (NSArray *)downloadTasks {
    return [self tasksForKeyPath:NSStringFromSelector(_cmd)];
}

#pragma mark -

/// 使NSURLSession对象失效，并可以选择取消正在进行的任务和重置会话
/// @param cancelPendingTasks 这是一个布尔类型的参数，用于指定是否取消正在进行的任务。如果为YES，则调用invalidateAndCancel方法取消所有进行中的任务；如果为NO，则调用finishTasksAndInvalidate方法等待任务完成后再失效会话
/// @param resetSession 这是另一个布尔类型的参数，用于指定是否在失效后重置会话。如果为YES，则将self.session设置为nil，以便之后可以重新创建或使用新的会话
- (void)invalidateSessionCancelingTasks:(BOOL)cancelPendingTasks resetSession:(BOOL)resetSession {
    if (cancelPendingTasks) {
        [self.session invalidateAndCancel];
    } else {
        [self.session finishTasksAndInvalidate];
    }
    if (resetSession) {
        self.session = nil;
    }
}

#pragma mark -

- (void)setResponseSerializer:(id <AFURLResponseSerialization>)responseSerializer {
    NSParameterAssert(responseSerializer);
    
    _responseSerializer = responseSerializer;
}

#pragma mark -
- (void)addNotificationObserverForTask:(NSURLSessionTask *)task {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(taskDidResume:) name:AFNSURLSessionTaskDidResumeNotification object:task];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(taskDidSuspend:) name:AFNSURLSessionTaskDidSuspendNotification object:task];
}

- (void)removeNotificationObserverForTask:(NSURLSessionTask *)task {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AFNSURLSessionTaskDidSuspendNotification object:task];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AFNSURLSessionTaskDidResumeNotification object:task];
}

#pragma mark -

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                               uploadProgress:(nullable void (^)(NSProgress *uploadProgress)) uploadProgressBlock
                             downloadProgress:(nullable void (^)(NSProgress *downloadProgress)) downloadProgressBlock
                            completionHandler:(nullable void (^)(NSURLResponse *response, id _Nullable responseObject,  NSError * _Nullable error))completionHandler {
    /*
     __block NSURLSessionDataTask *dataTask = nil;
     //第一件事，创建NSURLSessionDataTask，里面适配了Ios8以下taskIdentifiers，函数创建task对象。
     //其实现应该是因为iOS 8.0以下版本中会并发地创建多个task对象，而同步有没有做好，导致taskIdentifiers 不唯一…这边做了一个串行处理
     url_session_manager_create_task_safely(^{
        dataTask = [self.session dataTaskWithRequest:request];
     });
     */
    NSURLSessionDataTask *dataTask = [self.session dataTaskWithRequest:request];
    
    [self addDelegateForDataTask:dataTask uploadProgress:uploadProgressBlock downloadProgress:downloadProgressBlock completionHandler:completionHandler];
    
    return dataTask;
}

#pragma mark -

/// 创建一个基于文件的上传任务
/// @param request 表示包含上传任务相关信息的请求对象
/// @param fileURL 指定上传文件路径的参数，用于指定要上传的文件的位置
/// @param uploadProgressBlock 上传进度的回调
/// @param completionHandler 上传任务完成时调用
- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request
                                         fromFile:(NSURL *)fileURL
                                         progress:(void (^)(NSProgress *uploadProgress)) uploadProgressBlock
                                completionHandler:(void (^)(NSURLResponse *response, id responseObject, NSError *error))completionHandler
{
    NSURLSessionUploadTask *uploadTask = [self.session uploadTaskWithRequest:request fromFile:fileURL];
    
    if (uploadTask) {
        [self addDelegateForUploadTask:uploadTask
                              progress:uploadProgressBlock
                     completionHandler:completionHandler];
    }
    
    return uploadTask;
}

- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request
                                         fromData:(NSData *)bodyData
                                         progress:(void (^)(NSProgress *uploadProgress)) uploadProgressBlock
                                completionHandler:(void (^)(NSURLResponse *response, id responseObject, NSError *error))completionHandler
{
    NSURLSessionUploadTask *uploadTask = [self.session uploadTaskWithRequest:request fromData:bodyData];
    
    [self addDelegateForUploadTask:uploadTask progress:uploadProgressBlock completionHandler:completionHandler];
    
    return uploadTask;
}

- (NSURLSessionUploadTask *)uploadTaskWithStreamedRequest:(NSURLRequest *)request
                                                 progress:(void (^)(NSProgress *uploadProgress)) uploadProgressBlock
                                        completionHandler:(void (^)(NSURLResponse *response, id responseObject, NSError *error))completionHandler
{
    //此方法用于创建一个上传任务，其中请求的 HTTP 主体数据可以以流的方式动态生成
    //该方法适用于在请求体数据太大而无法一次性加载到内存的情况。它允许你通过流式方式生成请求体，这对于处理大型文件或流数据非常有用。
    NSURLSessionUploadTask *uploadTask = [self.session uploadTaskWithStreamedRequest:request];
    
    [self addDelegateForUploadTask:uploadTask progress:uploadProgressBlock completionHandler:completionHandler];
    
    return uploadTask;
}

#pragma mark -

- (NSURLSessionDownloadTask *)downloadTaskWithRequest:(NSURLRequest *)request
                                             progress:(void (^)(NSProgress *downloadProgress)) downloadProgressBlock
                                          destination:(NSURL * (^)(NSURL *targetPath, NSURLResponse *response))destination
                                    completionHandler:(void (^)(NSURLResponse *response, NSURL *filePath, NSError *error))completionHandler
{
    //downloadTaskWithRequest: 方法被调用以创建一个支持下载的任务。你可以通过配置 request 对象来设置请求的其他属性，例如 HTTP 方法、标头等。然后，通过调用 resume 方法启动任务。
    //downloadTaskWithRequest: 是用于在下载操作中创建任务的便捷方法，适用于需要下载大文件或将数据保存到本地的情况
    NSURLSessionDownloadTask *downloadTask = [self.session downloadTaskWithRequest:request];
    
    [self addDelegateForDownloadTask:downloadTask progress:downloadProgressBlock destination:destination completionHandler:completionHandler];
    
    return downloadTask;
}

- (NSURLSessionDownloadTask *)downloadTaskWithResumeData:(NSData *)resumeData
                                                progress:(void (^)(NSProgress *downloadProgress)) downloadProgressBlock
                                             destination:(NSURL * (^)(NSURL *targetPath, NSURLResponse *response))destination
                                       completionHandler:(void (^)(NSURLResponse *response, NSURL *filePath, NSError *error))completionHandler
{
    //此方法用于创建一个下载任务，通过提供之前被中断的下载任务的恢复数据，可以继续未完成的下载。这对于在下载中途被中断的情况下，能够恢复下载而不必重新开始非常有用
    //resumeData 之前下载任务被中断后获得的恢复数据
    NSURLSessionDownloadTask *downloadTask = [self.session downloadTaskWithResumeData:resumeData];
    
    [self addDelegateForDownloadTask:downloadTask progress:downloadProgressBlock destination:destination completionHandler:completionHandler];
    
    return downloadTask;
}

#pragma mark -

/// 获取到与特定任务相关的上传进度对象，从而监视上传任务的进度
/// @param task 任务
- (NSProgress *)uploadProgressForTask:(NSURLSessionTask *)task {
    return [[self delegateForTask:task] uploadProgress];
}

- (NSProgress *)downloadProgressForTask:(NSURLSessionTask *)task {
    return [[self delegateForTask:task] downloadProgress];
}

#pragma mark -

- (void)setSessionDidBecomeInvalidBlock:(void (^)(NSURLSession *session, NSError *error))block {
    self.sessionDidBecomeInvalid = block;
}

/// 通过调用这个方法，你可以自定义处理NSURLSession接收到的身份验证挑战的逻辑。在块内部，你可以根据具体的挑战情况决定如何响应，例如提供用户名和密码、使用证书进行身份验证等。这种灵活性允许你定制应用程序对于身份验证挑战的处理方式。
/// @param block 用于处理身份验证挑战。这个block接受三个参数：
///         session：表示发生挑战的NSURLSession对象。
///         challenge：表示具体的身份验证挑战。
///         credential：表示用于身份验证的凭据，可以通过修改这个参数来提供凭据。
- (void)setSessionDidReceiveAuthenticationChallengeBlock:(NSURLSessionAuthChallengeDisposition (^)(NSURLSession *session, NSURLAuthenticationChallenge *challenge, NSURLCredential * __autoreleasing *credential))block {
    self.sessionDidReceiveAuthenticationChallenge = block;
}

#if !TARGET_OS_OSX
///通过调用这个方法，你可以为后台会话设置一个回调块，以便在会话完成所有事件（例如下载完成）时执行特定的操作。这在处理后台下载任务时特别有用，因为在后台执行完成之后，你可能希望执行一些特定的逻辑，例如通知用户下载已完成或执行其他后续操作
- (void)setDidFinishEventsForBackgroundURLSessionBlock:(void (^)(NSURLSession *session))block {
    self.didFinishEventsForBackgroundURLSession = block;
}
#endif

#pragma mark -

- (void)setTaskNeedNewBodyStreamBlock:(NSInputStream * (^)(NSURLSession *session, NSURLSessionTask *task))block {
    self.taskNeedNewBodyStream = block;
}


/// 用于设置一个回调块，该块会在 HTTP 重定向即将发生时被调用。该回调允许你自定义 HTTP 重定向的行为
/// @param block 一个带有四个参数的块，用于在 HTTP 重定向即将发生时被调用。这个块应该返回一个 NSURLRequest 对象，该对象指定了新的请求，或者返回 nil 表示使用默认的重定向行为。参数包括：
///             session：包含这个任务的 NSURLSession 对象。
///             task：即将发生 HTTP 重定向的任务。
///             response：包含服务器的响应信息。
///             request：包含即将发生的重定向的请求信息。
- (void)setTaskWillPerformHTTPRedirectionBlock:(NSURLRequest * (^)(NSURLSession *session, NSURLSessionTask *task, NSURLResponse *response, NSURLRequest *request))block {
    self.taskWillPerformHTTPRedirection = block;
}

/// 通过调用这个方法，你可以为NSURLSession任务设置一个回调块，以便在任务发送请求体数据的时候执行特定的操作。这在监控上传进度、实时更新用户界面或执行其他与请求体数据相关的操作时非常有用
- (void)setTaskDidSendBodyDataBlock:(void (^)(NSURLSession *session, NSURLSessionTask *task, int64_t bytesSent, int64_t totalBytesSent, int64_t totalBytesExpectedToSend))block {
    self.taskDidSendBodyData = block;
}

- (void)setTaskDidCompleteBlock:(void (^)(NSURLSession *session, NSURLSessionTask *task, NSError *error))block {
    self.taskDidComplete = block;
}

#if AF_CAN_INCLUDE_SESSION_TASK_METRICS
/// 通过调用这个方法，你可以为NSURLSession任务设置一个回调块，以便在任务完成收集指标时执行特定的操作。指标信息可以包括任务的响应时间、重定向次数、传输大小等。这样的回调机制允许你在任务的特定事件发生时插入自定义逻辑，以适应你的应用程序的需求
- (void)setTaskDidFinishCollectingMetricsBlock:(void (^)(NSURLSession * _Nonnull, NSURLSessionTask * _Nonnull, NSURLSessionTaskMetrics * _Nullable))block AF_API_AVAILABLE(ios(10), macosx(10.12), watchos(3), tvos(10)) {
    self.taskDidFinishCollectingMetrics = block;
}
#endif

#pragma mark -

- (void)setDataTaskDidReceiveResponseBlock:(NSURLSessionResponseDisposition (^)(NSURLSession *session, NSURLSessionDataTask *dataTask, NSURLResponse *response))block {
    self.dataTaskDidReceiveResponse = block;
}


/// 是 NSURLSessionDataTask 类的方法，用于设置一个回调块，该块会在普通的数据任务 (NSURLSessionDataTask) 转变为下载任务 (NSURLSessionDownloadTask) 时被调用。这种情况可能发生在服务器响应指示应该使用下载任务来接收响应体时
/// @param block 一个没有返回值的块，带有三个参数，用于在数据任务转变为下载任务时被调用。参数包括：
///             session：包含这个任务的 NSURLSession 对象。
///             dataTask：原始的数据任务。
///             downloadTask：转变后的下载任务
- (void)setDataTaskDidBecomeDownloadTaskBlock:(void (^)(NSURLSession *session, NSURLSessionDataTask *dataTask, NSURLSessionDownloadTask *downloadTask))block {
    self.dataTaskDidBecomeDownloadTask = block;
}

///  是 NSURLSessionDataTask 类的方法，用于设置一个回调块，该块在接收到部分数据时被调用。这个方法提供了一个途径，允许你在每次接收到数据时执行一些操作
/// @param block block：一个没有返回值的块，带有三个参数，用于在接收到部分数据时被调用。参数包括：
///             session：包含这个任务的 NSURLSession 对象。
///             dataTask：原始的数据任务。
///             data：接收到的部分数据
- (void)setDataTaskDidReceiveDataBlock:(void (^)(NSURLSession *session, NSURLSessionDataTask *dataTask, NSData *data))block {
    self.dataTaskDidReceiveData = block;
}

/// 通过调用这个方法，你可以为NSURLSession数据任务设置一个回调块，以便在任务将要缓存响应时执行特定的操作。这种回调机制允许你在任务的特定事件发生时插入自定义逻辑，以适应你的应用程序的需求
- (void)setDataTaskWillCacheResponseBlock:(NSCachedURLResponse * (^)(NSURLSession *session, NSURLSessionDataTask *dataTask, NSCachedURLResponse *proposedResponse))block {
    self.dataTaskWillCacheResponse = block;
}

#pragma mark -

- (void)setDownloadTaskDidFinishDownloadingBlock:(NSURL * (^)(NSURLSession *session, NSURLSessionDownloadTask *downloadTask, NSURL *location))block {
    self.downloadTaskDidFinishDownloading = block;
}

/// 是 NSURLSessionDownloadTask 类的方法，用于设置一个回调块，该块在下载任务写入数据时被调用。这个方法提供了一个途径，允许你在下载任务每次写入数据时执行一些操作，例如用于实时监视下载进度
/// @param block block：一个没有返回值的块，带有五个参数，用于在下载任务写入数据时被调用。参数包括：
///             session：包含这个任务的 NSURLSession 对象。
///             downloadTask：下载任务。
///             bytesWritten：本次写入的字节数。
///             totalBytesWritten：到目前为止已经写入的总字节数。
///             totalBytesExpectedToWrite：总共要写入的字节数，可能是未知的（如果服务器未提供 Content-Length）
- (void)setDownloadTaskDidWriteDataBlock:(void (^)(NSURLSession *session, NSURLSessionDownloadTask *downloadTask, int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite))block {
    self.downloadTaskDidWriteData = block;
}

- (void)setDownloadTaskDidResumeBlock:(void (^)(NSURLSession *session, NSURLSessionDownloadTask *downloadTask, int64_t fileOffset, int64_t expectedTotalBytes))block {
    self.downloadTaskDidResume = block;
}

#pragma mark - NSObject

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p, session: %@, operationQueue: %@>", NSStringFromClass([self class]), self, self.session, self.operationQueue];
}

- (BOOL)respondsToSelector:(SEL)selector {
    if (selector == @selector(URLSession:didReceiveChallenge:completionHandler:)) {
        return self.sessionDidReceiveAuthenticationChallenge != nil;
    } else if (selector == @selector(URLSession:task:willPerformHTTPRedirection:newRequest:completionHandler:)) {
        return self.taskWillPerformHTTPRedirection != nil;
    } else if (selector == @selector(URLSession:dataTask:didReceiveResponse:completionHandler:)) {
        return self.dataTaskDidReceiveResponse != nil;
    } else if (selector == @selector(URLSession:dataTask:willCacheResponse:completionHandler:)) {
        return self.dataTaskWillCacheResponse != nil;
    }
#if !TARGET_OS_OSX
    else if (selector == @selector(URLSessionDidFinishEventsForBackgroundURLSession:)) {
        return self.didFinishEventsForBackgroundURLSession != nil;
    }
#endif
    
    return [[self class] instancesRespondToSelector:selector];
}

#pragma mark - NSURLSessionDelegate

/// 当前这个session已经失效时，该代理方法被调用。
/*
 如果你使用finishTasksAndInvalidate函数使该session失效，
 那么session首先会先完成最后一个task，然后再调用URLSession:didBecomeInvalidWithError:代理方法，
 如果你调用invalidateAndCancel方法来使session失效，那么该session会立即调用上面的代理方法。
 */

/// 这个方法是NSURLSessionDelegate协议中的一部分，通过实现该协议，你可以接收有关NSURLSession的事件和状态变化的通知。
/// 在这个具体的方法中，当会话失效时，会调用这个代理方法，使得你的应用程序能够响应并处理失效的情况。
/// 你可以在这个方法中执行一些清理操作或记录日志，以适应你的应用程序的需求
/// @param session 表示会话对象本身，通常是发起请求的NSURLSession实例
/// @param error 表示导致会话失效的错误信息。如果会话未因错误而失效，则此参数为nil
- (void)URLSession:(NSURLSession *)session
didBecomeInvalidWithError:(NSError *)error
{
    if (self.sessionDidBecomeInvalid) {
        self.sessionDidBecomeInvalid(session, error);
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:AFURLSessionDidInvalidateNotification object:session];
}

///https 认证
- (void)URLSession:(NSURLSession *)session
didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler
{
    NSAssert(self.sessionDidReceiveAuthenticationChallenge != nil, @"`respondsToSelector:` implementation forces `URLSession:didReceiveChallenge:completionHandler:` to be called only if `self.sessionDidReceiveAuthenticationChallenge` is not nil");
    
    //挑战处理类型为 默认
    /*
     NSURLSessionAuthChallengePerformDefaultHandling：默认方式处理
     NSURLSessionAuthChallengeUseCredential：使用指定的证书
     NSURLSessionAuthChallengeCancelAuthenticationChallenge：取消挑战
     */
    
    NSURLCredential *credential = nil;
    NSURLSessionAuthChallengeDisposition disposition = self.sessionDidReceiveAuthenticationChallenge(session, challenge, &credential);
    
    if (completionHandler) {
        completionHandler(disposition, credential);
    }
}

#pragma mark - NSURLSessionTaskDelegate

//  被服务器重定向的时候调用
/// 在这个方法中，你有机会检查重定向的响应和新的请求，并根据需要修改新请求的属性。
/// 然后，通过调用completionHandler块，你可以告诉NSURLSession继续执行请求，进一步处理HTTP重定向。
/// 这样的回调机制允许你在重定向过程中插入自定义逻辑，以适应你的应用程序的需求
/// @param session 表示会话对象本身，通常是发起请求的NSURLSession实例
/// @param task 表示与HTTP重定向相关的NSURLSessionTask对象
/// @param response 表示发生HTTP重定向时接收到的响应，是一个NSHTTPURLResponse对象
/// @param request 表示新的重定向请求，是一个NSURLRequest对象。你可以通过修改这个请求来定制重定向的行为
/// @param completionHandler 这是一个块（block）参数，用于通知NSURLSession继续处理重定向。你需要调用这个块，并将新的NSURLRequest作为参数传递给它，以便继续执行重定向。如果你不调用这个块，请求将不会继续执行
- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
willPerformHTTPRedirection:(NSHTTPURLResponse *)response
        newRequest:(NSURLRequest *)request
 completionHandler:(void (^)(NSURLRequest *))completionHandler
{
    NSURLRequest *redirectRequest = request;
    
    // step1. 看是否有对应的user block 有的话转发出去，通过这4个参数，返回一个NSURLRequest类型参数，request转发、网络重定向.
    if (self.taskWillPerformHTTPRedirection) {
        //用自己自定义的一个重定向的block实现，返回一个新的request
        redirectRequest = self.taskWillPerformHTTPRedirection(session, task, response, request);
    }
    
    if (completionHandler) {
        // step2. 用request重新请求
        completionHandler(redirectRequest);
    }
}

///https认证
- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler
{
    BOOL evaluateServerTrust = NO;
    //挑战处理类型为 默认
    /*
     NSURLSessionAuthChallengePerformDefaultHandling：默认方式处理
     NSURLSessionAuthChallengeUseCredential：使用指定的证书
     NSURLSessionAuthChallengeCancelAuthenticationChallenge：取消挑战
     */
    NSURLSessionAuthChallengeDisposition disposition = NSURLSessionAuthChallengePerformDefaultHandling;
    NSURLCredential *credential = nil;
    
    if (self.authenticationChallengeHandler) {
        id result = self.authenticationChallengeHandler(session, task, challenge, completionHandler);
        if (result == nil) {
            return;
        } else if ([result isKindOfClass:NSError.class]) {
            objc_setAssociatedObject(task, AuthenticationChallengeErrorKey, result, OBJC_ASSOCIATION_RETAIN);
            disposition = NSURLSessionAuthChallengeCancelAuthenticationChallenge;
        } else if ([result isKindOfClass:NSURLCredential.class]) {
            credential = result;
            disposition = NSURLSessionAuthChallengeUseCredential;
        } else if ([result isKindOfClass:NSNumber.class]) {
            disposition = [result integerValue];
            NSAssert(disposition == NSURLSessionAuthChallengePerformDefaultHandling || disposition == NSURLSessionAuthChallengeCancelAuthenticationChallenge || disposition == NSURLSessionAuthChallengeRejectProtectionSpace, @"");
            evaluateServerTrust = disposition == NSURLSessionAuthChallengePerformDefaultHandling && [challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust];
        } else {
            @throw [NSException exceptionWithName:@"Invalid Return Value" reason:@"The return value from the authentication challenge handler must be nil, an NSError, an NSURLCredential or an NSNumber." userInfo:nil];
        }
    } else {
        // 此处服务器要求客户端的接收认证挑战方法是NSURLAuthenticationMethodServerTrust
        // 也就是说服务器端需要客户端返回一个根据认证挑战的保护空间提供的信任（即challenge.protectionSpace.serverTrust）产生的挑战证书。
        evaluateServerTrust = [challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust];
    }
    
    if (evaluateServerTrust) {
        // 基于客户端的安全策略来决定是否信任该服务器，不信任的话，也就没必要响应挑战
        if ([self.securityPolicy evaluateServerTrust:challenge.protectionSpace.serverTrust forDomain:challenge.protectionSpace.host]) {
            //证书挑战
            disposition = NSURLSessionAuthChallengeUseCredential;
            // 创建挑战证书（注：挑战方式为UseCredential和PerformDefaultHandling都需要新建挑战证书）
            credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
        } else {
            objc_setAssociatedObject(task, AuthenticationChallengeErrorKey,
                                     [self serverTrustErrorForServerTrust:challenge.protectionSpace.serverTrust url:task.currentRequest.URL],
                                     OBJC_ASSOCIATION_RETAIN);
            //默认挑战
            disposition = NSURLSessionAuthChallengeCancelAuthenticationChallenge;
        }
    }
    
    //完成挑战
    if (completionHandler) {
        completionHandler(disposition, credential);
    }
}


/// 在这个方法中，可能的操作包括检查服务器信任（SSL证书验证）的结果，并根据需要生成一个NSError对象。
/// 这可以用于处理服务器信任失败的情况，例如SSL证书不匹配、证书过期等。
/// 在生成错误对象时，你可以设置适当的错误代码、描述和其他有关错误的信息。
/// @param serverTrust  表示服务器信任的SecTrustRef对象。这通常是由服务器返回的SSL证书链，用于验证服务器的身份
/// @param url 表示与服务器信任相关的URL。这是一个NSURL对象，用于与服务器建立连接的URL
- (nonnull NSError *)serverTrustErrorForServerTrust:(nullable SecTrustRef)serverTrust url:(nullable NSURL *)url
{
    NSBundle *CFNetworkBundle = [NSBundle bundleWithIdentifier:@"com.apple.CFNetwork"];
    NSString *defaultValue = @"The certificate for this server is invalid. You might be connecting to a server that is pretending to be “%@” which could put your confidential information at risk.";
    NSString *descriptionFormat = NSLocalizedStringWithDefaultValue(@"Err-1202.w", nil, CFNetworkBundle, defaultValue, @"") ?: defaultValue;
    NSString *localizedDescription = [descriptionFormat componentsSeparatedByString:@"%@"].count <= 2 ? [NSString localizedStringWithFormat:descriptionFormat, url.host] : descriptionFormat;
    NSMutableDictionary *userInfo = [@{
        NSLocalizedDescriptionKey: localizedDescription
    } mutableCopy];
    
    if (serverTrust) {
        userInfo[NSURLErrorFailingURLPeerTrustErrorKey] = (__bridge id)serverTrust;
    }
    
    if (url) {
        userInfo[NSURLErrorFailingURLErrorKey] = url;
        
        if (url.absoluteString) {
            userInfo[NSURLErrorFailingURLStringErrorKey] = url.absoluteString;
        }
    }
    
    return [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorServerCertificateUntrusted userInfo:userInfo];
}

//当一个session task需要发送一个新的request body stream到服务器端的时候，调用该代理方法。
/// 在这个方法中，你需要实现提供新请求体流的逻辑，并通过调用completionHandler块来传递NSInputStream对象。
/// 这个块的调用告诉NSURLSession你已经准备好提供请求体流了
/// 这种回调机制允许你在需要时动态地提供请求体流，例如，当你需要上传较大的请求体数据时，可以将数据从流中逐步读取，而不是一次性加载到内存中
/// @param session 表示会话对象本身，通常是发起请求的NSURLSession实例
/// @param task 表示与请求体流相关的NSURLSessionTask对象
/// @param completionHandler 这是一个块（block）参数，用于通知NSURLSession需要一个新的请求体流。你需要在这个块中提供一个NSInputStream对象，该流对象将用于提供任务的请求体数据
- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
 needNewBodyStream:(void (^)(NSInputStream *bodyStream))completionHandler
{
    NSInputStream *inputStream = nil;
    
    //有自定义的taskNeedNewBodyStream,用自定义的，不然用task里原始的stream
    if (self.taskNeedNewBodyStream) {
        inputStream = self.taskNeedNewBodyStream(session, task);
    } else if (task.originalRequest.HTTPBodyStream && [task.originalRequest.HTTPBodyStream conformsToProtocol:@protocol(NSCopying)]) {
        inputStream = [task.originalRequest.HTTPBodyStream copy];
    }
    
    if (completionHandler) {
        completionHandler(inputStream);
    }
}

//周期性地通知代理发送到服务器端数据的进度
/// 这个方法会在任务发送请求体数据时被调用，提供了关于数据发送进度的信息。
/// 通过这些参数，你可以了解到发送请求体的实时进度，以及总体的期望进度。
/// 这对于监控上传进度、更新用户界面或执行其他与请求体数据相关的操作非常有用
/// @param session 表示会话对象本身，通常是发起请求的NSURLSession实例
/// @param task 表示与请求体数据发送相关的NSURLSessionTask对象
/// @param bytesSent 表示最近一次发送的字节数
/// @param totalBytesSent 表示到目前为止已经发送的总字节数
/// @param totalBytesExpectedToSend 表示请求体的总字节数，也就是整个请求体的大小
- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
   didSendBodyData:(int64_t)bytesSent
    totalBytesSent:(int64_t)totalBytesSent
totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend
{
    // 如果totalUnitCount获取失败，就使用HTTP header中的Content-Length作为totalUnitCount
    int64_t totalUnitCount = totalBytesExpectedToSend;
    if (totalUnitCount == NSURLSessionTransferSizeUnknown) {
        //这行代码的目的是检索与任务相关的原始请求中"Content-Length"字段的值。
        //这个值可以用于获取请求体的长度信息，对于上传任务来说，这可能对监控上传进度等场景很有用。
        //需要注意的是，如果"Content-Length"字段在原始请求中未设置，该方法可能返回nil
        NSString *contentLength = [task.originalRequest valueForHTTPHeaderField:@"Content-Length"];
        if (contentLength) {
            totalUnitCount = (int64_t) [contentLength longLongValue];
        }
    }
    
    AFURLSessionManagerTaskDelegate *delegate = [self delegateForTask:task];
    
    if (delegate) {
        [delegate URLSession:session task:task didSendBodyData:bytesSent totalBytesSent:totalBytesSent totalBytesExpectedToSend:totalBytesExpectedToSend];
    }
    
    if (self.taskDidSendBodyData) {
        self.taskDidSendBodyData(session, task, bytesSent, totalBytesSent, totalUnitCount);
    }
}

/*
 task完成之后的回调，成功和失败都会回调这里
 函数讨论：
 注意这里的error不会报告服务期端的error，他表示的是客户端这边的eroor，比如无法解析hostname或者连不上host主机。
 */
- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error
{
    //根据task去取我们一开始创建绑定的delegate
    AFURLSessionManagerTaskDelegate *delegate = [self delegateForTask:task];
    
    // delegate may be nil when completing a task in the background
    if (delegate) {
        //把代理转发给我们绑定的delegate
        [delegate URLSession:session task:task didCompleteWithError:error];
        //转发完移除delegate
        [self removeDelegateForTask:task];
    }
    
    // 自定义Block回调
    if (self.taskDidComplete) {
        self.taskDidComplete(session, task, error);
    }
}
//表示仅当 AF_CAN_INCLUDE_SESSION_TASK_METRICS 宏已定义时才包含这部分代码。
#if AF_CAN_INCLUDE_SESSION_TASK_METRICS
/// 责处理在收集了NSURLSession任务指标（metrics）后调用的逻辑
- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics AF_API_AVAILABLE(ios(10), macosx(10.12), watchos(3), tvos(10))
{
    AFURLSessionManagerTaskDelegate *delegate = [self delegateForTask:task];
    // Metrics may fire after URLSession:task:didCompleteWithError: is called, delegate may be nil
    if (delegate) {
        [delegate URLSession:session task:task didFinishCollectingMetrics:metrics];
    }
    
    if (self.taskDidFinishCollectingMetrics) {
        self.taskDidFinishCollectingMetrics(session, task, metrics);
    }
}
#endif

#pragma mark - NSURLSessionDataDelegate

/// 告诉代理，该data task获取到了服务器端传回的最初始回复（response）
/// @param session <#session description#>
/// @param dataTask <#dataTask description#>
/// @param response <#response description#>
/// @param completionHandler 通过传入一个类型为NSURLSessionResponseDisposition的变量来决定该传输任务接下来该做什么：
/// NSURLSessionResponseAllow 该task正常进行 NSURLSessionResponseCancel 该task会被取消
/// NSURLSessionResponseBecomeDownload 会调用URLSession:dataTask:didBecomeDownloadTask:方法来新建一个download task以代替当前的data task
/// NSURLSessionResponseBecomeStream 转成一个StreamTask
 /**
  讨论：
  函数讨论：
  该方法是可选的，除非你必须支持“multipart/x-mixed-replace”类型的content-type。因为如果你的request中包含了这种类型的content-type，服务器会将数据分片传回来，而且每次传回来的数据会覆盖之前的数据。每次返回新的数据时，session都会调用该函数，你应该在这个函数中合理地处理先前的数据，否则会被新数据覆盖。如果你没有提供该方法的实现，那么session将会继续任务，也就是说会覆盖之前的数据。
  */
- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler
{
    //设置默认为继续进行
    NSURLSessionResponseDisposition disposition = NSURLSessionResponseAllow;
    
    //自定义去设置
    if (self.dataTaskDidReceiveResponse) {
        disposition = self.dataTaskDidReceiveResponse(session, dataTask, response);
    }
    
    if (completionHandler) {
        completionHandler(disposition);
    }
}

//代理如果设置为NSURLSessionResponseBecomeDownload，则会调用这个方法
/// 这个方法在数据任务需要转变为下载任务时被调用。
/// 这种转变可能发生在服务器返回一个重定向的时候，或者在需要处理数据时（例如，数据任务的响应体被写入到临时文件）
/// @param session 表示会话对象本身，通常是发起请求的 NSURLSession 实例
/// @param dataTask 表示原始的数据任务 (NSURLSessionDataTask) 对象
/// @param downloadTask 表示已经转变为下载任务
- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
didBecomeDownloadTask:(NSURLSessionDownloadTask *)downloadTask
{
    //因为转变了task，所以要对task做一个重新绑定
    AFURLSessionManagerTaskDelegate *delegate = [self delegateForTask:dataTask];
    if (delegate) {
        [self removeDelegateForTask:dataTask];
        [self setDelegate:delegate forTask:downloadTask];
    }
    
    //执行自定义Block
    if (self.dataTaskDidBecomeDownloadTask) {
        self.dataTaskDidBecomeDownloadTask(session, dataTask, downloadTask);
    }
}

//当我们获取到数据就会调用，会被反复调用，请求到的数据就在这被拼装完整
/// 这个方法会在每次从服务器接收到数据时被调用，允许你逐步处理接收到的数据。
/// 你可以在这个方法中执行一些特定的操作，例如将数据追加到一个缓存中，实时更新下载进度，或者进行其他与数据接收相关的处理
/// 需要注意的是，该方法可能会被多次调用，每次传递一个数据块，直到整个响应体的数据都被接收完毕。
/// 在处理数据时，你可能需要合并或追加这些数据块，以获取完整的响应体数据。
/// @param session 表示会话对象本身，通常是发起请求的 NSURLSession 实例
/// @param dataTask 表示与接收到新数据相关的数据任务 (NSURLSessionDataTask) 对象
/// @param data 表示接收到的新数据，以 NSData 对象的形式提供
- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data
{
    
    AFURLSessionManagerTaskDelegate *delegate = [self delegateForTask:dataTask];
    [delegate URLSession:session dataTask:dataTask didReceiveData:data];
    
    if (self.dataTaskDidReceiveData) {
        self.dataTaskDidReceiveData(session, dataTask, data);
    }
}

//当task接收到所有期望的数据后，session会调用此代理方法。
/// 这个方法在收到响应并在缓存之前被调用，允许你有机会自定义缓存的行为。
/// 你可以在这个方法中检查响应的信息，并决定是否缓存以及是否使用自定义的缓存响应。
/// 在调用 completionHandler 块时，你可以传递一个新的 NSCachedURLResponse 对象来替代默认的缓存响应
/// @param session <#session description#>
/// @param dataTask 表示与将要缓存响应相关的数据任务
/// @param proposedResponse 表示将要被缓存的响应，是一个 NSCachedURLResponse 对象
/// @param completionHandler 这是一个块（block）参数，用于通知 NSURLSession 是否应该缓存响应以及提供自定义的缓存响应
- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
 willCacheResponse:(NSCachedURLResponse *)proposedResponse
 completionHandler:(void (^)(NSCachedURLResponse *cachedResponse))completionHandler
{
    NSCachedURLResponse *cachedResponse = proposedResponse;
    
    if (self.dataTaskWillCacheResponse) {
        cachedResponse = self.dataTaskWillCacheResponse(session, dataTask, proposedResponse);
    }
    
    if (completionHandler) {
        completionHandler(cachedResponse);
    }
}

#if !TARGET_OS_OSX
//当session中所有已经入队的消息被发送出去后，会调用该代理方法
/// 这个方法在后台会话中所有数据传输完成后被调用，用于告知代理会话已经完成所有事件。在后台会话中，数据传输可能包括下载任务或上传任务等。当所有相关的任务完成时，系统会调用此方法，通知应用程序后台会话已经完成，并且此时可以执行任何相关的后续操作。

/// 通常，在使用后台会话进行数据传输时，你需要在应用程序的委托中实现这个方法。在这个方法中，你可以执行一些与会话完成相关的逻辑，例如通知用户、执行额外的处理等。在处理完成后，可以调用与后台会话相关联的 completionHandler 块，以便系统能够及时唤醒应用程序
/// @param session 表示与后台会话相关的 NSURLSession 对象
- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session {
    if (self.didFinishEventsForBackgroundURLSession) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.didFinishEventsForBackgroundURLSession(session);
        });
    }
}
#endif

#pragma mark - NSURLSessionDownloadDelegate

//下载完成的时候调用
- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
didFinishDownloadingToURL:(NSURL *)location
{
    AFURLSessionManagerTaskDelegate *delegate = [self delegateForTask:downloadTask];
    //这个是session的，也就是全局的，后面的个人代理也会做同样的这件事
    if (self.downloadTaskDidFinishDownloading) {
        //这个是session的，也就是全局的，后面的个人代理也会做同样的这件事
        NSURL *fileURL = self.downloadTaskDidFinishDownloading(session, downloadTask, location);
        if (fileURL) {
            delegate.downloadFileURL = fileURL;
            NSError *error = nil;
            
            //从临时的下载路径移动至我们需要的路径
            if (![[NSFileManager defaultManager] moveItemAtURL:location toURL:fileURL error:&error]) {
                [[NSNotificationCenter defaultCenter] postNotificationName:AFURLSessionDownloadTaskDidFailToMoveFileNotification object:downloadTask userInfo:error.userInfo];
            } else {
                [[NSNotificationCenter defaultCenter] postNotificationName:AFURLSessionDownloadTaskDidMoveFileSuccessfullyNotification object:downloadTask userInfo:nil];
            }
            
            return;
        }
    }
    
    //转发代理
    if (delegate) {
        [delegate URLSession:session downloadTask:downloadTask didFinishDownloadingToURL:location];
    }
}

/// 周期性地通知下载进度调用
/// @param session <#session description#>
/// @param downloadTask <#downloadTask description#>
/// @param bytesWritten 表示自上次调用该方法后，接收到的数据字节数
/// @param totalBytesWritten 表示目前已经接收到的数据字节数
/// @param totalBytesExpectedToWrite 表示期望收到的文件总字节数，是由Content-Length header提供。如果没有提供，默认是NSURLSessionTransferSizeUnknown
- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    
    AFURLSessionManagerTaskDelegate *delegate = [self delegateForTask:downloadTask];
    
    if (delegate) {
        [delegate URLSession:session downloadTask:downloadTask didWriteData:bytesWritten totalBytesWritten:totalBytesWritten totalBytesExpectedToWrite:totalBytesExpectedToWrite];
    }
    
    if (self.downloadTaskDidWriteData) {
        self.downloadTaskDidWriteData(session, downloadTask, bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    }
}


/// 当下载被取消或者失败后重新恢复下载时调用
/// @param session <#session description#>
/// @param downloadTask <#downloadTask description#>
/// @param fileOffset <#fileOffset description#>
/// @param expectedTotalBytes <#expectedTotalBytes description#>
- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
 didResumeAtOffset:(int64_t)fileOffset
expectedTotalBytes:(int64_t)expectedTotalBytes
{
    
    AFURLSessionManagerTaskDelegate *delegate = [self delegateForTask:downloadTask];
    
    if (delegate) {
        [delegate URLSession:session downloadTask:downloadTask didResumeAtOffset:fileOffset expectedTotalBytes:expectedTotalBytes];
    }
    
    //交给自定义的Block去调用
    if (self.downloadTaskDidResume) {
        self.downloadTaskDidResume(session, downloadTask, fileOffset, expectedTotalBytes);
    }
}

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)decoder {
    NSURLSessionConfiguration *configuration = [decoder decodeObjectOfClass:[NSURLSessionConfiguration class] forKey:@"sessionConfiguration"];
    
    self = [self initWithSessionConfiguration:configuration];
    if (!self) {
        return nil;
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.session.configuration forKey:@"sessionConfiguration"];
}

#pragma mark - NSCopying

- (instancetype)copyWithZone:(NSZone *)zone {
    return [[[self class] allocWithZone:zone] initWithSessionConfiguration:self.session.configuration];
}

@end
