//
//  ViewController.m
//  SDWebImageCode
//
//  Created by Harley Huang on 24/10/2020.
//  Copyright © 2020 HuangGang. All rights reserved.
//

#import "ViewController.h"
#import "SDWebImage.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    
    UIImageView *pic = [[UIImageView alloc] initWithFrame:CGRectMake(100, 100, 300, 150)];
    [pic sd_setImageWithURL:@"https://img0.baidu.com/it/u=674920964,2902284025&fm=253&fmt=auto&app=138&f=JPEG?w=658&h=494"];
    [self.view addSubview:pic];
    
}


@end
