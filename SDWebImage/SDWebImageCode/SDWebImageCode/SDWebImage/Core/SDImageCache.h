/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import <Foundation/Foundation.h>
#import "SDWebImageCompat.h"
#import "SDWebImageDefine.h"
#import "SDImageCacheConfig.h"
#import "SDImageCacheDefine.h"
#import "SDMemoryCache.h"
#import "SDDiskCache.h"

/// Image Cache Options
typedef NS_OPTIONS(NSUInteger, SDImageCacheOptions) {
    /**
     * By default, we do not query image data when the image is already cached in memory. This mask can force to query image data at the same time. However, this query is asynchronously unless you specify `SDImageCacheQueryMemoryDataSync`
     * 当查询内存缓存时也同时查询图像数据
     * 如果这个选项被设置，当你从内存缓存中查询图像时，它将不仅返回图像对象本身，还会包含图像的原始二进制数据。
     * 这可以用于获取图像的原始数据而不必重新解码
     */
    SDImageCacheQueryMemoryData = 1 << 0,
    /**
     * By default, when you only specify `SDImageCacheQueryMemoryData`, we query the memory image data asynchronously. Combined this mask as well to query the memory image data synchronously.
     * 它用于在同步模式下从内存缓存中查询图像并获取图像的原始二进制数据。
     * 使用这个选项时，查询将会在当前线程同步执行，而不是异步执行。
     */
    SDImageCacheQueryMemoryDataSync = 1 << 1,
    /**
     * By default, when the memory cache miss, we query the disk cache asynchronously. This mask can force to query disk cache (when memory cache miss) synchronously.
     @note These 3 query options can be combined together. For the full list about these masks combination, see wiki page.
     * 在同步模式下查询磁盘缓存
     * 通常，查询磁盘缓存是异步进行的，因为磁盘操作可能比较慢。
     * 但是，如果你需要在主线程同步查询磁盘缓存，可以使用这个选项
     */
    SDImageCacheQueryDiskDataSync = 1 << 2,
    /**
     * By default, images are decoded respecting their original size. On iOS, this flag will scale down the
     * images to a size compatible with the constrained memory of devices.
     * ，用于配置图像缓存时是否对大尺寸的图像进行缩小处理。
     * 当这个选项被设置时，SDWebImage 在将图像存储到磁盘缓存时，会对大尺寸的图像进行缩小以减少占用的磁盘空间
     */
    SDImageCacheScaleDownLargeImages = 1 << 3,
    /**
     * By default, we will decode the image in the background during cache query and download from the network. This can help to improve performance because when rendering image on the screen, it need to be firstly decoded. But this happen on the main queue by Core Animation.
     * However, this process may increase the memory usage as well. If you are experiencing a issue due to excessive memory consumption, This flag can prevent decode the image.
     * 用于配置图像缓存时是否避免对图像进行解码。当这个选项被设置时，SDWebImage 在将图像从磁盘缓存加载到内存时，会尽量避免对图像进行解码操作。
     */
    SDImageCacheAvoidDecodeImage = 1 << 4,
    /**
     * By default, we decode the animated image. This flag can force decode the first frame only and produece the static image.
     * 用于配置图像缓存时是否只解码 GIF 图像的第一帧。
     * 当这个选项被设置时，SDWebImage 在加载 GIF 图像并将其存储到内存缓存时，仅会解码并缓存第一帧，而不是整个 GIF 动画
     */
    SDImageCacheDecodeFirstFrameOnly = 1 << 5,
    /**
     * By default, for `SDAnimatedImage`, we decode the animated image frame during rendering to reduce memory usage. This flag actually trigger `preloadAllAnimatedImageFrames = YES` after image load from disk cache
     */
    SDImageCachePreloadAllFrames = 1 << 6,
    /**
     * By default, when you use `SDWebImageContextAnimatedImageClass` context option (like using `SDAnimatedImageView` which designed to use `SDAnimatedImage`), we may still use `UIImage` when the memory cache hit, or image decoder is not available, to behave as a fallback solution.
     * Using this option, can ensure we always produce image with your provided class. If failed, a error with code `SDWebImageErrorBadImageData` will been used.
     * Note this options is not compatible with `SDImageCacheDecodeFirstFrameOnly`, which always produce a UIImage/NSImage.
     */
    SDImageCacheMatchAnimatedImageClass = 1 << 7,
};

/**
 * SDImageCache maintains a memory cache and a disk cache. Disk cache write operations are performed
 * asynchronous so it doesn’t add unnecessary latency to the UI.
 */
@interface SDImageCache : NSObject

#pragma mark - Properties

/**
 *  Cache Config object - storing all kind of settings.
 *  The property is copy so change of currrent config will not accidentally affect other cache's config.
 */
@property (nonatomic, copy, nonnull, readonly) SDImageCacheConfig *config;

/**
 * The memory cache implementation object used for current image cache.
 * By default we use `SDMemoryCache` class, you can also use this to call your own implementation class method.
 * @note To customize this class, check `SDImageCacheConfig.memoryCacheClass` property.
 */
@property (nonatomic, strong, readonly, nonnull) id<SDMemoryCache> memoryCache;

/**
 * The disk cache implementation object used for current image cache.
 * By default we use `SDMemoryCache` class, you can also use this to call your own implementation class method.
 * @note To customize this class, check `SDImageCacheConfig.diskCacheClass` property.
 * @warning When calling method about read/write in disk cache, be sure to either make your disk cache implementation IO-safe or using the same access queue to avoid issues.
 */
@property (nonatomic, strong, readonly, nonnull) id<SDDiskCache> diskCache;

/**
 *  The disk cache's root path
 */
@property (nonatomic, copy, nonnull, readonly) NSString *diskCachePath;

/**
 *  The additional disk cache path to check if the query from disk cache not exist;
 *  The `key` param is the image cache key. The returned file path will be used to load the disk cache. If return nil, ignore it.
 *  Useful if you want to bundle pre-loaded images with your app
 */
@property (nonatomic, copy, nullable) SDImageCacheAdditionalCachePathBlock additionalCachePathBlock;

#pragma mark - Singleton and initialization

/**
 * Returns global shared cache instance
 */
@property (nonatomic, class, readonly, nonnull) SDImageCache *sharedImageCache;

/**
 * Init a new cache store with a specific namespace
 *
 * @param ns The namespace to use for this cache store
 */
- (nonnull instancetype)initWithNamespace:(nonnull NSString *)ns;

/**
 * Init a new cache store with a specific namespace and directory.
 * If you don't provide the disk cache directory, we will use the User Cache directory with prefix (~/Library/Caches/com.hackemist.SDImageCache/).
 *
 * @param ns        The namespace to use for this cache store
 * @param directory Directory to cache disk images in
 */
- (nonnull instancetype)initWithNamespace:(nonnull NSString *)ns
                       diskCacheDirectory:(nullable NSString *)directory;

/**
 * Init a new cache store with a specific namespace, directory and file manager
 * The final disk cache directory should looks like ($directory/$namespace). And the default config of shared cache, should result in (~/Library/Caches/com.hackemist.SDImageCache/default/)
 *
 * @param ns          The namespace to use for this cache store
 * @param directory   Directory to cache disk images in
 * @param config      The cache config to be used to create the cache. You can provide custom memory cache or disk cache class in the cache config
 */
- (nonnull instancetype)initWithNamespace:(nonnull NSString *)ns
                       diskCacheDirectory:(nullable NSString *)directory
                                   config:(nullable SDImageCacheConfig *)config NS_DESIGNATED_INITIALIZER;

#pragma mark - Cache paths

/**
 Get the cache path for a certain key
 
 @param key The unique image cache key
 @return The cache path. You can check `lastPathComponent` to grab the file name.
 */
- (nullable NSString *)cachePathForKey:(nullable NSString *)key;

#pragma mark - Store Ops

/**
 * Asynchronously store an image into memory and disk cache at the given key.
 *
 * @param image           The image to store
 * @param key             The unique image cache key, usually it's image absolute URL
 * @param completionBlock A block executed after the operation is finished
 */
/*
根据给定的key异步存储图片
image 要存储的图片
key 一张图片的唯一ID，一般使用图片的URL
completionBlock 完成异步存储后的回调块
该方法并不执行任何实际的操作，而是直接调用下面的下面的那个方法
*/
- (void)storeImage:(nullable UIImage *)image
            forKey:(nullable NSString *)key
        completion:(nullable SDWebImageNoParamsBlock)completionBlock;

/**
 * Asynchronously store an image into memory and disk cache at the given key.
 *
 * @param image           The image to store
 * @param key             The unique image cache key, usually it's image absolute URL
 * @param toDisk          Store the image to disk cache if YES. If NO, the completion block is called synchronously
 * @param completionBlock A block executed after the operation is finished
 * @note If no image data is provided and encode to disk, we will try to detect the image format (using either `sd_imageFormat` or `SDAnimatedImage` protocol method) and animation status, to choose the best matched format, including GIF, JPEG or PNG.
 */
/*
同上，该方法并不是真正的执行者，而是需要调用下面的那个方法
根据给定的key异步存储图片
image 要存储的图片
key 唯一ID，一般使用URL
toDisk 是否缓存到磁盘中
completionBlock 缓存完成后的回调块
*/
- (void)storeImage:(nullable UIImage *)image
            forKey:(nullable NSString *)key
            toDisk:(BOOL)toDisk
        completion:(nullable SDWebImageNoParamsBlock)completionBlock;

/**
 * Asynchronously store an image into memory and disk cache at the given key.
 *
 * @param image           The image to store
 * @param imageData       The image data as returned by the server, this representation will be used for disk storage
 *                        instead of converting the given image object into a storable/compressed image format in order
 *                        to save quality and CPU
 * @param key             The unique image cache key, usually it's image absolute URL
 * @param toDisk          Store the image to disk cache if YES. If NO, the completion block is called synchronously
 * @param completionBlock A block executed after the operation is finished
 * @note If no image data is provided and encode to disk, we will try to detect the image format (using either `sd_imageFormat` or `SDAnimatedImage` protocol method) and animation status, to choose the best matched format, including GIF, JPEG or PNG.
 */
/*
根据给定的key异步存储图片，真正的缓存执行者
image 要存储的图片
imageData 要存储的图片的二进制数据即NSData数据
key 唯一ID，一般使用URL
toDisk 是否缓存到磁盘中
completionBlock
*/
- (void)storeImage:(nullable UIImage *)image
         imageData:(nullable NSData *)imageData
            forKey:(nullable NSString *)key
            toDisk:(BOOL)toDisk
        completion:(nullable SDWebImageNoParamsBlock)completionBlock;

/**
 * Synchronously store image into memory cache at the given key.
 *
 * @param image  The image to store
 * @param key    The unique image cache key, usually it's image absolute URL
 */
- (void)storeImageToMemory:(nullable UIImage*)image
                    forKey:(nullable NSString *)key;

/**
 * Synchronously store image data into disk cache at the given key.
 *
 * @param imageData  The image data to store
 * @param key        The unique image cache key, usually it's image absolute URL
 */

/*
根据指定key同步存储NSData类型的图片的数据到磁盘中
这是一个同步的方法，需要放在指定的ioQueue中执行，指定的ioQueue在下面会讲
imageData 图片的二进制数据即NSData类型的对象
key 图片的唯一ID，一般使用URL
*/
- (void)storeImageDataToDisk:(nullable NSData *)imageData
                      forKey:(nullable NSString *)key;


#pragma mark - Contains and Check Ops

/**
 *  Asynchronously check if image exists in disk cache already (does not load the image)
 *
 *  @param key             the key describing the url
 *  @param completionBlock the block to be executed when the check is done.
 *  @note the completion block will be always executed on the main queue
 */
/*
异步方式根据指定的key查询磁盘中是否缓存了这个图片
key 图片的唯一ID，一般使用URL
completionBlock 查询完成后的回调块，这个回调块默认会在主线程中执行
*/
- (void)diskImageExistsWithKey:(nullable NSString *)key completion:(nullable SDImageCacheCheckCompletionBlock)completionBlock;

/**
 *  Synchronously check if image data exists in disk cache already (does not load the image)
 *
 *  @param key             the key describing the url
 */
- (BOOL)diskImageDataExistsWithKey:(nullable NSString *)key;

#pragma mark - Query and Retrieve Ops

/**
 * Synchronously query the image data for the given key in disk cache. You can decode the image data to image after loaded.
 *
 *  @param key The unique key used to store the wanted image
 *  @return The image data for the given key, or nil if not found.
 */
- (nullable NSData *)diskImageDataForKey:(nullable NSString *)key;

/**
 * Asynchronously query the image data for the given key in disk cache. You can decode the image data to image after loaded.
 *
 *  @param key The unique key used to store the wanted image
 *  @param completionBlock the block to be executed when the query is done.
 *  @note the completion block will be always executed on the main queue
 */
- (void)diskImageDataQueryForKey:(nullable NSString *)key completion:(nullable SDImageCacheQueryDataCompletionBlock)completionBlock;

/**
 * Asynchronously queries the cache with operation and call the completion when done.
 *
 * @param key       The unique key used to store the wanted image. If you want transformed or thumbnail image, calculate the key with `SDTransformedKeyForKey`, `SDThumbnailedKeyForKey`, or generate the cache key from url with `cacheKeyForURL:context:`.
 * @param doneBlock The completion block. Will not get called if the operation is cancelled
 *
 * @return a NSOperation instance containing the cache op
 */
- (nullable NSOperation *)queryCacheOperationForKey:(nullable NSString *)key done:(nullable SDImageCacheQueryCompletionBlock)doneBlock;

/**
 * Asynchronously queries the cache with operation and call the completion when done.
 *
 * @param key       The unique key used to store the wanted image. If you want transformed or thumbnail image, calculate the key with `SDTransformedKeyForKey`, `SDThumbnailedKeyForKey`, or generate the cache key from url with `cacheKeyForURL:context:`.
 * @param options   A mask to specify options to use for this cache query
 * @param doneBlock The completion block. Will not get called if the operation is cancelled
 *
 * @return a NSOperation instance containing the cache op
 */
- (nullable NSOperation *)queryCacheOperationForKey:(nullable NSString *)key options:(SDImageCacheOptions)options done:(nullable SDImageCacheQueryCompletionBlock)doneBlock;

/**
 * Asynchronously queries the cache with operation and call the completion when done.
 *
 * @param key       The unique key used to store the wanted image. If you want transformed or thumbnail image, calculate the key with `SDTransformedKeyForKey`, `SDThumbnailedKeyForKey`, or generate the cache key from url with `cacheKeyForURL:context:`.
 * @param options   A mask to specify options to use for this cache query
 * @param context   A context contains different options to perform specify changes or processes, see `SDWebImageContextOption`. This hold the extra objects which `options` enum can not hold.
 * @param doneBlock The completion block. Will not get called if the operation is cancelled
 *
 * @return a NSOperation instance containing the cache op
 */
- (nullable NSOperation *)queryCacheOperationForKey:(nullable NSString *)key options:(SDImageCacheOptions)options context:(nullable SDWebImageContext *)context done:(nullable SDImageCacheQueryCompletionBlock)doneBlock;

/**
 * Asynchronously queries the cache with operation and call the completion when done.
 *
 * @param key       The unique key used to store the wanted image. If you want transformed or thumbnail image, calculate the key with `SDTransformedKeyForKey`, `SDThumbnailedKeyForKey`, or generate the cache key from url with `cacheKeyForURL:context:`.
 * @param options   A mask to specify options to use for this cache query
 * @param context   A context contains different options to perform specify changes or processes, see `SDWebImageContextOption`. This hold the extra objects which `options` enum can not hold.
 * @param queryCacheType Specify where to query the cache from. By default we use `.all`, which means both memory cache and disk cache. You can choose to query memory only or disk only as well. Pass `.none` is invalid and callback with nil immediatelly.
 * @param doneBlock The completion block. Will not get called if the operation is cancelled
 *
 * @return a NSOperation instance containing the cache op
 */
- (nullable NSOperation *)queryCacheOperationForKey:(nullable NSString *)key options:(SDImageCacheOptions)options context:(nullable SDWebImageContext *)context cacheType:(SDImageCacheType)queryCacheType done:(nullable SDImageCacheQueryCompletionBlock)doneBlock;

/**
 * Synchronously query the memory cache.
 *
 * @param key The unique key used to store the image
 * @return The image for the given key, or nil if not found.
 */
/*
同步查询内存缓存中是否有ID为key的图片
key 图片的唯一ID，一般使用URL
*/
- (nullable UIImage *)imageFromMemoryCacheForKey:(nullable NSString *)key;

/**
 * Synchronously query the disk cache.
 *
 * @param key The unique key used to store the image
 * @return The image for the given key, or nil if not found.
 */
/*
同步查询磁盘缓存中是否有ID为key的图片
key 图片的唯一ID，一般使用URL
*/
- (nullable UIImage *)imageFromDiskCacheForKey:(nullable NSString *)key;

/**
 * Synchronously query the disk cache. With the options and context which may effect the image generation. (Such as transformer, animated image, thumbnail, etc)
 *
 * @param key The unique key used to store the image
 * @param options   A mask to specify options to use for this cache query
 * @param context   A context contains different options to perform specify changes or processes, see `SDWebImageContextOption`. This hold the extra objects which `options` enum can not hold.
 * @return The image for the given key, or nil if not found.
 */
- (nullable UIImage *)imageFromDiskCacheForKey:(nullable NSString *)key options:(SDImageCacheOptions)options context:(nullable SDWebImageContext *)context;

/**
 * Synchronously query the cache (memory and or disk) after checking the memory cache.
 *
 * @param key The unique key used to store the image
 * @return The image for the given key, or nil if not found.
 */
/*
同步查询内存缓存和磁盘缓存中是否有ID为key的图片
key 图片的唯一ID，一般使用URL
*/
- (nullable UIImage *)imageFromCacheForKey:(nullable NSString *)key;

/**
 * Synchronously query the cache (memory and or disk) after checking the memory cache. With the options and context which may effect the image generation. (Such as transformer, animated image, thumbnail, etc)
 *
 * @param key The unique key used to store the image
 * @param options   A mask to specify options to use for this cache query
 * @param context   A context contains different options to perform specify changes or processes, see `SDWebImageContextOption`. This hold the extra objects which `options` enum can not hold.
 * @return The image for the given key, or nil if not found.
 */
- (nullable UIImage *)imageFromCacheForKey:(nullable NSString *)key options:(SDImageCacheOptions)options context:(nullable SDWebImageContext *)context;;

#pragma mark - Remove Ops

/**
 * Asynchronously remove the image from memory and disk cache
 *
 * @param key             The unique image cache key
 * @param completion      A block that should be executed after the image has been removed (optional)
 */
/*
根据给定key异步方式删除缓存
key 图片的唯一ID，一般使用URL
completion 操作完成后的回调块
*/
- (void)removeImageForKey:(nullable NSString *)key withCompletion:(nullable SDWebImageNoParamsBlock)completion;

/**
 * Asynchronously remove the image from memory and optionally disk cache
 *
 * @param key             The unique image cache key
 * @param fromDisk        Also remove cache entry from disk if YES. If NO, the completion block is called synchronously
 * @param completion      A block that should be executed after the image has been removed (optional)
 */
/*
根据给定key异步方式删除内存中的缓存
key 图片的唯一ID，一般使用URL
fromDisk 是否删除磁盘中的缓存，如果为YES那也会删除磁盘中的缓存
completion 操作完成后的回调块
*/
- (void)removeImageForKey:(nullable NSString *)key fromDisk:(BOOL)fromDisk withCompletion:(nullable SDWebImageNoParamsBlock)completion;

/**
 Synchronously remove the image from memory cache.
 
 @param key The unique image cache key
 */
- (void)removeImageFromMemoryForKey:(nullable NSString *)key;

/**
 Synchronously remove the image from disk cache.
 
 @param key The unique image cache key
 */
- (void)removeImageFromDiskForKey:(nullable NSString *)key;

#pragma mark - Cache clean Ops

/**
 * Synchronously Clear all memory cached images
 */
//删除所有的内存缓存，即NSCache中的removeAllObjects
- (void)clearMemory;

/**
 * Asynchronously clear all disk cached images. Non-blocking method - returns immediately.
 * @param completion    A block that should be executed after cache expiration completes (optional)
 */
/*
异步方式清空磁盘中的所有缓存
completion 删除完成后的回调块
*/
- (void)clearDiskOnCompletion:(nullable SDWebImageNoParamsBlock)completion;

/**
 * Asynchronously remove all expired cached image from disk. Non-blocking method - returns immediately.
 * @param completionBlock A block that should be executed after cache expiration completes (optional)
 */
/*
异步删除磁盘缓存中所有超过缓存最大时间的图片，即前面属性中的maxCacheAge
completionBlock 删除完成后的回调块
*/
- (void)deleteOldFilesWithCompletionBlock:(nullable SDWebImageNoParamsBlock)completionBlock;

#pragma mark - Cache Info

/**
 * Get the total bytes size of images in the disk cache
 */
- (NSUInteger)totalDiskSize;

/**
 * Get the number of images in the disk cache
 */
- (NSUInteger)totalDiskCount;

/**
 * Asynchronously calculate the disk cache's size.
 */
- (void)calculateSizeWithCompletionBlock:(nullable SDImageCacheCalculateSizeBlock)completionBlock;

@end

/**
 * SDImageCache is the built-in image cache implementation for web image manager. It adopts `SDImageCache` protocol to provide the function for web image manager to use for image loading process.
 */
@interface SDImageCache (SDImageCache) <SDImageCache>

@end
