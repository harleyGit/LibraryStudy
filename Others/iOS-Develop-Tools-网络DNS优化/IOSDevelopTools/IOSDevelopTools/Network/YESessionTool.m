//
//  YESessionTool.m
//  IOSDevelopTools
//
//  Created by SimonYHB on 2020/4/27.
//  Copyright © 2020 SimonYe. All rights reserved.
//

#import "YESessionTool.h"
#import "NSString+YEUtil.h"

#define CerFile  @"xxx"

@interface YESessionTool ()
@property (nonatomic, strong)NSMutableDictionary *sessionDict;

@end


@implementation YESessionTool

#pragma mark - Public
+ (nonnull instancetype)shareInstance {
    static YESessionTool *instance = nil;
    static dispatch_once_t onceToken;
    if (!instance) {
        dispatch_once(&onceToken, ^{
            instance = [[YESessionTool alloc] init];
        });
    }
    
    return instance;
}

- (void)zgetSessionManagerWithRequest:(NSURLRequest *)request
                            callBack:(YESessionToolCallBack)callBack {
    // 本地资源单独处理
    if (![request.URL.absoluteString hasPrefix:@"http"]) {
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        YESessionManager *manager = [[YESessionManager alloc] initWithSessionConfiguration:config];
        manager.responseSerializer = [AFHTTPResponseSerializer serializer];
        if (manager) {
            callBack(manager);
        }
        return;
    }
    // 网络请求
    YESessionManager *cacheManager = [self.sessionDict objectForKey:request.URL.host];
    if (cacheManager == nil) {
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        cacheManager = [[YESessionManager alloc] initWithSessionConfiguration:config];
        cacheManager.responseSerializer = [AFHTTPResponseSerializer serializer];
        
        // 设置网络安全策略
        [self setSSLPolicy:cacheManager request:request];
        
        [self.sessionDict setObject:cacheManager forKey:request.URL.host];
    }
    
    if (callBack) {
        callBack(cacheManager);
    }
    return;
    
    
    
    

}

#pragma mark - Private
- (void)setSSLPolicy: (YESessionManager *)manager request:(NSURLRequest *)request {
    // 区分域名和ip请求
    if ([request.URL.host isIPAddressString]) {
        [self setIPNetPolicy:manager request:request];

    } else {
        [self setDomainNetPolicy:manager request:request];
    }
}

//证书校验分为 IP 请求和域名请求，对于普通的域名请求，我们只需要设置 SessionManager 安全策略即可
// 域名请求的证书校验设置
- (void)setDomainNetPolicy: (YESessionManager *)manager request:(NSURLRequest *)request {
    AFSecurityPolicy *securityPolicy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeCertificate];
    securityPolicy.validatesDomainName = YES;
    securityPolicy.allowInvalidCertificates = YES;
    // 从本地获取cer证书，仅作参考
    NSString * cerPath = [[NSBundle mainBundle] pathForResource:CerFile ofType:@"cer"];
    NSData * cerData = [NSData dataWithContentsOfFile:cerPath];
    securityPolicy.pinnedCertificates = [NSSet setWithObject:cerData];
    manager.securityPolicy = securityPolicy;
    
}

// IP请求的证书校验设置
//IP 请求部分稍微复杂点，我们在收到服务器安全认证请求时，再用真实域名和本地证书去进行校验，AFNetworking 提供了 setSessionDidReceiveAuthenticationChallengeBlock 和 setTaskDidReceiveAuthenticationChallengeBlock 方法可以让我们设置认证请求时的回调
- (void)setIPNetPolicy: (YESessionManager *)manager request:(NSURLRequest *)request {
    // 判断是否存在域名
    NSString *realDomain = [request.allHTTPHeaderFields objectForKey:@"host"];
    if (realDomain == nil || realDomain.length == 0) {
        //无域名不验证
        return;
    }
    
    
    // 通过客户端验证服务器信任凭证
    //用于设置一个回调块，以便在 NSURLSession 收到认证挑战时执行自定义的处理逻辑，提供了更灵活、更定制的方式来处理网络请求中的身份验证需求
    //或者也可以这么理解为这个方法，通常用于设置一个回调块（block），以便在 NSURLSession 收到认证挑战时执行自定义的处理逻辑。这个方法在处理需要进行身份验证的网络请求时非常有用，比如 HTTPS 请求。
    [manager setSessionDidReceiveAuthenticationChallengeBlock:^NSURLSessionAuthChallengeDisposition(NSURLSession * _Nonnull session, NSURLAuthenticationChallenge * _Nonnull challenge, NSURLCredential *__autoreleasing  _Nullable * _Nullable credential) {
        return [self handleReceiveAuthenticationChallenge:challenge credential:credential host:realDomain];
    }];
    
    //这个方法用于设置一个回调块（block），以便在 NSURLSessionTask（通常是一个具体的网络请求任务）收到认证挑战时执行自定义的处理逻辑。这个方法提供了对特定网络请求任务的认证挑战进行处理的能力，允许你在收到认证挑战时执行特定于任务的逻辑
    [manager setTaskDidReceiveAuthenticationChallengeBlock:^NSURLSessionAuthChallengeDisposition(NSURLSession * _Nonnull session, NSURLSessionTask * _Nonnull task, NSURLAuthenticationChallenge * _Nonnull challenge, NSURLCredential *__autoreleasing  _Nullable * _Nullable credential) {
        return [self handleReceiveAuthenticationChallenge:challenge credential:credential host:realDomain];
    }];
}


// 处理认证请求发生的回调
///这段代码是对 NSURLSession 收到的认证挑战进行处理的逻辑，根据条件判断是否创建凭证对象，并决定如何处理认证挑战。
- (NSURLSessionAuthChallengeDisposition)handleReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge*)challenge
                                                       credential:(NSURLCredential**)credential
                                                             host:(NSString*)host
{
    //NSURLSessionAuthChallengeDisposition 是一个枚举类型，用于在处理 NSURLSession 接收到的认证挑战时指定处理方式。这个枚举在处理 HTTPS 请求时非常有用，因为服务器可能会要求客户端提供证书或者进行其他形式的身份验证
    //erformDefaultHandling: 执行默认处理。这意味着由系统提供的默认认证机制将会被使用，通常会弹出一个对话框要求用户输入用户名和密码，或者使用客户端证书来完成认证。
    NSURLSessionAuthChallengeDisposition disposition = NSURLSessionAuthChallengePerformDefaultHandling;
    
    //NSURLAuthenticationMethodServerTrust 是一个常量字符串，表示服务器信任认证。这个认证方法用于 TLS/SSL 握手，允许客户端自定义服务器信任的证书链。
    //这个条件判断时，我们正在检查当前的认证挑战是否是基于服务器信任的认证挑战。通常，当服务器使用 TLS/SSL 协议与客户端进行通信时，会发送一个信任认证挑战，要求客户端验证服务器的身份。在这种情况下，客户端可以执行额外的验证，如验证服务器的证书是否由可信的 CA 签发，以确保与服务器的通信是安全的。
    //如果条件判断为真，则表示当前的认证挑战是基于服务器信任的，客户端可以根据自己的需求执行额外的验证逻辑，例如检查服务器证书是否符合预期，然后决定是否信任服务器。
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust])
    {
        //验证域名是否被信任
        if ([self evaluateServerTrust:challenge.protectionSpace.serverTrust forDomain:host])
        {
            //这个方法的作用是创建一个凭证对象，用于在 SSL/TLS 握手时使用服务器信任。如果成功创建了凭证对象，则 credential 变量将被赋值为非空值，表示认证挑战可以使用凭证来完成认证
            *credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
            if (*credential){//如果 credential 非空，说明已经成功创建了凭证对象，可以用于认证挑战，因此将 disposition 设置为 NSURLSessionAuthChallengeUseCredential，表示将使用凭证来完成认证。
                disposition = NSURLSessionAuthChallengeUseCredential;
            }else{//默认处理或取消认证挑战
                disposition = NSURLSessionAuthChallengePerformDefaultHandling;
            }
        }else{//取消当前的认证挑战
            disposition = NSURLSessionAuthChallengeCancelAuthenticationChallenge;
        }
    }else{//不等于 NSURLAuthenticationMethodServerTrust，即当前认证挑战不是基于服务器信任的认证挑战，则将 disposition 设置为 NSURLSessionAuthChallengePerformDefaultHandling，表示执行默认的认证处理机制。
        disposition = NSURLSessionAuthChallengePerformDefaultHandling;
    }
    return disposition;
}


/// 验证域名
/// @param serverTrust 表示服务器信任
/// @param domain 表示服务器的域名
- (BOOL)evaluateServerTrust:(SecTrustRef)serverTrust forDomain:(NSString *)domain
{
    //设置 SSL Pinning 模式为 AFSSLPinningModeCertificate，表示只验证服务器的证书
    AFSecurityPolicy *securityPolicy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeCertificate];
    //表示验证服务器的域名
    securityPolicy.validatesDomainName = YES;
    //允许使用自签名或者无效的证书进行连接。这在某些情况下可能会有用，但需要注意安全风险。
    securityPolicy.allowInvalidCertificates = YES;
    
    //设置固定证书: 然后，从本地获取了一个证书文件的路径，并将其读取为 NSData 对象。这个证书文件通常是预先获取并打包在应用程序中的，用于验证服务器的身份。将证书数据设置到 pinnedCertificates 属性中，这样 AFSecurityPolicy 就会使用这个证书来验证服务器的证书。
    // 从本地获取cer证书,仅作参考
    NSString * cerPath = [[NSBundle mainBundle] pathForResource:CerFile ofType:@"cer"];
    NSData * cerData = [NSData dataWithContentsOfFile:cerPath];
    securityPolicy.pinnedCertificates = [NSSet setWithObject:cerData];
    
    //这个方法会根据之前设置的验证选项来评估服务器的信任，并返回一个布尔值，表示服务器是否被信任
    return [securityPolicy evaluateServerTrust:serverTrust forDomain:domain];
}
@end
