//
//  ImageCache.m
//  ImageLoadSDK
//
//  Created by Harley Huang on 18/11/2020.
//

#import "ImageCache.h"
#import <CommonCrypto/CommonCrypto.h>
#import <UIKit/UIKit.h>
#import "UIImage+ImageFormat.h"
#import "DiskCache.h"
#import "ImageCoder.h"

//定义了一个关于block的宏，为了避免参数传递的block为nil，需要在使用前对block进行判断是否为nil
// __VA_ARGS__ 表示可以传递多个参数
#define SAFE_CALL_BLOCK(blockFunc, ...)    \
    if (blockFunc) {                        \
        blockFunc(__VA_ARGS__);              \
    }

@interface ImageCache ()

@property (nonatomic, strong) NSCache *imageMemoryCache;
@property (nonatomic, copy) NSString *diskCachePath;
@property (nonatomic, strong) NSFileManager *fileManager;
//文件读、写耗时，引入异步操作
@property (nonatomic, strong) dispatch_queue_t ioQueue;


@end

@implementation ImageCache


- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - init
- (instancetype)init {
    return [self initWithNameSpace:@"default"];
}

- (instancetype)initWithNameSpace:(NSString *)nameSpace {
    return [self initWithNameSpace:nameSpace diskDirectoryPath:[self diskPathWithNameSpace:nameSpace]];
}

+ (instancetype)shareManager {
    static ImageCache *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[ImageCache alloc] init];
        [instance setup];
    });
    return instance;
}


- (void)setup {
    self.imageMemoryCache = [[NSCache alloc] init];
    self.fileManager = [NSFileManager new];
    // 磁盘缓存放置图片位置
    NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    self.diskCachePath = [paths[0] stringByAppendingPathComponent:@"com.jimage.cache"];
    //串行队列
    self.ioQueue = dispatch_queue_create("com.jimage.cache", DISPATCH_QUEUE_SERIAL);
    
}

- (instancetype)initWithNameSpace:(NSString *)nameSpace diskDirectoryPath:(NSString *)directory {
    if (self = [super init]) {
        NSString *fullNameSpace = [@"com.jimage.cache" stringByAppendingString:nameSpace];
        NSString *diskPath;
        if (directory) {
            diskPath = [directory stringByAppendingPathComponent:fullNameSpace];
        } else {
            diskPath = [[self diskPathWithNameSpace:nameSpace] stringByAppendingString:fullNameSpace];
        }
        NSLog(@"✈️ 图片路径：%@ ✈️", diskPath);
        self.cacheConfig = [[ImageCacheConfig alloc] init];
        self.diskCache = [[DiskCache alloc] initWithPath:diskPath withConfig:self.cacheConfig];
        self.memoryCache = [[NSCache alloc] init];
        self.ioQueue = dispatch_queue_create("com.jimage.cache", DISPATCH_QUEUE_SERIAL);
        //注册清理图片的通知
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    }
    return self;
}


#pragma mark - private method
- (NSString *)diskPathWithNameSpace:(NSString *)namespace {
    NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    return [paths[0] stringByAppendingPathComponent:namespace];
}


- (NSOperation *)queryImageForKey:(NSString *)key cacheType:(ImageCacheType)cacheType completion:(void (^)(UIImage * _Nullable, ImageCacheType))completionBlock {
    
    if (!key || key.length == 0) {
        SAFE_CALL_BLOCK(completionBlock, nil, ImageCacheTypeNone);
        return nil;
    }
    
    NSOperation *operation = [NSOperation new];
    void(^queryBlock)(void) = ^ {//图片在内存和Disk进行查询，此过程在线程中执行
        if (operation.isCancelled) {
            NSLog(@"cancel cache query for key: %@", key ? : @"");
            return;
        }
        UIImage *image = nil;
        ImageCacheType cacheFrom = cacheType;
        if (cacheType == ImageCacheTypeMemory) {
            image = [self.memoryCache objectForKey:key];
        } else if (cacheType == ImageCacheTypeDisk) {
            NSData *data = [self.diskCache queryImageDataForKey:key];
            if (data) {
                image = [[ImageCoder shareCoder] decodeImageSyncWithData:data];
            }
        } else if (cacheType == ImageCacheTypeAll) {
            image = [self.memoryCache objectForKey:key];
            cacheFrom = ImageCacheTypeMemory;
            if (!image) {
                NSData *data = [self.diskCache queryImageDataForKey:key];
                if (data) {
                    cacheFrom = ImageCacheTypeDisk;
                    image = [[ImageCoder shareCoder] decodeImageSyncWithData:data];
                    if (image) {
                        [self.memoryCache setObject:image forKey:key cost:image.memoryCost];
                    }
                }
            }
        }
        SAFE_CALL_BLOCK(completionBlock, image, cacheFrom);
    };
    dispatch_async(self.ioQueue, queryBlock);
    return operation;
}

- (void)containImageWithKey:(NSString *)key cacheType:(ImageCacheType)cacheType completion:(void (^)(BOOL))completionBlock {
    if (!key || key.length == 0) {
        SAFE_CALL_BLOCK(completionBlock, NO);
        return;
    }
    
    void(^diskContainedBlock)(void) = ^ {
        BOOL contained = [self.diskCache containImageDataForKey:key];
        SAFE_CALL_BLOCK(completionBlock, contained);
    };
    
    if (cacheType == ImageCacheTypeMemory) {
        BOOL contained = ([self.memoryCache objectForKey:key] != nil);
        SAFE_CALL_BLOCK(completionBlock, contained);
    } else if (cacheType == ImageCacheTypeDisk) {
        dispatch_async(self.ioQueue, diskContainedBlock);
    } else if (cacheType == ImageCacheTypeAll) {
        BOOL contained = ([self.memoryCache objectForKey:key] != nil);
        if (contained) {
            SAFE_CALL_BLOCK(completionBlock, contained);
        } else {
            dispatch_async(self.ioQueue, diskContainedBlock);
        }
    } else {
        SAFE_CALL_BLOCK(completionBlock, NO);
    }
}


- (void)removeImageForKey:(NSString *)key cacheType:(ImageCacheType)cacheType completion:(void (^)(void))completionBlock {
    if (!key || key.length == 0) {
        SAFE_CALL_BLOCK(completionBlock);
        return;
    }
    
    void(^diskRemovedBlock)(void) = ^{
        [self.diskCache removeImageDataForKey:key];
        SAFE_CALL_BLOCK(completionBlock);
    };
    
    if (cacheType == ImageCacheTypeMemory) {
        [self.memoryCache removeObjectForKey:key];
        SAFE_CALL_BLOCK(completionBlock);
    } else if (cacheType == ImageCacheTypeDisk) {
        dispatch_async(self.ioQueue, diskRemovedBlock);
    } else if (cacheType == ImageCacheTypeAll) {
        [self.memoryCache removeObjectForKey:key];
        dispatch_async(self.ioQueue, diskRemovedBlock);
    } else {
        SAFE_CALL_BLOCK(completionBlock);
    }
}


- (void)clearAllWithCacheType:(ImageCacheType)cacheType completion:(void (^)(void))completionBlock {
    if (cacheType == ImageCacheTypeMemory) {
        [self.memoryCache removeAllObjects];
    } else if (cacheType == ImageCacheTypeDisk) {
        dispatch_async(self.ioQueue, ^{
            [self.diskCache clearDiskCache];
            SAFE_CALL_BLOCK(completionBlock);
        });
    } else if (cacheType == ImageCacheTypeAll) {
        [self.memoryCache removeAllObjects];
        dispatch_async(self.ioQueue, ^{
            [self.diskCache clearDiskCache];
            SAFE_CALL_BLOCK(completionBlock);
        });
    }
}

#pragma mark - backgournd task

- (void)onDidEnterBackground:(NSNotification *)notification {
    [self backgroundDeleteOldFiles];
}

- (void)backgroundDeleteOldFiles {
    Class UIApplicationClass = NSClassFromString(@"UIApplication");
    if(!UIApplicationClass || ![UIApplicationClass respondsToSelector:@selector(sharedApplication)]) {
        return;
    }
    UIApplication *application = [UIApplication performSelector:@selector(sharedApplication)];
    __block UIBackgroundTaskIdentifier bgTask = [application beginBackgroundTaskWithExpirationHandler:^{
        [application endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
    
    void(^deleteBlock)(void) = ^ {
        if ([self.diskCache respondsToSelector:@selector(deleteOldFiles)]) {
            [self.diskCache deleteOldFiles];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [application endBackgroundTask:bgTask];
            bgTask = UIBackgroundTaskInvalid;
        });
    };
    
    dispatch_async(self.ioQueue, deleteBlock);
}

- (void)queryImageCacheForKey:(NSString *)key completionBlock:(void(^)(UIImage * _Nullable, ImageCacheType))completionBlock{
    if (!key || key.length == 0) {
        completionBlock(nil, ImageCacheTypeNone);
        return;
    }
    UIImage *memoryCache = [self.imageMemoryCache objectForKey:key];
    if (memoryCache) {
        NSLog(@"image from memory cache");
        completionBlock(memoryCache, ImageCacheTypeMemory);
        return;
    }
    void(^queryDiskBlock)(void) = ^ {
        NSString *filepath = [self.diskCachePath stringByAppendingPathComponent:[self cachedFileNameForKey:key]];
        NSData *data = [NSData dataWithContentsOfFile:filepath];
        UIImage *diskCache = nil;
        ImageCacheType cacheType = ImageCacheTypeNone;
        if (data) {
            diskCache = [UIImage imageWithData:data];
            if (diskCache) {
                cacheType = ImageCacheTypeDisk;
                [self.imageMemoryCache setObject:diskCache forKey:key];
                NSLog(@"image from disk cache");
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            completionBlock(diskCache, cacheType);
        });
    };
    dispatch_async(self.ioQueue, queryDiskBlock);//加入到队列中异步处理
}

- (void)storeImage:(UIImage *)image imageData:(NSData *)imageData forKey:(NSString *)key completion:(void (^)(void))completionBlock {
    if (!key || key.length == 0 || (!image && !imageData)) {
        SAFE_CALL_BLOCK(completionBlock);
        return;
    }
    void(^storeBlock)(void) = ^ {
        if (self.cacheConfig.shouldCacheImagesInMemory) {
            if (image) {
                [self.memoryCache setObject:image forKey:key cost:image.memoryCost];
            } else if (imageData) {
                UIImage *decodedImage = [[ImageCoder shareCoder] decodeImageSyncWithData:imageData];
                if (decodedImage) {
                    [self.memoryCache setObject:decodedImage forKey:key cost:decodedImage.memoryCost];
                }
            }
        }
        if (self.cacheConfig.shouldCacheImagesInDisk) {
            if (imageData) {
                [self.diskCache storeImageData:imageData forKey:key];
            } else if (image) {
                NSData *data = [[ImageCoder shareCoder] encodedDataSyncWithImage:image];
                if (data) {
                    [self.diskCache storeImageData:data forKey:key];
                }
            }
        }
        SAFE_CALL_BLOCK(completionBlock);
    };
    dispatch_async(self.ioQueue, storeBlock);
}

- (void)storeImage2:(UIImage *)image forKey:(NSString *)key {
    if (!image || !key || key.length == 0) {
        return;
    }
    [self.imageMemoryCache setObject:image forKey:key];
    void(^storeDiskBlock)(void) = ^ {
        NSData *data = nil;
        if ([self containsAlphaWithCGImage:image.CGImage]) {
            data = UIImagePNGRepresentation(image);
        } else {
            data = UIImageJPEGRepresentation(image, 1.0);
        }
        if (!data) {
            return;
        }
        if (![self.fileManager fileExistsAtPath:self.diskCachePath]) {
            [self.fileManager createDirectoryAtPath:self.diskCachePath withIntermediateDirectories:YES attributes:nil error:nil];
        }
        NSString *cachePath = [self.diskCachePath stringByAppendingPathComponent:[self cachedFileNameForKey:key]];
        NSURL *fileURL = [NSURL fileURLWithPath:cachePath];
        NSLog(@"🍎图片路径：%@", cachePath);
        [data writeToURL:fileURL atomically:YES];
    };
    dispatch_async(self.ioQueue, storeDiskBlock);
    
}


- (UIImage *)queryImageCacheForKey:(NSString *)key {
    if (!key || key.length == 0) {
        return nil;
    }
    UIImage *memoryCache = [self.imageMemoryCache objectForKey:key];
    if (memoryCache) { //从内存缓存中获取
        NSLog(@"image from memory cache");
        return memoryCache;
    }
    NSString *filepath = [self.diskCachePath stringByAppendingPathComponent:[self cachedFileNameForKey:key]];
    NSData *data = [NSData dataWithContentsOfFile:filepath];
    if (data) {
        UIImage *diskCache = [UIImage imageWithData:data];
        NSLog(@"image from disk cache");
        if (diskCache) { //从磁盘缓存中获取
            [self.imageMemoryCache setObject:diskCache forKey:key];
        }
        return diskCache;
    }
    return nil;
}

- (void)storeImage1:(UIImage *)image forKey:(NSString *)key {
    if (!image || !key || key.length == 0) {
        return;
    }
    [self.imageMemoryCache setObject:image forKey:key]; //存储到内存中
    NSData *data = nil;
    if ([self containsAlphaWithCGImage:image.CGImage]) {
        data = UIImagePNGRepresentation(image);
    } else {
        data = UIImageJPEGRepresentation(image, 1.0);
    }
    if (!data) {
        return;
    }
    if (![self.fileManager fileExistsAtPath:self.diskCachePath]) {
        [self.fileManager createDirectoryAtPath:self.diskCachePath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSString *cachePath = [self.diskCachePath stringByAppendingPathComponent:[self cachedFileNameForKey:key]];
    NSURL *fileURL = [NSURL fileURLWithPath:cachePath];
    [data writeToURL:fileURL atomically:YES]; //存储到磁盘中
}

//根据alpha通道判断是png和jpeg格式
#pragma mark - util methods
- (BOOL)containsAlphaWithCGImage:(CGImageRef)imageRef {
    if (!imageRef) {
        return NO;
    }
    CGImageAlphaInfo alphaInfo = CGImageGetAlphaInfo(imageRef);
    BOOL hasAlpha = !(alphaInfo == kCGImageAlphaNone || alphaInfo == kCGImageAlphaNoneSkipFirst || alphaInfo == kCGImageAlphaNoneSkipLast);
    return hasAlpha;
}

//对图片的url进行MD5的hash，用url无法进行存取
- (nullable NSString *)cachedFileNameForKey:(nullable NSString *)key {
    const char *str = key.UTF8String;
    if (str == NULL) {
        str = "";
    }
    unsigned char r[16];
    CC_MD5(str, (CC_LONG)strlen(str), r);
    NSURL *keyURL = [NSURL URLWithString:key];
    NSString *ext = keyURL ? keyURL.pathExtension : key.pathExtension;
    NSString *filename = [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%@",
                          r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[10],
                          r[11], r[12], r[13], r[14], r[15], ext.length == 0 ? @"" : [NSString stringWithFormat:@".%@", ext]];
    return filename;
}








@end
