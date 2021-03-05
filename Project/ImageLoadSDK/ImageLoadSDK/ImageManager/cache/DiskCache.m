//
//  DiskCache.m
//  ImageLoadSDK
//
//  Created by Harley Huang on 26/11/2020.
//

#import <CommonCrypto/CommonCrypto.h>
#import "DiskCache.h"


@interface DiskCache ()

@property (nonatomic, copy) NSString *diskPath;
@property (nonatomic, strong) NSFileManager *fileManager;
//maxCacheAge实现流程：根据设置的存活时间计算出文件可保留的最早时间->遍历文件，进行时间比对->若文件被访问的时间早于最早时间，那么删除对应的文件
@property (nonatomic, assign) NSInteger maxCacheAge;
//maxCacheSize实现流程：遍历文件计算文件总大小->若文件总大小超过限制的大小，则对文件按被访问的时间顺序进行排序->逐一删除文件，直到小于总限制的一半为止。
@property (nonatomic, assign) NSInteger maxCacheSize;

@end

@implementation DiskCache


- (instancetype)initWithPath:(NSString *)path withConfig:(ImageCacheConfig *)config{
    if (self = [super init]) {
        if (path) {
            self.diskPath = path;
        } else {
            self.diskPath = [self defaultDiskPath];
        }
        if (config) {
            self.maxCacheAge = config.maxCacheAge;
            self.maxCacheSize = config.maxCacheSize;
        } else {
            self.maxCacheSize = NSIntegerMax;
            self.maxCacheAge = NSIntegerMax;
        }
        self.fileManager = [NSFileManager new];
    }
    return self;
}

#pragma mark - DiskCacheDelegate
- (void)storeImageData:(NSData *)imageData forKey:(NSString *)key {
    if (!imageData || !key || key.length == 0) {
        return;
    }
    
    if (![self.fileManager fileExistsAtPath:self.diskPath]) {
        [self.fileManager createDirectoryAtPath:self.diskPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSString *filePath = [self.diskPath stringByAppendingPathComponent:[self cachedFileNameForKey:key]];
    NSURL *fileURL = [NSURL fileURLWithPath:filePath];
    [imageData writeToURL:fileURL atomically:YES];
}

- (BOOL)containImageDataForKey:(NSString *)key {
    if (!key || key.length == 0) {
        return NO;
    }
    
    NSString *filePath = [self filePathForKey:key];
    BOOL contained = [self.fileManager fileExistsAtPath:filePath];
    if (!contained) {
        contained = [self.fileManager fileExistsAtPath:filePath.stringByDeletingPathExtension];
    }
    return contained;
}

- (BOOL)removeImageDataForKey:(NSString *)key {
    if (!key || key.length == 0) {
        return NO;
    }
    
    NSString *filePath = [self filePathForKey:key];
    return [self.fileManager removeItemAtPath:filePath error:nil];
}

- (NSData *)queryImageDataForKey:(NSString *)key {
    if (!key || key.length == 0) {
        return nil;
    }
    
    NSString *filePath = [self filePathForKey:key];
    NSData *data = [NSData dataWithContentsOfFile:filePath];
    return data;
}

- (void)clearDiskCache {
    NSError *error;
    [self.fileManager removeItemAtPath:self.diskPath error:&error];
    if (error) {
        NSLog(@"clear disk cache fail: %@", error ? error.description : @"");
    }
}


/**
 *何时触发deleteOldFiles函数，以保证磁盘缓存中的maxCacheAge和maxCacheSize
 *可以考虑在应用进入后台时，启动后台任务去完成检查和清理工作
 */
- (void)deleteOldFiles {
    
    NSLog(@"💣 start clean up old files");
    
    NSURL *diskCacheURL = [NSURL fileURLWithPath:self.diskPath isDirectory:YES];
    NSArray<NSString *> *resourceKeys = @[NSURLIsDirectoryKey, NSURLContentAccessDateKey, NSURLTotalFileAllocatedSizeKey];
    //获取到所有的文件以及文件属性
    NSDirectoryEnumerator *fileEnumerator = [self.fileManager enumeratorAtURL:diskCacheURL includingPropertiesForKeys:resourceKeys options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:NULL];
    //计算出文件可保留的最早时间
    NSDate *expirationDate = [NSDate dateWithTimeIntervalSinceNow:-self.maxCacheAge];
    NSMutableArray <NSURL *> *deleteURLs = [NSMutableArray array];
    NSMutableDictionary<NSURL *, NSDictionary<NSString *, id>*> *cacheFiles = [NSMutableDictionary dictionary];
    NSInteger currentCacheSize = 0;
    //遍历获取图片的内存大小
    for (NSURL *fileURL in fileEnumerator) {
        NSError *error;
        NSDictionary<NSString *, id> *resourceValues = [fileURL resourceValuesForKeys:resourceKeys error:&error];
        //错误或不存在文件属性或为文件夹的情况忽略
        if (error || !resourceValues || [resourceValues[NSURLIsDirectoryKey] boolValue]) {
            continue;
        }
        //获取到文件最近被访问的时间
        NSDate *accessDate = resourceValues[NSURLContentAccessDateKey];
        if ([accessDate earlierDate:expirationDate]) {//若早于可保留的最早时间，则加入删除列表中
            [deleteURLs addObject:fileURL];
            continue;
        }
        //获取文件的大小，并保存文件相关属性
        NSNumber *fileSize = resourceValues[NSURLTotalFileAllocatedSizeKey];
        currentCacheSize += fileSize.unsignedIntegerValue;
        [cacheFiles setObject:resourceValues forKey:fileURL];
    }
    
    //删除过时文件
    for (NSURL *URL in deleteURLs) {
        NSLog(@"delete old file: %@", URL.absoluteString);
        //删除过时的文件
        [self.fileManager removeItemAtURL:URL error:nil];
    }
    
    //删除过时文件之后，若还是超过文件总大小限制，则继续删除
    if (self.maxCacheSize > 0 && currentCacheSize > self.maxCacheSize) {//超过总限制大小
        NSUInteger desiredCacheSize = self.maxCacheSize / 2;
        NSArray<NSURL *> *sortedFiles = [cacheFiles keysSortedByValueWithOptions:NSSortConcurrent usingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
            return [obj1[NSURLContentAccessDateKey] compare:obj2[NSURLContentAccessDateKey]];
        }];//对文件按照被访问时间的顺序来排序
        for (NSURL *fileURL in sortedFiles) {
            if ([self.fileManager removeItemAtURL:fileURL error:nil]) {
                NSDictionary<NSString *, id> *resourceValues = cacheFiles[fileURL];
                NSNumber *fileSize = resourceValues[NSURLTotalFileAllocatedSizeKey];
                currentCacheSize -= fileSize.unsignedIntegerValue;
                
                if (currentCacheSize < desiredCacheSize) {//达到总限制大小的一半即可停止删除
                    break;
                }
            }
        }
    }
}

#pragma mark - private method
- (NSString *)filePathForKey:(NSString *)key {
    return [self.diskPath stringByAppendingPathComponent:[self cachedFileNameForKey:key]];
}

- (NSString *)defaultDiskPath {
    NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    return [paths[0] stringByAppendingString:@"com.jimage.cache"];
}

- (NSString *)cachedFileNameForKey:(nullable NSString *)key {
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
