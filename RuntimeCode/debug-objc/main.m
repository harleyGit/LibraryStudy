//
//  main.m
//  debug-objc
//
//  Created by Closure on 2018/12/4.
//

#import <Foundation/Foundation.h>

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // insert code here...
        NSObject *obj = [[NSObject alloc] init];
        NSLog(@"🍎 Runtime： %@",obj);
        NSLog(@"Hello, World! %@", [NSString class]);
    }
    return 0;
}
