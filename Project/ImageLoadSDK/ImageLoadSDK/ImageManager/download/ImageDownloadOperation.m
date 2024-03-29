//
//  ImageDownloadOperation.m
//  ImageLoadSDK
//
//  Created by Harley Huang on 27/11/2020.
//

#import "ImageDownloadOperation.h"
#import "ImageProgressiveCoder.h"

#define LOCK(lock) dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
#define UNLOCK(lock) dispatch_semaphore_signal(lock);
typedef NSMutableDictionary<NSString *, id> ImageCallbackDictionary;
static NSString *const kImageProgressCallback = @"kImageProgressCallback";
static NSString *const kImageCompletionCallback = @"kImageCompletionCallback";


@interface ImageDownloadOperation ()<NSURLSessionDelegate, NSURLSessionTaskDelegate>

@property (nonatomic, strong) NSURLRequest *request;
@property (nonatomic, assign) NSUInteger options;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSURLSessionDataTask *dataTask;
@property (nonatomic, strong) NSMutableArray *callbackBlocks;
@property (nonatomic, strong) dispatch_semaphore_t callbacksLock;
@property (nonatomic, assign, getter=isFinished) BOOL finished;
@property (nonatomic, assign) NSInteger expectedSize;
@property (nonatomic, strong) NSMutableData *imageData;
@property (nonatomic, strong) ImageProgressiveCoder *progressiveCoder;

@end


@implementation ImageDownloadOperation
@synthesize finished = _finished;


- (instancetype)initWithRequest:(NSURLRequest *)request options:(ImageOptions)options{
    if (self = [super init]) {
        self.request = request;
        self.options = options;
        self.callbackBlocks = [NSMutableArray new];
        self.callbacksLock = dispatch_semaphore_create(1);
    }
    return self;
}

#pragma mark - callbacks
- (id)addProgressHandler:(ImageDownloadProgressBlock)progressBlock withCompletionBlock:(ImageDownloadCompletionBlock)completionBlock {
    ImageCallbackDictionary *callback = [NSMutableDictionary new];
    if(progressBlock) [callback setObject:[progressBlock copy] forKey:kImageProgressCallback];
    if(completionBlock) [callback setObject:[completionBlock copy] forKey:kImageCompletionCallback];
    LOCK(self.callbacksLock);
    [self.callbackBlocks addObject:callback];
    UNLOCK(self.callbacksLock);
    return callback;
}

- (nullable NSArray *)callbacksForKey:(NSString *)key {
    LOCK(self.callbacksLock);
    //valueForKey：https://blog.csdn.net/Baby_come_here/article/details/75797669
    NSMutableArray *callbacks = [[self.callbackBlocks valueForKey:key] mutableCopy];
    UNLOCK(self.callbacksLock);
    [callbacks removeObject:[NSNull null]];
    return [callbacks copy];
}

#pragma mark - cancel
- (BOOL)cancelWithToken:(id)token {
    BOOL shouldCancelTask = NO;
    LOCK(self.callbacksLock);
    [self.callbackBlocks removeObjectIdenticalTo:token];
    if (self.callbackBlocks.count == 0) {
        shouldCancelTask = YES;
    }
    UNLOCK(self.callbacksLock);
    if (shouldCancelTask) {
        [self cancel];
    }
    return shouldCancelTask;
}

#pragma mark - NSOperation
- (void)start {
    if (self.isCancelled) {//任务是否被取消
        self.finished = YES;
        [self reset];
        return;
    }
    
    if (!self.session) {
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        self.session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
    }
    self.dataTask = [self.session dataTaskWithRequest:self.request];
    [self.dataTask resume];
    
    for (ImageDownloadProgressBlock progressBlock in [self callbacksForKey:kImageProgressCallback]){
        progressBlock(0, NSURLResponseUnknownLength, self.request.URL);
    }
}

- (void)cancel {
    if (self.finished) {
        return;
    }
    [super cancel];
    if (self.dataTask) {
        //取消任务
        [self.dataTask cancel];
    }
    [self reset];
}

- (void)reset {
    LOCK(self.callbacksLock);
    [self.callbackBlocks removeAllObjects];
    UNLOCK(self.callbacksLock);
    
    self.dataTask = nil;
    if (self.session) {
        //取消所有未完成的任务，然后使会话无效。
        [self.session invalidateAndCancel];
        self.session = nil;
    }
}

- (void)done {
    self.finished = YES;
    [self reset];
}

#pragma mark - NSURLSessionDataDelegate
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    NSInteger expectedSize = (NSInteger)response.expectedContentLength;
    self.expectedSize = expectedSize > 0 ? expectedSize : 0;
    for (ImageDownloadProgressBlock progressBlock in [self callbacksForKey:kImageProgressCallback]) {
        progressBlock(0, self.expectedSize, self.request.URL);
    }
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    if (!self.imageData) {
        self.imageData = [[NSMutableData alloc] initWithCapacity:self.expectedSize];
    }
    [self.imageData appendData:data];
    for (ImageDownloadProgressBlock progressBlock in [self callbacksForKey:kImageProgressCallback]) {
        progressBlock(self.imageData.length, self.expectedSize, self.request.URL);
    }
    
    if (self.expectedSize > 0 && (self.options & ImageOptionProgressive)) {
        if (!self.progressiveCoder) {
            self.progressiveCoder = [[ImageProgressiveCoder alloc] init];
        }

        NSData *imageData = [self.imageData copy];
        NSInteger totalSize = imageData.length;
        BOOL finished = totalSize >= self.expectedSize;
        UIImage *image = [self.progressiveCoder progressiveDecodedImageWithData:imageData finished:finished];
        for (ImageDownloadCompletionBlock block in [self callbacksForKey:kImageCompletionCallback]) {
            block(image ,nil, nil, finished);
        }
    }
}

#pragma mark - NSURLSessionTaskDelgate
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    for (ImageDownloadCompletionBlock completionBlock in [self callbacksForKey:kImageCompletionCallback]) {
        completionBlock(nil, [self.imageData copy], error, YES);
    }
    [self done];
}

#pragma mark - ImageOperation
- (void)cancelOperation {
    [self cancel];
}

#pragma mark - setter
- (void)setFinished:(BOOL)finished {
    [self willChangeValueForKey:@"isFinished"];
    _finished = finished;
    [self didChangeValueForKey:@"isFinished"];
}


@end
