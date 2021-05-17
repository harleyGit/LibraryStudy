//
//  Test1.m
//  KVO演示
//
//  Created by Harley Huang on 17/5/2021.
//  Copyright © 2021 Azuo. All rights reserved.
//

#import "Test1.h"

@implementation Test1


-(void)observeValueForKeyPath:(NSString *)keyPath
                     ofObject:(id)object
                       change:(NSDictionary<NSString *,id> *)change
                      context:(void *)context {
    if([keyPath isEqualToString:@"num"] ) {
        // 响应变化处理：UI更新（label文本改变）
//        self.label.text = [NSString stringWithFormat:@"当前的num值为：%@",
//                           [change valueForKey:@"new"]];
//
        //上文注册时，枚举为2个，因此可以提取change字典中的新、旧值的这两个方法
        NSLog(@"\noldnum:%@ newnum:%@",
              [change valueForKey:@"old"],
              [change valueForKey:@"new"]);
    }
   
    printf("\n");
    
   
}

@end
