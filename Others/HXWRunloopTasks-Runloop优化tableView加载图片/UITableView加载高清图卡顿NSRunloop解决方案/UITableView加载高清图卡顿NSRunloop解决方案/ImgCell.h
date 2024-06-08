//
//  ImgCell.h
//  UITableView加载高清图卡顿NSRunloop解决方案
//
//  Created by BTI-HXW on 2019/6/5.
//  Copyright © 2019 BTI-HXW. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ImgCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UIImageView *imageView1;
@property (weak, nonatomic) IBOutlet UIImageView *imageView2;
@property (weak, nonatomic) IBOutlet UIImageView *imageView3;

@end

NS_ASSUME_NONNULL_END
