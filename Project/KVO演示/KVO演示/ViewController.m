//
//  ViewController.m
//  KVO演示
//
//  Created by zuoA on 16/4/27.
//  Copyright © 2016年 Azuo. All rights reserved.
//

#import "ViewController.h"
#import <objc/message.h>

#import "MyKVOModel.h"
#import "Test1.h"

@interface ViewController ()

@property (nonatomic, strong) MyKVOModel *myObject;

@property (nonatomic, strong) MyKVOModel *myObject2;

@property (nonatomic, retain) Test1 *test1;


@end

@implementation ViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 初始化待观察类对象
    self.myObject = [[MyKVOModel alloc]init];
    
    self.myObject2 = [[MyKVOModel alloc]init];
    self.myObject2.num = 2;
    
    NSLog(@"%@", [self.myObject2 class]);
    
//    self.test1 = [[Test1 alloc] init];
//
//    
//    NSLog(@"myObject2.num: %d", self.myObject2.num);
//    
//    1.注册对象myKVO为被观察者。
//    option中：
//    NSKeyValueObservingOptionOld 以字典的形式提供 “初始对象数据”;
//    NSKeyValueObservingOptionNew 以字典的形式提供 “更新后新的数据”;
    [self.myObject addObserver:self
                       forKeyPath:@"num"
                          options:NSKeyValueObservingOptionOld|NSKeyValueObservingOptionNew
                          context:nil];
    
    [self.myObject2 addObserver:self
                       forKeyPath:@"num"
                          options:NSKeyValueObservingOptionOld|NSKeyValueObservingOptionNew
                          context:nil];
    
    //[obj class]返回类对象本身
    NSLog(@"---->>>2: %@", [self.myObject2 class]);

    //object_getClass(obj)返回类对象中的isa指向的元类对象，即指向元类对象
    NSLog(@"---->>>3: %s", object_getClassName(self.myObject2));
    NSLog(@"---->>>4: %@", object_getClass(self.myObject2));
}

#pragma mark - KVO
/**
 2.只要object的keyPath属性发生变化，就会调用此回调方法，进行相应的处理：UI更

 @param keyPath 属性名称
 @param object 被观察的对象
 @param change 变化前后的值都存储在 change 字典中
 @param context 注册观察者时，context 传过来的值
 */
-(void)observeValueForKeyPath:(NSString *)keyPath
                     ofObject:(id)object
                       change:(NSDictionary<NSString *,id> *)change
                      context:(void *)context {
    if([keyPath isEqualToString:@"num"] && object == self.myObject) {
        // 响应变化处理：UI更新（label文本改变）
        self.label.text = [NSString stringWithFormat:@"当前的num值为：%@",
                           [change valueForKey:@"new"]];
        
        //上文注册时，枚举为2个，因此可以提取change字典中的新、旧值的这两个方法
        NSLog(@"\noldnum:%@ newnum:%@",
              [change valueForKey:@"old"],
              [change valueForKey:@"new"]);
    }
   
    printf("\n");
    
    if ([keyPath isEqualToString:@"num"] && object == self.myObject2){
        NSLog(@"------->>>\noldnum:%@ newnum:%@",
              [change valueForKey:@"old"],
              [change valueForKey:@"new"]);
    }
}

#pragma mark - Event Click

/**
 按钮事件

 @param sender button
 */
- (IBAction)changeNum:(UIButton *)sender {
    //按一次，使num的值+1
    self.myObject.num = self.myObject.num + 1;
    self.myObject2.num = self.myObject.num + 1;

    
//    NSLog(@"myObject2.num: %d", self.myObject2.num);

}

/**
  3.移除KVO
 */
- (void)dealloc {
    [self removeObserver:self
              forKeyPath:@"num"
                 context:nil];
}

@end

