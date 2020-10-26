//
//  ViewController.m
//  AFNetWorkingCode
//
//  Created by Harley Huang on 26/10/2020.
//  Copyright © 2020 HuangGang. All rights reserved.
//

#import "ViewController.h"
#import "AFNetworking.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    UIButton *netBtn = [[UIButton alloc] initWithFrame:CGRectMake(100, 100, 150, 75)];
    [netBtn setTitle:@"AFNet 网络请求" forState: UIControlStateNormal];
    netBtn.backgroundColor = UIColor.redColor;
    [netBtn addTarget:self action:@selector(afnetworkTextClickAction:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.view addSubview:netBtn];
    
}


 - (void) afnetworkTextClickAction:(UIButton *)sender {
    AFHTTPSessionManager *manager = [[AFHTTPSessionManager alloc]init];
    [manager GET:@"https://route.showapi.com/341-2?maxResult=2&page=1&showapi_appid=206561&showapi_timestamp=20200501230719&showapi_sign=c5deb2531727443141b89413d89a3147" parameters:nil headers:nil progress:^(NSProgress * _Nonnull downloadProgress) {

    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        NSLog(@"相应结果：%@", responseObject);
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {

    }];
    AFURLSessionManager *mm = [AFURLSessionManager new];
    [mm dataTaskWithRequest:[NSURLRequest new] uploadProgress:nil downloadProgress:nil completionHandler:nil];
    [manager.session dataTaskWithRequest:[NSURLRequest new]];
    
}


@end
