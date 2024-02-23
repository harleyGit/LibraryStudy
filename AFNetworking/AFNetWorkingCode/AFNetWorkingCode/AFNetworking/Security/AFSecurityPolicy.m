// AFSecurityPolicy.m
// Copyright (c) 2011–2016 Alamofire Software Foundation ( http://alamofire.org/ )
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "AFSecurityPolicy.h"

#import <AssertMacros.h>

#if !TARGET_OS_IOS && !TARGET_OS_WATCH && !TARGET_OS_TV
static NSData * AFSecKeyGetData(SecKeyRef key) {
    CFDataRef data = NULL;

    __Require_noErr_Quiet(SecItemExport(key, kSecFormatUnknown, kSecItemPemArmour, NULL, &data), _out);

    return (__bridge_transfer NSData *)data;

_out:
    if (data) {
        CFRelease(data);
    }

    return nil;
}
#endif
//判断两个公钥是否相同
static BOOL AFSecKeyIsEqualToKey(SecKeyRef key1, SecKeyRef key2) {
#if TARGET_OS_IOS || TARGET_OS_WATCH || TARGET_OS_TV
    //iOS 判断二者地址
    return [(__bridge id)key1 isEqual:(__bridge id)key2];
#else
    return [AFSecKeyGetData(key1) isEqual:AFSecKeyGetData(key2)];
#endif
}

static id AFPublicKeyForCertificate(NSData *certificate) {
    id allowedPublicKey = nil;
    
    //用于存储创建的证书
    SecCertificateRef allowedCertificate;
    //用于指定信任策略
    SecPolicyRef policy = nil;
    //用于存储信任管理信息
    SecTrustRef allowedTrust = nil;
    //存储信任评估的结果类型
    SecTrustResultType result;

    //使用 SecCertificateCreateWithData 函数根据提供的二进制数据 (certificate) 创建一个证书对象。这通常是用于表示公钥证书的二进制数据。__bridge CFDataRef 是将 Objective-C 类型的 NSData 转换为 Core Foundation 类型的 CFDataRef
    allowedCertificate = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)certificate);
    //这是一个宏，用于进行错误检查。如果 allowedCertificate 为 NULL，则跳到 _out 标签处，可能是为了执行一些错误处理或清理代码。
    __Require_Quiet(allowedCertificate != NULL, _out);

    //使用 SecPolicyCreateBasicX509 函数创建一个基本的 X.509 信任策略。X.509 是一种证书标准，用于在网络中进行身份验证和加密通信
    policy = SecPolicyCreateBasicX509();
    //这是一个宏，用于检查 SecTrustCreateWithCertificates 函数的返回值。该函数基于提供的证书 (allowedCertificate) 和信任策略 (policy) 创建一个信任管理对象 (allowedTrust)
    __Require_noErr_Quiet(SecTrustCreateWithCertificates(allowedCertificate, policy, &allowedTrust), _out);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    //使用 SecTrustEvaluate 函数对先前创建的信任管理对象 allowedTrust 进行评估，并将评估的结果存储在 result 变量中。它还使用 __Require_noErr_Quiet 宏来检查评估是否成功，如果不成功，则跳转到 _out 标签处，可能包含一些错误处理或清理代码。
    __Require_noErr_Quiet(SecTrustEvaluate(allowedTrust, &result), _out);
#pragma clang diagnostic pop

    //返回与给定信任管理对象相关联的公钥。这是一个 Core Foundation 函数，返回的类型是 SecKeyRef，表示一个安全的公钥。
    allowedPublicKey = (__bridge_transfer id)SecTrustCopyPublicKey(allowedTrust);

_out:
    if (allowedTrust) {
        CFRelease(allowedTrust);
    }

    if (policy) {
        CFRelease(policy);
    }

    if (allowedCertificate) {
        CFRelease(allowedCertificate);
    }

    return allowedPublicKey;
}

/// 验证服务器信任的
/// @param serverTrust <#serverTrust description#>
static BOOL AFServerTrustIsValid(SecTrustRef serverTrust) {
    BOOL isValid = NO;
    SecTrustResultType result;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    //评估给定的 serverTrust，并将结果存储在 result 中。这是验证服务器信任的关键步骤。
    __Require_noErr_Quiet(SecTrustEvaluate(serverTrust, &result), _out);
#pragma clang diagnostic pop

    // 检查评估结果和状态
    isValid = (result == kSecTrustResultUnspecified || result == kSecTrustResultProceed);

_out:
    return isValid;
}

static NSArray * AFCertificateTrustChainForServerTrust(SecTrustRef serverTrust) {
    //使用SecTrustGetCertificateCount函数获取到serverTrust中需要评估的证书链中的证书数目，并保存到certificateCount中
    CFIndex certificateCount = SecTrustGetCertificateCount(serverTrust);
    //创建数组
    NSMutableArray *trustChain = [NSMutableArray arrayWithCapacity:(NSUInteger)certificateCount];

    for (CFIndex i = 0; i < certificateCount; i++) {
        SecCertificateRef certificate = SecTrustGetCertificateAtIndex(serverTrust, i);
        /// 使用SecTrustGetCertificateAtIndex函数获取到证书链中的每个证书，并添加到trustChain中，最后返回trustChain
        [trustChain addObject:(__bridge_transfer NSData *)SecCertificateCopyData(certificate)];
    }

    return [NSArray arrayWithArray:trustChain];
}

//从serverTrust中取出服务器端传过来的所有可用的证书，并依次得到相应的公钥
static NSArray * AFPublicKeyTrustChainForServerTrust(SecTrustRef serverTrust) {
    // 接下来的一小段代码和上面AFCertificateTrustChainForServerTrust函数的作用基本一致，都是为了获取到serverTrust中证书链上的所有证书，并依次遍历，取出公钥。
    //安全策略
    SecPolicyRef policy = SecPolicyCreateBasicX509();
    CFIndex certificateCount = SecTrustGetCertificateCount(serverTrust);
    NSMutableArray *trustChain = [NSMutableArray arrayWithCapacity:(NSUInteger)certificateCount];
    //遍历serverTrust里证书的证书链
    for (CFIndex i = 0; i < certificateCount; i++) {
        //从证书链取证书
        SecCertificateRef certificate = SecTrustGetCertificateAtIndex(serverTrust, i);

        //数组
        SecCertificateRef someCertificates[] = {certificate};
        //CF数组
        CFArrayRef certificates = CFArrayCreate(NULL, (const void **)someCertificates, 1, NULL);

        SecTrustRef trust;
        // 根据给定的certificates和policy来生成一个trust对象
        //不成功跳到 _out。
        __Require_noErr_Quiet(SecTrustCreateWithCertificates(certificates, policy, &trust), _out);
        SecTrustResultType result;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        __Require_noErr_Quiet(SecTrustEvaluate(trust, &result), _out);
#pragma clang diagnostic pop
        // 如果该trust符合X.509证书格式，那么先使用SecTrustCopyPublicKey获取到trust的公钥，再将此公钥添加到trustChain中
        [trustChain addObject:(__bridge_transfer id)SecTrustCopyPublicKey(trust)];

    _out:
        //释放资源
        if (trust) {
            CFRelease(trust);
        }

        if (certificates) {
            CFRelease(certificates);
        }

        continue;
    }
    CFRelease(policy);

    return [NSArray arrayWithArray:trustChain];
}

#pragma mark -

@interface AFSecurityPolicy()
@property (readwrite, nonatomic, assign) AFSSLPinningMode SSLPinningMode;
@property (readwrite, nonatomic, strong) NSSet *pinnedPublicKeys;
@end

@implementation AFSecurityPolicy

+ (NSSet *)certificatesInBundle:(NSBundle *)bundle {
    //获取了在主Bundle中所有文件扩展名为"cer"的资源的文件路径数组（由inDirectory:@"."指定）。得到的数组赋值给paths变量
    NSArray *paths = [bundle pathsForResourcesOfType:@"cer" inDirectory:@"."];

    //创建了一个可变集合certificates，使用setWithCapacity:。容量设置为paths数组的元素个数，这是一种根据预期元素数量预先分配集合内存的优化
    NSMutableSet *certificates = [NSMutableSet setWithCapacity:[paths count]];
    for (NSString *path in paths) {
        //读取了由当前path指定的文件的内容，并创建了一个NSData对象certificateData，其中包含了文件的内容
        NSData *certificateData = [NSData dataWithContentsOfFile:path];
        [certificates addObject:certificateData];
    }

    return [NSSet setWithSet:certificates];
}

+ (instancetype)defaultPolicy {
    AFSecurityPolicy *securityPolicy = [[self alloc] init];
    //表示在进行 SSL/TLS 握手时，不进行证书或公钥的校验，不要求服务器的证书必须是信任的证书。
    securityPolicy.SSLPinningMode = AFSSLPinningModeNone;

    return securityPolicy;
}

+ (instancetype)policyWithPinningMode:(AFSSLPinningMode)pinningMode {
    NSSet <NSData *> *defaultPinnedCertificates = [self certificatesInBundle:[NSBundle mainBundle]];
    return [self policyWithPinningMode:pinningMode withPinnedCertificates:defaultPinnedCertificates];
}

+ (instancetype)policyWithPinningMode:(AFSSLPinningMode)pinningMode withPinnedCertificates:(NSSet *)pinnedCertificates {
    AFSecurityPolicy *securityPolicy = [[self alloc] init];
    securityPolicy.SSLPinningMode = pinningMode;

    [securityPolicy setPinnedCertificates:pinnedCertificates];

    return securityPolicy;
}

- (instancetype)init {
    self = [super init];
    if (!self) {
        return nil;
    }

    self.validatesDomainName = YES;

    return self;
}

///根据这些证书获取设置公钥数组
- (void)setPinnedCertificates:(NSSet *)pinnedCertificates {
    _pinnedCertificates = pinnedCertificates;

    if (self.pinnedCertificates) {
        NSMutableSet *mutablePinnedPublicKeys = [NSMutableSet setWithCapacity:[self.pinnedCertificates count]];
        for (NSData *certificate in self.pinnedCertificates) {
            id publicKey = AFPublicKeyForCertificate(certificate);
            if (!publicKey) {
                continue;
            }
            [mutablePinnedPublicKeys addObject:publicKey];
        }
        self.pinnedPublicKeys = [NSSet setWithSet:mutablePinnedPublicKeys];
    } else {
        self.pinnedPublicKeys = nil;
    }
}

#pragma mark -

- (BOOL)evaluateServerTrust:(SecTrustRef)serverTrust
                  forDomain:(NSString *)domain
{
    if (domain && self.allowInvalidCertificates && self.validatesDomainName && (self.SSLPinningMode == AFSSLPinningModeNone || [self.pinnedCertificates count] == 0)) {
        // https://developer.apple.com/library/mac/documentation/NetworkingInternet/Conceptual/NetworkingTopics/Articles/OverridingSSLChainValidationCorrectly.html
        //  According to the docs, you should only trust your provided certs for evaluation.
        //  Pinned certificates are added to the trust. Without pinned certificates,
        //  there is nothing to evaluate against.
        //
        //  From Apple Docs:
        //          "Do not implicitly trust self-signed certificates as anchors (kSecTrustOptionImplicitAnchors).
        //           Instead, add your own (self-signed) CA certificate to the list of trusted anchors."
        NSLog(@"In order to validate a domain name for self signed certificates, you MUST use pinning.");
        return NO;
    }

    NSMutableArray *policies = [NSMutableArray array];
    if (self.validatesDomainName) {
        //SecPolicyCreateSSL: 创建一个启用SSL策略的对象，并且可能会与给定的域名（通过domain参数传递）相关联。SSL策略通常用于在进行安全通信时验证远程服务器的证书
        //  SecPolicyCreateSSL: 这是一个Security框架中的函数，用于创建SSL策略对象。SSL策略通常用于在安全通信中验证证书
        //  true: 这是一个布尔值，表示是否启用SSL策略。在这里，它被设置为true，表示启用SSL策略
        [policies addObject:(__bridge_transfer id)SecPolicyCreateSSL(true, (__bridge CFStringRef)domain)];
    } else {
        [policies addObject:(__bridge_transfer id)SecPolicyCreateBasicX509()];
    }

    //SecPolicyCreateBasicX509: 这是 Security 框架中的函数，用于创建基本的 X.509 策略对象。X.509 是一种公钥基础设施（PKI）标准，用于描述公共密钥证书的格式
    SecTrustSetPolicies(serverTrust, (__bridge CFArrayRef)policies);

    if (self.SSLPinningMode == AFSSLPinningModeNone) {
        return self.allowInvalidCertificates || AFServerTrustIsValid(serverTrust);
    } else if (!self.allowInvalidCertificates && !AFServerTrustIsValid(serverTrust)) {
        return NO;
    }

    switch (self.SSLPinningMode) {
        case AFSSLPinningModeCertificate: {
            NSMutableArray *pinnedCertificates = [NSMutableArray array];
            for (NSData *certificateData in self.pinnedCertificates) {
                //SecCertificateCreateWithData: 这是 Security 框架中的函数，用于根据提供的二进制数据创建一个证书对象
                [pinnedCertificates addObject:(__bridge_transfer id)SecCertificateCreateWithData(NULL, (__bridge CFDataRef)certificateData)];
            }
            /**
             * 通过调用 SecTrustSetAnchorCertificates，你告诉系统使用指定的锚点证书来验证服务器的证书。这在进行安全通信时非常有用，可以帮助确保通信方与预期的服务器建立安全连接。
             *
             * 1.SecTrustSetAnchorCertificates: 这是 Security 框架中的函数，用于为指定的 SecTrustRef 对象设置锚点证书（anchor certificates）。锚点证书是一组用于验证远程服务器证书的信任锚点。
             * 2.serverTrust: 这是一个 SecTrustRef 对象，代表了一个服务器的信任链。通常，这个 serverTrust 对象会包含服务器返回的证书链。
             * 3.(__bridge CFArrayRef)pinnedCertificates: 这是一个 Objective-C 数组，包含了你希望作为锚点的证书。__bridge CFArrayRef 用于将 Objective-C 数组转换为 Core Foundation 数组。这些锚点证书是你明确指定的、可信任的证书，用于验证服务器证书链
             */
            SecTrustSetAnchorCertificates(serverTrust, (__bridge CFArrayRef)pinnedCertificates);

            if (!AFServerTrustIsValid(serverTrust)) {
                return NO;
            }

            // obtain the chain after being validated, which *should* contain the pinned certificate in the last position (if it's the Root CA)
            NSArray *serverCertificates = AFCertificateTrustChainForServerTrust(serverTrust);
            
            for (NSData *trustChainCertificate in [serverCertificates reverseObjectEnumerator]) {
                if ([self.pinnedCertificates containsObject:trustChainCertificate]) {
                    return YES;
                }
            }
            
            return NO;
        }
        case AFSSLPinningModePublicKey: {
            NSUInteger trustedPublicKeyCount = 0;
            NSArray *publicKeys = AFPublicKeyTrustChainForServerTrust(serverTrust);

            for (id trustChainPublicKey in publicKeys) {
                for (id pinnedPublicKey in self.pinnedPublicKeys) {
                    if (AFSecKeyIsEqualToKey((__bridge SecKeyRef)trustChainPublicKey, (__bridge SecKeyRef)pinnedPublicKey)) {
                        trustedPublicKeyCount += 1;
                    }
                }
            }
            return trustedPublicKeyCount > 0;
        }
            
        default:
            return NO;
    }
    
    return NO;
}

#pragma mark - NSKeyValueObserving

+ (NSSet *)keyPathsForValuesAffectingPinnedPublicKeys {
    return [NSSet setWithObject:@"pinnedCertificates"];
}

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)decoder {

    self = [self init];
    if (!self) {
        return nil;
    }

    self.SSLPinningMode = [[decoder decodeObjectOfClass:[NSNumber class] forKey:NSStringFromSelector(@selector(SSLPinningMode))] unsignedIntegerValue];
    self.allowInvalidCertificates = [decoder decodeBoolForKey:NSStringFromSelector(@selector(allowInvalidCertificates))];
    self.validatesDomainName = [decoder decodeBoolForKey:NSStringFromSelector(@selector(validatesDomainName))];
    self.pinnedCertificates = [decoder decodeObjectOfClass:[NSSet class] forKey:NSStringFromSelector(@selector(pinnedCertificates))];

    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:[NSNumber numberWithUnsignedInteger:self.SSLPinningMode] forKey:NSStringFromSelector(@selector(SSLPinningMode))];
    [coder encodeBool:self.allowInvalidCertificates forKey:NSStringFromSelector(@selector(allowInvalidCertificates))];
    [coder encodeBool:self.validatesDomainName forKey:NSStringFromSelector(@selector(validatesDomainName))];
    [coder encodeObject:self.pinnedCertificates forKey:NSStringFromSelector(@selector(pinnedCertificates))];
}

#pragma mark - NSCopying

- (instancetype)copyWithZone:(NSZone *)zone {
    AFSecurityPolicy *securityPolicy = [[[self class] allocWithZone:zone] init];
    securityPolicy.SSLPinningMode = self.SSLPinningMode;
    securityPolicy.allowInvalidCertificates = self.allowInvalidCertificates;
    securityPolicy.validatesDomainName = self.validatesDomainName;
    securityPolicy.pinnedCertificates = [self.pinnedCertificates copyWithZone:zone];

    return securityPolicy;
}

@end
