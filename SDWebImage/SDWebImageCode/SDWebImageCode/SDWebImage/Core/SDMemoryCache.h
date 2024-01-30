/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "SDWebImageCompat.h"

@class SDImageCacheConfig;
/**
 A protocol to allow custom memory cache used in SDImageCache.
 */
@protocol SDMemoryCache <NSObject>

@required

/**
 Create a new memory cache instance with the specify cache config. You can check `maxMemoryCost` and `maxMemoryCount` used for memory cache.

 @param config The cache config to be used to create the cache.
 @return The new memory cache instance.
 */

- (nonnull instancetype)initWithConfig:(nonnull SDImageCacheConfig *)config;

/**
 Returns the value associated with a given key.

 @param key An object identifying the value. If nil, just return nil.
 @return The value associated with key, or nil if no value is associated with key.
 */
- (nullable id)objectForKey:(nonnull id)key;

/**
 Sets the value of the specified key in the cache (0 cost).

 @param object The object to be stored in the cache. If nil, it calls `removeObjectForKey:`.
 @param key    The key with which to associate the value. If nil, this method has no effect.
 @discussion Unlike an NSMutableDictionary object, a cache does not copy the key
 objects that are put into it.
 */
- (void)setObject:(nullable id)object forKey:(nonnull id)key;

/**
 Sets the value of the specified key in the cache, and associates the key-value
 pair with the specified cost.

 @param object The object to store in the cache. If nil, it calls `removeObjectForKey`.
 @param key    The key with which to associate the value. If nil, this method has no effect.
 @param cost   The cost with which to associate the key-value pair.
 @discussion Unlike an NSMutableDictionary object, a cache does not copy the key
 objects that are put into it.
 */
- (void)setObject:(nullable id)object forKey:(nonnull id)key cost:(NSUInteger)cost;

/**
 Removes the value of the specified key in the cache.

 @param key The key identifying the value to be removed. If nil, this method has no effect.
 */
- (void)removeObjectForKey:(nonnull id)key;

/**
 Empties the cache immediately.
 */
- (void)removeAllObjects;

@end

/**
 * A memory cache which auto purge the cache on memory warning and support weak cache.
 * 这个声明表示 SDMemoryCache 类继承自 NSCache 类，同时拥有两个泛型参数 KeyType 和 ObjectType。
 * 此外，它还遵循了一个名为 SDMemoryCache 的协议。在实际使用时，你可以在创建 SDMemoryCache 类的实例时指定具体的类型参数，以适应不同的键值类型
 * 举例: SDMemoryCache<NSString *, UIImage *> *imageCache = [[SDMemoryCache alloc] init];
 * 上述举例,解释: KeyType 被指定为 NSString *，而 ObjectType 被指定为 UIImage *。这样，在使用 imageCache 对象时，键的类型为字符串，值的类型为图像。
 */
@interface SDMemoryCache <KeyType, ObjectType> : NSCache <KeyType, ObjectType> <SDMemoryCache>

//配置
@property (nonatomic, strong, nonnull, readonly) SDImageCacheConfig *config;

@end
