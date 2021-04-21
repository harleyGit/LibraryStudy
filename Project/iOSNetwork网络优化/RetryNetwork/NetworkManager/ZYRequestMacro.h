//
//  ZYRequestMacro.h
//  RetryNetwork
//
//  Created by 王志盼 on 2017/12/22.
//  Copyright © 2017年 王志盼. All rights reserved.
//

#ifndef ZYRequestMacro_h
#define ZYRequestMacro_h

typedef NS_ENUM(NSInteger, YQDRequestType) {
    YQDRequestTypeGet,
    YQDRequestTypePost,
    YQDRequestTypeDelete,
    YQDRequestTypePut
};

//定时器每隔60s查询一次数据库
#define kTimerDuration 60

#endif /* ZYRequestMacro_h */
