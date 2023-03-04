//
//  main.m
//  debug-objc
//
//  Created by Closure on 2018/12/4.
//

#import <Foundation/Foundation.h>

/**
 *测试弱引用
 *原理: https://blog.csdn.net/u013378438/article/details/82767947
 */
void testWeakReference() {
    NSObject *obj = [[NSObject alloc] init];
    __weak NSObject *weakObj = obj;
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // insert code here...
        NSObject *obj = [[NSObject alloc] init];
        NSLog(@"🍎 Runtime： %@",obj);
        NSLog(@"Hello, World! %@", [NSString class]);
        
        testWeakReference();
    }
    return 0;
}





