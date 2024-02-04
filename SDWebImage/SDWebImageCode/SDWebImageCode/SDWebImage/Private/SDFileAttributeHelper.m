//
//  This file is from https://gist.github.com/zydeco/6292773
//
//  Created by Jesús A. Álvarez on 2008-12-17.
//  Copyright 2008-2009 namedfork.net. All rights reserved.
//

#import "SDFileAttributeHelper.h"
#import <sys/xattr.h>

@implementation SDFileAttributeHelper

+ (NSArray*)extendedAttributeNamesAtPath:(NSString *)path traverseLink:(BOOL)follow error:(NSError **)err {
    int flags = follow? 0 : XATTR_NOFOLLOW;
    
    // get size of name list
    ssize_t nameBuffLen = listxattr([path fileSystemRepresentation], NULL, 0, flags);
    if (nameBuffLen == -1) {
        if (err) *err = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:
                         @{
                             @"error": [NSString stringWithUTF8String:strerror(errno)],
                             @"function": @"listxattr",
                             @":path": path,
                             @":traverseLink": @(follow)
                         }
                         ];
        return nil;
    } else if (nameBuffLen == 0) return @[];
    
    // get name list
    NSMutableData *nameBuff = [NSMutableData dataWithLength:nameBuffLen];
    listxattr([path fileSystemRepresentation], [nameBuff mutableBytes], nameBuffLen, flags);
    
    // convert to array
    NSMutableArray * names = [NSMutableArray arrayWithCapacity:5];
    char *nextName, *endOfNames = [nameBuff mutableBytes] + nameBuffLen;
    for(nextName = [nameBuff mutableBytes]; nextName < endOfNames; nextName += 1+strlen(nextName))
        [names addObject:[NSString stringWithUTF8String:nextName]];
    return names.copy;
}

+ (BOOL)hasExtendedAttribute:(NSString *)name atPath:(NSString *)path traverseLink:(BOOL)follow error:(NSError **)err {
    int flags = follow? 0 : XATTR_NOFOLLOW;
    
    // get size of name list
    ssize_t nameBuffLen = listxattr([path fileSystemRepresentation], NULL, 0, flags);
    if (nameBuffLen == -1) {
        if (err) *err = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:
                         @{
                             @"error": [NSString stringWithUTF8String:strerror(errno)],
                             @"function": @"listxattr",
                             @":path": path,
                             @":traverseLink": @(follow)
                         }
                         ];
        return NO;
    } else if (nameBuffLen == 0) return NO;
    
    // get name list
    NSMutableData *nameBuff = [NSMutableData dataWithLength:nameBuffLen];
    listxattr([path fileSystemRepresentation], [nameBuff mutableBytes], nameBuffLen, flags);
    
    // find our name
    char *nextName, *endOfNames = [nameBuff mutableBytes] + nameBuffLen;
    for(nextName = [nameBuff mutableBytes]; nextName < endOfNames; nextName += 1+strlen(nextName))
        if (strcmp(nextName, [name UTF8String]) == 0) return YES;
    return NO;
}

///获取扩展属性的值
+ (NSData *)extendedAttribute:(NSString *)name atPath:(NSString *)path traverseLink:(BOOL)follow error:(NSError **)err {
    
    //XATTR_NOFOLLOW 主要与符号链接有关。如果你希望在设置或获取文件的 Extended Attributes 时不要跟随符号链接，就可以使用这个标记。
    //如果符号链接指向一个目录，XATTR_NOFOLLOW 将确保 Extended Attributes 不会应用于符号链接所指向的目录，而是应用于符号链接本身。
    int flags = follow? 0 : XATTR_NOFOLLOW;
    
    // get length
    //fileSystemRepresentation 方法返回了文件路径的 C 字符串表示形式
    //该函数返回读取的 Extended Attribute 的字节数，或者如果出错，则返回 -1。如果传递的缓冲区大小 size 小于 Extended Attribute 的实际大小，那么只会读取部分数据，并返回实际读取的字节数
    ssize_t attrLen = getxattr([path fileSystemRepresentation], [name UTF8String], NULL, 0, 0, flags);
    if (attrLen == -1) {
        if (err) *err = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:
                         @{
                             @"error": [NSString stringWithUTF8String:strerror(errno)],
                             @"function": @"getxattr",
                             @":name": name,
                             @":path": path,
                             @":traverseLink": @(follow)
                         }
                         ];
        return nil;
    }
    
    // get attribute data
    NSMutableData *attrData = [NSMutableData dataWithLength:attrLen];
    getxattr([path fileSystemRepresentation], [name UTF8String], [attrData mutableBytes], attrLen, 0, flags);
    return attrData;
}

+ (BOOL)setExtendedAttribute:(NSString *)name value:(NSData *)value atPath:(NSString *)path traverseLink:(BOOL)follow overwrite:(BOOL)overwrite error:(NSError **)err {
    int flags = (follow? 0 : XATTR_NOFOLLOW) | (overwrite? 0 : XATTR_CREATE);
    //设置扩展属性: https://www.cnblogs.com/fanjing/p/4551589.html
    if (0 == setxattr([path fileSystemRepresentation], [name UTF8String], [value bytes], [value length], 0, flags)) return YES;
    // error
    if (err) *err = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:
                     @{
                         @"error": [NSString stringWithUTF8String:strerror(errno)],
                         @"function": @"setxattr",
                         @":name": name,
                         @":value.length": @(value.length),
                         @":path": path,
                         @":traverseLink": @(follow),
                         @":overwrite": @(overwrite)
                     }
                     ];
    return NO;
}

+ (BOOL)removeExtendedAttribute:(NSString *)name atPath:(NSString *)path traverseLink:(BOOL)follow error:(NSError **)err {
    // XATTR_NOFOLLOW 是一个标志（flag），用于在文件系统扩展属性相关的操作中指定不要跟随符号链接
    //在 Unix-like 操作系统中，扩展属性允许为文件或目录关联额外的元数据信息。XATTR_NOFOLLOW 标志通常与文件系统操作函数一起使用，以指示在访问文件时不要跟随符号链接的扩展属性
    int flags = (follow? 0 : XATTR_NOFOLLOW);
    //removexattr 是一个 Unix-like 操作系统中的系统调用，用于移除文件或目录的扩展属性（Extended Attributes，简称 xattr）。扩展属性是与文件或目录关联的元数据信息，可以用来存储一些额外的信息
    if (0 == removexattr([path fileSystemRepresentation], [name UTF8String], flags)) return YES;
    // error
    if (err) *err = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:
                     @{
                         @"error": [NSString stringWithUTF8String:strerror(errno)],
                         @"function": @"removexattr",
                         @":name": name,
                         @":path": path,
                         @":traverseLink": @(follow)
                     }
                     ];
    return NO;
}

@end
