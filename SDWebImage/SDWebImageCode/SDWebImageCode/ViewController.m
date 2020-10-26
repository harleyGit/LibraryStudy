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
    [pic sd_setImageWithURL:@"https://timgsa.baidu.com/timg?image&quality=80&size=b9999_10000&sec=1603690915065&di=76c1d4fdcd8ca41cd923466b539bed82&imgtype=0&src=http%3A%2F%2Fhbimg.b0.upaiyun.com%2Ff5682f2b362a497ec3339369ccd08757491cd87823d47-QupZFW_fw658"];
    [self.view addSubview:pic];
    
}


@end
