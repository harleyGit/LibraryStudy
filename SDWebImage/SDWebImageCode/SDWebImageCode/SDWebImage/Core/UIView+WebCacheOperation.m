/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "UIView+WebCacheOperation.h"
#import "objc/runtime.h"

static char loadOperationKey;

// key is strong, value is weak because operation instance is retained by SDWebImageManager's runningOperations property
// we should use lock to keep thread-safe because these method may not be acessed from main queue
typedef NSMapTable<NSString *, id<SDWebImageOperation>> SDOperationsDictionary;

@implementation UIView (WebCacheOperation)

- (SDOperationsDictionary *)sd_operationDictionary {
    @synchronized(self) {
        SDOperationsDictionary *operations = objc_getAssociatedObject(self, &loadOperationKey);
        if (operations) {
            return operations;
        }
        //当在多线程环境中操作集合时，NSMapTable 可以提供更好的线程安全性。
        //通过使用弱引用键和值，可以避免在移除对象时引起的引用计数问题。
        //这是因为弱引用不会影响对象的引用计数，当没有其他强引用时，这些对象可以被自动释放或垃圾回收。
        //NSPointerFunctionsStrongMemory 来表示对键或值使用强引用（strong reference
        operations = [[NSMapTable alloc] initWithKeyOptions:NSPointerFunctionsStrongMemory valueOptions:NSPointerFunctionsWeakMemory capacity:0];
        objc_setAssociatedObject(self, &loadOperationKey, operations, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return operations;
    }
}

- (nullable id<SDWebImageOperation>)sd_imageLoadOperationForKey:(nullable NSString *)key  {
    id<SDWebImageOperation> operation;
    if (key) {
        SDOperationsDictionary *operationDictionary = [self sd_operationDictionary];
        @synchronized (self) {
            operation = [operationDictionary objectForKey:key];
        }
    }
    return operation;
}

- (void)sd_setImageLoadOperation:(nullable id<SDWebImageOperation>)operation forKey:(nullable NSString *)key {
    if (key) {
        [self sd_cancelImageLoadOperationWithKey:key];
        if (operation) {
            SDOperationsDictionary *operationDictionary = [self sd_operationDictionary];
            @synchronized (self) {
                [operationDictionary setObject:operation forKey:key];
            }
        }
    }
}

- (void)sd_cancelImageLoadOperationWithKey:(nullable NSString *)key {
    if (key) {
        // Cancel in progress downloader from queue
        SDOperationsDictionary *operationDictionary = [self sd_operationDictionary];
        id<SDWebImageOperation> operation;
        
        //@synchronized (self)通常使用 self，因为它是一个常用的唯一对象，可以确保在整个程序中是唯一的。
        //然而，你也可以使用其他对象，只要它在所有需要同步的地方都是相同的。
        @synchronized (self) {
            operation = [operationDictionary objectForKey:key];
        }
        if (operation) {
            if ([operation conformsToProtocol:@protocol(SDWebImageOperation)]) {
                [operation cancel];
            }
            @synchronized (self) {
                [operationDictionary removeObjectForKey:key];
            }
        }
    }
}

- (void)sd_removeImageLoadOperationWithKey:(nullable NSString *)key {
    if (key) {
        SDOperationsDictionary *operationDictionary = [self sd_operationDictionary];
        @synchronized (self) {
            [operationDictionary removeObjectForKey:key];
        }
    }
}

@end
