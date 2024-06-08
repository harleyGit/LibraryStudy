//
//  ViewController.m
//  UITableView加载高清图卡顿NSRunloop解决方案
//
//  Created by BTI-HXW on 2019/6/5.
//  Copyright © 2019 BTI-HXW. All rights reserved.
//  iOS 透过CFRunloop源码分析runloop底层原理及应用场景: https://www.jianshu.com/p/e29f846d8a97

#import "ViewController.h"
#import "ImgCell.h"
#import "HXWRunloopTask.h"

#define ImageWidth ([UIScreen mainScreen].bounds.size.width-20)/3.0
#define ImageHeight 110.0

@interface ViewController ()<UITableViewDelegate,UITableViewDataSource>
@property (weak, nonatomic) IBOutlet UITableView *tableView;
/**
 
 */
@property (nonatomic, copy) NSString *path;
/**
 
 */
@property (nonatomic, strong) HXWRunloopTask *runloopTask;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    self.runloopTask = [HXWRunloopTask new];
    [self.tableView registerNib:[UINib nibWithNibName:@"ImgCell" bundle:[NSBundle mainBundle]] forCellReuseIdentifier:@"imgCell"];
    self.path = [[NSBundle mainBundle] pathForResource:@"test" ofType:@"jpeg"];
}

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return 1;
}
-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return 120;
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    return 120.0;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    ImgCell* cell = [self.tableView dequeueReusableCellWithIdentifier:@"imgCell" forIndexPath:indexPath];
    __weak typeof(self) weakSelf = self;
    [self.runloopTask addTask:^{

        [weakSelf addImageToCell:cell];

    }];

    return cell;
}
-(void)addImageToCell:(ImgCell*)cell{
    @autoreleasepool {///读取图片，内存爆增，需要手动加@autoreleasepool
        UIImage * img = [UIImage imageWithContentsOfFile:_path];
        cell.imageView1.image = img;
        cell.imageView2.image = img;
        cell.imageView3.image = img;
    }
//    ///模拟耗时超大计算
//    for (int i = 0 ; i<100000000; i++) {
//
//    }

}
@end
