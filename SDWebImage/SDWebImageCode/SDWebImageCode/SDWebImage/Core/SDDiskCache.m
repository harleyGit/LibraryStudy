/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "SDDiskCache.h"
#import "SDImageCacheConfig.h"
#import "SDFileAttributeHelper.h"
#import <CommonCrypto/CommonDigest.h>

static NSString * const SDDiskCacheExtendedAttributeName = @"com.hackemist.SDDiskCache";

@interface SDDiskCache ()

@property (nonatomic, copy) NSString *diskCachePath;
@property (nonatomic, strong, nonnull) NSFileManager *fileManager;

@end

@implementation SDDiskCache

- (instancetype)init {
    NSAssert(NO, @"Use `initWithCachePath:` with the disk cache path");
    return nil;
}

#pragma mark - SDcachePathForKeyDiskCache Protocol
- (instancetype)initWithCachePath:(NSString *)cachePath config:(nonnull SDImageCacheConfig *)config {
    if (self = [super init]) {
        _diskCachePath = cachePath;
        _config = config;
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    if (self.config.fileManager) {
        self.fileManager = self.config.fileManager;
    } else {
        //同步方法在这个IO队列上进行fileManager的创建工作
        self.fileManager = [NSFileManager new];
    }
}

- (BOOL)containsDataForKey:(NSString *)key {
    NSParameterAssert(key);
    NSString *filePath = [self cachePathForKey:key];
    BOOL exists = [self.fileManager fileExistsAtPath:filePath];
    
    // fallback because of https://github.com/rs/SDWebImage/pull/976 that added the extension to the disk file name
    // checking the key with and without the extension
    if (!exists) {
        //再次去掉后缀名查询，这个问题可以自行查看上面git的问题
        exists = [self.fileManager fileExistsAtPath:filePath.stringByDeletingPathExtension];
    }
    
    return exists;
}

//根据Key获取图片的Data
- (NSData *)dataForKey:(NSString *)key {
    NSParameterAssert(key);
    NSString *filePath = [self cachePathForKey:key];
    NSData *data = [NSData dataWithContentsOfFile:filePath options:self.config.diskCacheReadingOptions error:nil];
    if (data) {
        return data;
    }
    
    // fallback because of https://github.com/rs/SDWebImage/pull/976 that added the extension to the disk file name
    // checking the key with and without the extension
    //从指定路径的文件中读取数据并返回一个 NSData 对象
    data = [NSData dataWithContentsOfFile:filePath.stringByDeletingPathExtension options:self.config.diskCacheReadingOptions error:nil];
    if (data) {
        return data;
    }
    
    return nil;
}

/// 存储图片的数据到磁盘中
- (void)setData:(NSData *)data forKey:(NSString *)key {
    NSParameterAssert(data);
    NSParameterAssert(key);
    if (![self.fileManager fileExistsAtPath:self.diskCachePath]) {
        [self.fileManager createDirectoryAtPath:self.diskCachePath withIntermediateDirectories:YES attributes:nil error:NULL];
    }
    
    // get cache Path for image key
    NSString *cachePathForKey = [self cachePathForKey:key];
    // transform to NSUrl
    NSURL *fileURL = [NSURL fileURLWithPath:cachePathForKey];
    //写入文件的方式：NSDataWritingWithoutOverwriting： 如果已存在文件，则不会覆盖原文件，写入失败; NSDataWritingAtomic 表示使用辅助文件完成原子操作
    [data writeToURL:fileURL options:self.config.diskCacheWritingOptions error:nil];
    
    // disable iCloud backup
    if (self.config.shouldDisableiCloud) {
        // ignore iCloud backup resource value error 防止文件被iCloud同步备份; 从iOS 5.1开始，应用程序可以使用文件系统中的NSURLIsExcludedFromBackupKey或者kCFURLIsExcludedFromBackupKey来避免同步文件和目录。
        //设置文件或目录资源的特定属性值。这个方法允许你修改文件或目录的元数据信息
        [fileURL setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:nil];
    }
}

/// 获取拓展属性数据
/// 对于 SDWebImage 这样的图像加载库，使用扩展属性可以存储一些额外的元数据，例如缓存的过期时间、图片格式等。这样，可以在读取缓存时，通过读取这些额外信息来判断缓存是否过期，或者获取其他与缓存相关的信息。
/// 具体来说，SDDiskCacheExtendedAttributeName 可能用于存储 SDWebImage 在缓存中保存的一些额外信息，这些信息对于缓存的管理和优化可能很有用。例如，缓存的过期时间可以帮助库在读取缓存时判断是否需要重新下载图片，以确保使用的是最新的数据。
/// @param key 图片url(或者路径)
- (NSData *)extendedDataForKey:(NSString *)key {
    NSParameterAssert(key);
    
    // get cache Path for image key
    NSString *cachePathForKey = [self cachePathForKey:key];
    
    //获取指定路径下的指定扩展属性（Extended Attribute）的值
    NSData *extendedData = [SDFileAttributeHelper extendedAttribute:SDDiskCacheExtendedAttributeName atPath:cachePathForKey traverseLink:NO error:nil];
    
    return extendedData;
}

- (void)setExtendedData:(NSData *)extendedData forKey:(NSString *)key {
    NSParameterAssert(key);
    // get cache Path for image key
    NSString *cachePathForKey = [self cachePathForKey:key];
    
    if (!extendedData) {
        // Remove
        [SDFileAttributeHelper removeExtendedAttribute:SDDiskCacheExtendedAttributeName atPath:cachePathForKey traverseLink:NO error:nil];
    } else {
        // Override
        [SDFileAttributeHelper setExtendedAttribute:SDDiskCacheExtendedAttributeName value:extendedData atPath:cachePathForKey traverseLink:NO overwrite:YES error:nil];
    }
}

- (void)removeDataForKey:(NSString *)key {
    NSParameterAssert(key);
    NSString *filePath = [self cachePathForKey:key];
    [self.fileManager removeItemAtPath:filePath error:nil];
}

- (void)removeAllData {
    //获取默认的图片存储路径然后使用NSFileManager删除这个路径的所有文件及文件夹
    [self.fileManager removeItemAtPath:self.diskCachePath error:nil];
    //删除以后再创建一个空的文件夹
    [self.fileManager createDirectoryAtPath:self.diskCachePath
            withIntermediateDirectories:YES
                             attributes:nil
                                  error:NULL];
}

- (void)removeExpiredData {
    //获取磁盘缓存存储图片的路径构造为NSURL对象
    NSURL *diskCacheURL = [NSURL fileURLWithPath:self.diskCachePath isDirectory:YES];
    
    // Compute content date key to be used for tests NSURLContentModificationDateKey 是一个用于在文件系统中获取文件或目录属性的键。它对应的是文件或目录的最后修改日期
    NSURLResourceKey cacheContentDateKey = NSURLContentModificationDateKey;
    switch (self.config.diskCacheExpireType) {
        case SDImageCacheConfigExpireTypeAccessDate://表示图像在最后一次访问之后一定时间内未被使用时将被标记为过期并被删除。
            cacheContentDateKey = NSURLContentAccessDateKey;
            break;
        case SDImageCacheConfigExpireTypeModificationDate://表示图像在被添加到缓存之后一定时间内过期
            cacheContentDateKey = NSURLContentModificationDateKey;
            break;
        case SDImageCacheConfigExpireTypeCreationDate://表示图像在创建时指定的一定时间内过期。
            cacheContentDateKey = NSURLCreationDateKey;
            break;
        case SDImageCacheConfigExpireTypeChangeDate://文件或目录的最后修改日期
            cacheContentDateKey = NSURLAttributeModificationDateKey;
            break;
        default:
            break;
    }
    //后面会用到，查询文件的属性;
    //NSURLIsDirectoryKey 是一个属性键，用于在文件系统中获取文件或目录的属性。这个键对应的值是一个布尔值，表示文件是否是一个目录（文件夹）
    //NSURLTotalFileAllocatedSizeKey 是一个属性键，用于在文件系统中获取文件或目录的属性。这个键对应的值是文件或目录所占用的总分配大小，即文件占用的磁盘空间大小。
    NSArray<NSString *> *resourceKeys = @[NSURLIsDirectoryKey, cacheContentDateKey, NSURLTotalFileAllocatedSizeKey];
    
    // This enumerator prefetches useful properties for our cache files.
    //用于获取目录中文件和子目录的枚举器（enumerator）的方法。
    //这个方法可以遍历指定 URL（目录）下的所有文件和子目录，包括它们的属性。
    //includingPropertiesForKeys：一个数组，包含了你希望在枚举过程中获取的文件或子目录的属性键
    //NSDirectoryEnumerationSkipsHiddenFiles 枚举的作用是在枚举文件和子目录时跳过隐藏文件。隐藏文件通常以.开头
    NSDirectoryEnumerator *fileEnumerator = [self.fileManager enumeratorAtURL:diskCacheURL
                                               includingPropertiesForKeys:resourceKeys
                                                                  options:NSDirectoryEnumerationSkipsHiddenFiles
                                                             errorHandler:NULL];
    
    //构造过期日期，即当前时间往前maxCacheAge秒的日期
    NSDate *expirationDate = (self.config.maxDiskAge < 0) ? nil: [NSDate dateWithTimeIntervalSinceNow:-self.config.maxDiskAge];
    //缓存的文件的字典
    NSMutableDictionary<NSURL *, NSDictionary<NSString *, id> *> *cacheFiles = [NSMutableDictionary dictionary];
    //当前缓存大小
    NSUInteger currentCacheSize = 0;
    
    // Enumerate all of the files in the cache directory.  This loop has two purposes:
    //
    //  1. Removing files that are older than the expiration date.
    //  2. Storing file attributes for the size-based cleanup pass.
    //需要删除的图片的文件URL
    NSMutableArray<NSURL *> *urlsToDelete = [[NSMutableArray alloc] init];
    //遍历上面创建的那个目录迭代器
    for (NSURL *fileURL in fileEnumerator) {
        NSError *error;
        //根据resourcesKeys获取文件的相关属性
        //resourceValuesForKeys:error: 方法获取了指定文件或目录的三个属性值：是否是目录 (NSURLIsDirectoryKey)，创建日期 (NSURLCreationDateKey)，和内容修改日期 (NSURLContentModificationDateKey)。得到的结果是一个字典 resourceValues，其中包含了这些属性的值
        NSDictionary<NSString *, id> *resourceValues = [fileURL resourceValuesForKeys:resourceKeys error:&error];
        
        // Skip directories and errors.
        //有错误，然后属性为nil或者路径是个目录就continue
        if (error || !resourceValues || [resourceValues[NSURLIsDirectoryKey] boolValue]) {
            continue;
        }
        
        // Remove files that are older than the expiration date;
        //获取文件的上次修改日期，即创建日期
        NSDate *modifiedDate = resourceValues[cacheContentDateKey];
        //如果过期就加进要删除的集合中, laterDate: 返回较晚的那个日期，即两者中的最大日期。
        if (expirationDate && [[modifiedDate laterDate:expirationDate] isEqualToDate:expirationDate]) {
            [urlsToDelete addObject:fileURL];
            continue;
        }
        
        // Store a reference to this file and account for its total size.
        //获取文件的占用磁盘的大小
        NSNumber *totalAllocatedSize = resourceValues[NSURLTotalFileAllocatedSizeKey];
        //累加总缓存大小
        currentCacheSize += totalAllocatedSize.unsignedIntegerValue;
        cacheFiles[fileURL] = resourceValues;
    }
    
    //遍历要删除的过期的图片文件URL集合，并删除文件
    for (NSURL *fileURL in urlsToDelete) {
        [self.fileManager removeItemAtURL:fileURL error:nil];
    }
    
    // If our remaining disk cache exceeds a configured maximum size, perform a second
    // size-based cleanup pass.  We delete the oldest files first.
    NSUInteger maxDiskSize = self.config.maxDiskSize;
    //如果缓存策略配置了最大缓存大小，并且当前缓存的大小大于这个值则需要清理
    if (maxDiskSize > 0 && currentCacheSize > maxDiskSize) {
        // Target half of our maximum cache size for this cleanup pass.
        //清理到只占用最大缓存大小的一半
        const NSUInteger desiredCacheSize = maxDiskSize / 2;
        
        // Sort the remaining cache files by their last modification time or last access time (oldest first).
        //根据文件创建的日期排序
        NSArray<NSURL *> *sortedFiles = [cacheFiles keysSortedByValueWithOptions:NSSortConcurrent
                                                                 usingComparator:^NSComparisonResult(id obj1, id obj2) {
                                                                     return [obj1[cacheContentDateKey] compare:obj2[cacheContentDateKey]];
                                                                 }];
        
        // Delete files until we fall below our desired cache size.
        //按创建的先后顺序遍历，然后删除，直到缓存大小是最大值的一半
        for (NSURL *fileURL in sortedFiles) {
            if ([self.fileManager removeItemAtURL:fileURL error:nil]) {
                NSDictionary<NSString *, id> *resourceValues = cacheFiles[fileURL];
                NSNumber *totalAllocatedSize = resourceValues[NSURLTotalFileAllocatedSizeKey];
                currentCacheSize -= totalAllocatedSize.unsignedIntegerValue;
                
                if (currentCacheSize < desiredCacheSize) {
                    break;
                }
            }
        }
    }
}

- (nullable NSString *)cachePathForKey:(NSString *)key {
    NSParameterAssert(key);
    return [self cachePathForKey:key inPath:self.diskCachePath];
}

//计算磁盘缓存占用空间大小
- (NSUInteger)totalSize {
    NSUInteger size = 0;
    NSDirectoryEnumerator *fileEnumerator = [self.fileManager enumeratorAtPath:self.diskCachePath];
    for (NSString *fileName in fileEnumerator) {
        NSString *filePath = [self.diskCachePath stringByAppendingPathComponent:fileName];
        NSDictionary<NSString *, id> *attrs = [self.fileManager attributesOfItemAtPath:filePath error:nil];
        size += [attrs fileSize];
    }
    return size;
}

//计算磁盘缓存图片的个数
- (NSUInteger)totalCount {
    NSUInteger count = 0;
    NSDirectoryEnumerator *fileEnumerator = [self.fileManager enumeratorAtPath:self.diskCachePath];
    count = fileEnumerator.allObjects.count;
    return count;
}

#pragma mark - Cache paths

/*
根据指定的图片的key和指定文件夹路径获取图片存储的绝对路径
首先通过cachedFileNameForKey:方法根据URL获取一个MD5值作为这个图片的名称
接着在这个指定路径path后面添加这个MD5名称作为这个图片在磁盘中的绝对路径
*/
- (nullable NSString *)cachePathForKey:(nullable NSString *)key inPath:(nonnull NSString *)path {
    NSString *filename = SDDiskCacheFileNameForKey(key);
    return [path stringByAppendingPathComponent:filename];
}

- (void)moveCacheDirectoryFromPath:(nonnull NSString *)srcPath toPath:(nonnull NSString *)dstPath {
    NSParameterAssert(srcPath);//NSParameterAssert 是 Foundation 框架中的一个宏，用于在运行时对方法的参数进行断言检查。这个宏通常用于验证方法的输入参数是否满足预期条件，如果不满足，则触发断言。
    NSParameterAssert(dstPath);
    // Check if old path is equal to new path
    if ([srcPath isEqualToString:dstPath]) {
        return;
    }
    BOOL isDirectory;
    // Check if old path is directory
    if (![self.fileManager fileExistsAtPath:srcPath isDirectory:&isDirectory] || !isDirectory) {
        return;
    }
    // Check if new path is directory fileExistsAtPath:isDirectory: 方法是 NSFileManager 类的一个方法，用于判断指定路径是否存在，并且返回路径是否为目录的信息; 之所以传&isDirectory是因为要求传一个变量地址过去,用于存储返回的路径是否为目录的信息
    if (![self.fileManager fileExistsAtPath:dstPath isDirectory:&isDirectory] || !isDirectory) {
        if (!isDirectory) {
            // New path is not directory, remove file
            [self.fileManager removeItemAtPath:dstPath error:nil];//removeItemAtPath:error: 方法用于删除指定路径下的文件或目录。如果路径指向一个目录，该方法会递归删除该目录下的所有内容，包括其子目录和文件。
        }
        NSString *dstParentPath = [dstPath stringByDeletingLastPathComponent];//stringByDeletingLastPathComponent 是 NSString 类的一个方法，用于获取去除路径中最后一个文件名（或目录名）后的新路径。
        // Creates any non-existent parent directories as part of creating the directory in path
        if (![self.fileManager fileExistsAtPath:dstParentPath]) {
            [self.fileManager createDirectoryAtPath:dstParentPath withIntermediateDirectories:YES attributes:nil error:NULL];//创建目录,
        }
        // New directory does not exist, rename directory 用于将文件或目录从一个路径移动到另一个路径。这个方法会将源路径下的文件（或目录）移动到目标路径，并且它是原子的，即要么移动成功，要么不做任何改变。
        [self.fileManager moveItemAtPath:srcPath toPath:dstPath error:nil];
    } else {
        // New directory exist, merge the files 用于获取指定路径下文件和子目录的枚举器（enumerator）。该枚举器可以用来遍历指定路径下的文件和子目录。
        NSDirectoryEnumerator *dirEnumerator = [self.fileManager enumeratorAtPath:srcPath];
        NSString *file;
        while ((file = [dirEnumerator nextObject])) {//  nextObjec 获取下一个文件或子目录的名称，直到枚举器遍历完整个目录
            [self.fileManager moveItemAtPath:[srcPath stringByAppendingPathComponent:file] toPath:[dstPath stringByAppendingPathComponent:file] error:nil];
        }
        // Remove the old path
        [self.fileManager removeItemAtPath:srcPath error:nil];
    }
}

#pragma mark - Hash

#define SD_MAX_FILE_EXTENSION_LENGTH (NAME_MAX - CC_MD5_DIGEST_LENGTH * 2 - 1)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
static inline NSString * _Nonnull SDDiskCacheFileNameForKey(NSString * _Nullable key) {
    //字符串 key 转换为 UTF-8 编码的 C 字符串（char array）的操作
    const char *str = key.UTF8String;
    if (str == NULL) {
        str = "";
    }
    //创建一个C语言的字符数组，用来接收加密结束之后的字符
    unsigned char r[CC_MD5_DIGEST_LENGTH];
    //MD5计算（也就是加密）
    //第一个参数：需要加密的字符串
    //第二个参数：需要加密的字符串的长度
    //第三个参数：加密完成之后的字符串存储的地方
    CC_MD5(str, (CC_LONG)strlen(str), r);
    NSURL *keyURL = [NSURL URLWithString:key];
    NSString *ext = keyURL ? keyURL.pathExtension : key.pathExtension;
    // File system has file name length limit, we need to check if ext is too long, we don't add it to the filename
    if (ext.length > SD_MAX_FILE_EXTENSION_LENGTH) {
        ext = nil;
    }
    NSString *filename = [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%@",
                          r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[10],
                          r[11], r[12], r[13], r[14], r[15], ext.length == 0 ? @"" : [NSString stringWithFormat:@".%@", ext]];
    return filename;
}
#pragma clang diagnostic pop

@end
