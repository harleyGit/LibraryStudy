/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "SDWebImageTransition.h"

#if SD_UIKIT || SD_MAC

#if SD_MAC
#import <QuartzCore/QuartzCore.h>
#endif

@implementation SDWebImageTransition

- (instancetype)init {
    self = [super init];
    if (self) {
        self.duration = 0.5;
    }
    return self;
}

@end

@implementation SDWebImageTransition (Conveniences)
//创建一个渐变效果的图像切换对象
+ (SDWebImageTransition *)fadeTransition {
    SDWebImageTransition *transition = [SDWebImageTransition new];
#if SD_UIKIT
    //UIViewAnimationOptionTransitionCrossDissolve：表示视图切换时采用交叉淡入淡出的过渡效果
    //UIViewAnimationOptionAllowUserInteraction：允许用户在动画执行过程中与界面进行交互
    transition.animationOptions = UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowUserInteraction;
#else
    transition.animations = ^(__kindof NSView * _Nonnull view, NSImage * _Nullable image) {
        //用于定义 Core Animation 转场动画。CATransition 是 Core Animation 提供的用于视图切换效果的类
        CATransition *trans = [CATransition animation];
        trans.type = kCATransitionFade;
        [view.layer addAnimation:trans forKey:kCATransition];
    };
#endif
    return transition;
}


/// 创建一个从左侧翻转的图像切换效果的过渡对象
+ (SDWebImageTransition *)flipFromLeftTransition {
    SDWebImageTransition *transition = [SDWebImageTransition new];
#if SD_UIKIT
    transition.animationOptions = UIViewAnimationOptionTransitionFlipFromLeft | UIViewAnimationOptionAllowUserInteraction;
#else
    transition.animations = ^(__kindof NSView * _Nonnull view, NSImage * _Nullable image) {
        CATransition *trans = [CATransition animation];
        //kCATransitionPush;： 设置转场动画的类型。在这里，kCATransitionPush 表示使用推送效果，即视图的切换过程中会有推入的动画效果
        trans.type = kCATransitionPush;
        //设置转场动画的方向。在这里，kCATransitionFromLeft 表示动画方向是从左侧开始，即视图从左侧推入
        trans.subtype = kCATransitionFromLeft;
        [view.layer addAnimation:trans forKey:kCATransition];
    };
#endif
    return transition;
}
//创建一个从右侧翻转的图像切换效果的过渡对象
+ (SDWebImageTransition *)flipFromRightTransition {
    SDWebImageTransition *transition = [SDWebImageTransition new];
#if SD_UIKIT
    transition.animationOptions = UIViewAnimationOptionTransitionFlipFromRight | UIViewAnimationOptionAllowUserInteraction;
#else
    transition.animations = ^(__kindof NSView * _Nonnull view, NSImage * _Nullable image) {
        CATransition *trans = [CATransition animation];
        trans.type = kCATransitionPush;
        trans.subtype = kCATransitionFromRight;
        [view.layer addAnimation:trans forKey:kCATransition];
    };
#endif
    return transition;
}


/// 创建一个从顶部翻转的图像切换效果的过渡对象
+ (SDWebImageTransition *)flipFromTopTransition {
    SDWebImageTransition *transition = [SDWebImageTransition new];
#if SD_UIKIT
    transition.animationOptions = UIViewAnimationOptionTransitionFlipFromTop | UIViewAnimationOptionAllowUserInteraction;
#else
    transition.animations = ^(__kindof NSView * _Nonnull view, NSImage * _Nullable image) {
        CATransition *trans = [CATransition animation];
        trans.type = kCATransitionPush;
        trans.subtype = kCATransitionFromTop;
        [view.layer addAnimation:trans forKey:kCATransition];
    };
#endif
    return transition;
}

+ (SDWebImageTransition *)flipFromBottomTransition {
    SDWebImageTransition *transition = [SDWebImageTransition new];
#if SD_UIKIT
    transition.animationOptions = UIViewAnimationOptionTransitionFlipFromBottom | UIViewAnimationOptionAllowUserInteraction;
#else
    transition.animations = ^(__kindof NSView * _Nonnull view, NSImage * _Nullable image) {
        CATransition *trans = [CATransition animation];
        trans.type = kCATransitionPush;
        trans.subtype = kCATransitionFromBottom;
        [view.layer addAnimation:trans forKey:kCATransition];
    };
#endif
    return transition;
}


/// 创建一个卷曲向上翻页的图像切换效果的过渡对象
+ (SDWebImageTransition *)curlUpTransition {
    SDWebImageTransition *transition = [SDWebImageTransition new];
#if SD_UIKIT
    transition.animationOptions = UIViewAnimationOptionTransitionCurlUp | UIViewAnimationOptionAllowUserInteraction;
#else
    transition.animations = ^(__kindof NSView * _Nonnull view, NSImage * _Nullable image) {
        CATransition *trans = [CATransition animation];
        trans.type = kCATransitionReveal;
        trans.subtype = kCATransitionFromTop;
        [view.layer addAnimation:trans forKey:kCATransition];
    };
#endif
    return transition;
}

+ (SDWebImageTransition *)curlDownTransition {
    SDWebImageTransition *transition = [SDWebImageTransition new];
#if SD_UIKIT
    transition.animationOptions = UIViewAnimationOptionTransitionCurlDown | UIViewAnimationOptionAllowUserInteraction;
#else
    transition.animations = ^(__kindof NSView * _Nonnull view, NSImage * _Nullable image) {
        CATransition *trans = [CATransition animation];
        trans.type = kCATransitionReveal;
        trans.subtype = kCATransitionFromBottom;
        [view.layer addAnimation:trans forKey:kCATransition];
    };
#endif
    return transition;
}

@end

#endif
