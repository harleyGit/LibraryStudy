//
//  ViewController.m
//  RetryNetwork
//
//  Created by 王志盼 on 2017/12/21.
//  Copyright © 2017年 王志盼. All rights reserved.
//

#import "ViewController.h"
#import "ZYRequestManager.h"
#import "ZYRequest.h"
#import "ZYRequestCache.h"
#import "ZYRequestRealm.h"




//资料： https://www.cnblogs.com/ziyi--caolu/p/8176331.html
@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    ZYRequestManager *mgr = [ZYRequestManager sharedInstance];
    for (int i = 0; i < 100; i++)
    {
        ZYRequest *request = [[ZYRequest alloc] init];
        request.urlStr = @"http://qf.56.com/pay/v4/giftList.ios";
        request.params = @{@"type": @0, @"page": @1, @"rows": @150};
        request.requestId = i;
        request.cacheKey = [NSString stringWithFormat:@"cache%d", i];
//        request.reliability = ZYRequestReliabilityStoreToDB;


        CGFloat duration = 0;

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{

            [mgr sendRequest:request successBlock:^(id obj) {
                NSLog(@"~~~~~~~~~~~~~[%d]", request.requestId);
            } failureBlock:nil];

        });
    }



    //根据key读取缓存
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//        NSData *data = [[ZYRequestCache sharedInstance] readDataForKey:@"cache0"];
//        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
//        NSLog(@"%@", dict);
//    });
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
