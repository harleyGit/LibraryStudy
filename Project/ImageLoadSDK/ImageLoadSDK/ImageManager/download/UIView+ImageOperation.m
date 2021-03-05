//
//  UIImage+ImageOperation.m
//  ImageLoadSDK
//
//  Created by Harley Huang on 27/11/2020.
//

#import "UIView+ImageOperation.h"
#import "objc/runtime.h"


static char kImageOperation;
typedef NSMutableDictionary<NSString *, id<ImageOperation>> OperationDictionay;


@implementation UIView (ImageOperation)


- (OperationDictionay *)operationDictionary {
    @synchronized (self) {
        OperationDictionay *operationDict = objc_getAssociatedObject(self, &kImageOperation);
        if (operationDict) {
            return operationDict;
        }
        operationDict = [[NSMutableDictionary alloc] init];
        objc_setAssociatedObject(self, &kImageOperation, operationDict, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return operationDict;
    }
}

- (void)setOperation:(id<ImageOperation>)operation forKey:(NSString *)key {
    if (key) {
        [self cancelOperationForKey:key]; //先取消当前任务，再重新设置加载任务
        if (operation) {
            OperationDictionay *operationDict = [self operationDictionary];
            @synchronized (self) {
                [operationDict setObject:operation forKey:key];
            }
        }
    }
}

- (void)cancelOperationForKey:(NSString *)key {
    if (key) {
        OperationDictionay *operationDict = [self operationDictionary];
        id<ImageOperation> operation;
        @synchronized (self) {
            operation = [operationDict objectForKey:key];
        }
        if (operation && [operation conformsToProtocol:@protocol(ImageOperation)]) {//判断当前operation是否实现了ImageOperation协议
            [operation cancelOperation];
        }
        @synchronized (self) {
            [operationDict removeObjectForKey:key];
        }
    }
}

- (void)removeOperationForKey:(NSString *)key {
    if (key) {
        OperationDictionay *operationDict = [self operationDictionary];
        @synchronized (self) {
            [operationDict removeObjectForKey:key];
        }
    }
}



@end
