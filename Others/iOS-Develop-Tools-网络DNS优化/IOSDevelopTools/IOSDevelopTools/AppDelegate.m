//
//  AppDelegate.m
//  IOSDevelopTools
//
//  Created by 叶煌斌 on 2020/3/10.
//  Copyright © 2020 叶煌斌. All rights reserved.
//

#import "AppDelegate.h"
#import "YECallMonitor.h"
#import "mach-o/dyld.h"
#import "AppCallCollecter.h"
#import "YENetworkManager.h"
@interface AppDelegate ()

@end

@implementation AppDelegate
//static void add(const struct mach_header* header, intptr_t imp) {
//    usleep(10000);
//}
extern CFAbsoluteTime startTime;
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.

//        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//            _dyld_register_func_for_add_image(add);
//            usleep(3000000);
//        });
    
    [[YENetworkManager shareInstance] requestRemoteDNSList];
    
    YECallMonitor *monitor = [YECallMonitor shareInstance];
    [monitor setMinTime:10];
    [monitor start];
    [monitor setFilterClassNames:@[@"ViewController"]];

    double launchTime = (CFAbsoluteTimeGetCurrent() - startTime);
    NSLog(@"%.5f",launchTime);
    
//    appOrderFile(^(NSString *orderFilePath) {
//        NSLog(@"%@",orderFilePath);
//    });
    
    NSArray *arr = getAppCalls();
    NSLog(@"%@",[arr description]);

    return YES;
}


- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}


- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}


@end
