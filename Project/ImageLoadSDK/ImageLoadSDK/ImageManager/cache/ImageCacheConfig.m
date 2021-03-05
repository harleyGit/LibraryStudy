//
//  ImageCacheConfig.m
//  ImageLoadSDK
//
//  Created by Harley Huang on 26/11/2020.
//

#import "ImageCacheConfig.h"

static const NSInteger kDefaultMaxCacheAge = 60 * 60 * 24 * 7;

@implementation ImageCacheConfig

- (instancetype)init {
    if (self = [super init]) {
        self.shouldCacheImagesInDisk = YES;
        self.shouldCacheImagesInMemory = YES;
        self.maxCacheAge = kDefaultMaxCacheAge;
        self.maxCacheSize = NSIntegerMax;
    }
    return self;
}

@end
