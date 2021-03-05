//
//  ImageDownloader.m
//  ImageLoadSDK
//
//  Created by Harley Huang on 17/11/2020.
//

#import "ImageDownloader.h"
#import "ImageCache.h"
#import "ImageCoder.h"

@implementation ImageDownloadToken

@end



#define LOCK(lock) dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
#define UNLOCK(lock) dispatch_semaphore_signal(lock);


@interface ImageDownloader()

@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSCache *imageCache;
@property (nonatomic, strong) NSOperationQueue *operationQueue;
@property (nonatomic, strong) NSMutableDictionary<NSURL *, ImageDownloadOperation *> *URLOperations;
@property (nonatomic, strong) dispatch_semaphore_t URLsLock;

@end

@implementation ImageDownloader

+ (instancetype)shareInstance {
    static ImageDownloader *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[ImageDownloader alloc] init];
        [instance setup];
    });
    return instance;
}
- (void)setup {
    self.session = [NSURLSession sharedSession];
    self.operationQueue = [[NSOperationQueue alloc] init];
    self.URLOperations = [NSMutableDictionary dictionary];
    self.URLsLock = dispatch_semaphore_create(1);
    
    self.imageCache = [[NSCache alloc] init];
}

- (ImageDownloadToken *)fetchImageWithURL:(NSString *)url options:(ImageOptions)options progressBlock:(ImageDownloadProgressBlock)progressBlock completionBlock:(ImageDownloadCompletionBlock)completionBlock {
    if (!url || url.length == 0) {
        return nil;
    }
    
    NSURL *URL = [NSURL URLWithString:url];
    if (!URL) {
        return nil;
    }
    
    LOCK(self.URLsLock);
    ImageDownloadOperation *operation = [self.URLOperations objectForKey:URL];
    if (!operation || operation.isCancelled || operation.isFinished) {
        NSURLRequest *request = [[NSURLRequest alloc] initWithURL:URL];
        operation = [[ImageDownloadOperation alloc] initWithRequest:request options:options];
        __weak typeof(self) weakSelf = self;
        operation.completionBlock = ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            LOCK(self.URLsLock);
            [strongSelf.URLOperations removeObjectForKey:URL];
            UNLOCK(self.URLsLock);
        };
        [self.operationQueue addOperation:operation];
        [self.URLOperations setObject:operation forKey:URL];
    }
    UNLOCK(self.URLsLock);
    id downloadToken = [operation addProgressHandler:progressBlock withCompletionBlock:completionBlock];
    ImageDownloadToken *token = [ImageDownloadToken new];
    token.url = URL;
    token.downloadToken = downloadToken;
    return token;
}

- (void)cancelWithToken:(ImageDownloadToken *)token {
    if (!token || !token.url) {
        return;
    }
    
    LOCK(self.URLsLock);
    ImageDownloadOperation *opertion = [self.URLOperations objectForKey:token.url];
    UNLOCK(self.URLsLock);
    if (opertion) {
        BOOL hasCancelTask = [opertion cancelWithToken:token.downloadToken];
        if (hasCancelTask) {
            LOCK(self.URLsLock);
            [self.URLOperations removeObjectForKey:token.url];
            UNLOCK(self.URLsLock);
            NSLog(@"cancle download task for url:%@", token.url ? : @"");
        }
    }
    
}


- (void)fetchImageWithURL3:(NSString *)url completion:(void (^)(UIImage * _Nullable, NSError * _Nullable))completionBlock  {
    if (!url || url.length == 0) {
        return;
    }
    NSURL *URL = [NSURL URLWithString:url];
    if (!URL) {
        return;
    }
    [[ImageCache shareManager] queryImageCacheForKey:url completionBlock:^(UIImage * _Nullable cacheImage, ImageCacheType cacheType) {
        if (cacheImage) {
            completionBlock(cacheImage, nil);
            return;
        }
        NSURLSessionDataTask *dataTask = [self.session dataTaskWithURL:URL completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            UIImage *image = nil;
            if (!error && data) {
                image = [UIImage imageWithData:data];
                if (image) {
                    [[ImageCache shareManager] storeImage2:image forKey:url];
                }
            }
            if (error) {
                NSLog(@"fetch image from net fail:%@", error.description ? : @"");
            } else {
                NSLog(@"image from network");
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(image, error);
            });
        }];
        [dataTask resume];
    }];
    
}

- (void)fetchImageWithURL2:(NSString *)url completion:(void (^)(UIImage * _Nullable, NSError * _Nullable))completionBlock {
    if (!url || url.length == 0) {
        return;
    }
    NSURL *URL = [NSURL URLWithString:url];
    if (!URL) {
        return;
    }
    UIImage *cacheImage = [[ImageCache shareManager] queryImageCacheForKey:url]; //获取缓存数据
    if (cacheImage) {
        completionBlock(cacheImage, nil);
        return;
    }
    __weak typeof (self) weakSelf = self;
    NSURLSessionDataTask *dataTask = [self.session dataTaskWithURL:URL completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        UIImage *image = nil;
        if (!error && data) {
            image = [UIImage imageWithData:data];
            __strong typeof (weakSelf) strongSelf = weakSelf;
            if (strongSelf && image) {
                [[ImageCache shareManager] storeImage2:image forKey:url]; //写入缓存中
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                NSLog(@"fetch image from net fail:%@", error.description);
            } else {
                NSLog(@"image from network");
            }
            completionBlock(image, error);
        });
    }];
    [dataTask resume];
}


- (void)fetchImageWithURL1:(NSString *)url completion:(void (^)(UIImage * _Nullable, NSError * _Nullable))completionBlock {
    if (!url || url.length == 0) {
        return;
    }
    //从缓存中获取
    UIImage *cacheImage = [self.imageCache objectForKey:url];
    if (cacheImage) {
        completionBlock(cacheImage, nil);
        
        NSLog(@"🍎 🍎 🍎：image from memory cache");
        //[MBProgressHUD showGlobalHUDWithTitle:@"image from memory cache"];
        return;
    }
    __weak typeof (self) weakSelf = self;
    NSURLSessionDataTask *dataTask = [self.session dataTaskWithURL:[NSURL URLWithString:url] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        UIImage *image = nil;
        if (!error && data) {
            image = [UIImage imageWithData:data];
            __strong typeof (weakSelf) strongSelf = weakSelf;
            if (strongSelf && image) { //将图片放置在缓存中
                [strongSelf.imageCache setObject:image forKey:url];
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                //                [MBProgressHUD showGlobalHUDWithTitle:error.description];
                NSLog(@"❌ ❌ ❌ ： %@", error.description);
            } else {
                NSLog(@"🍊 🍊 🍊 ：image from network");
                //                [MBProgressHUD showGlobalHUDWithTitle:@"image from network"];
            }
            completionBlock(image, error);
        });
    }];
    [dataTask resume];
}

@end
