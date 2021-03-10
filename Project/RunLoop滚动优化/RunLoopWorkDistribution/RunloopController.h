//
//  RunloopController.h
//  RunLoopWorkDistribution
//
//  Created by Harley Huang on 10/3/2021.
//  Copyright © 2021 Di Wu. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface RunloopController : UIViewController

@property (nonatomic, strong)NSTimer *runLoopObServerTimer;
@property (nonatomic, copy)NSString *name;

@end

NS_ASSUME_NONNULL_END
