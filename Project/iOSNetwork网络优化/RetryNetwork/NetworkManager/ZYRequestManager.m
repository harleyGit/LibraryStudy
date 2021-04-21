//
//  ZYRequestManager.m
//  RetryNetwork
//
//  Created by 王志盼 on 2017/12/21.
//  Copyright © 2017年 王志盼. All rights reserved.
//

#import "ZYRequestManager.h"
#import "ZYRequest.h"
#import "YQDHttpClinetCore.h"
#import "ZYRequestCache.h"


@interface ZYRequestManager()

//这个串行队列用来控制任务有序的执行
@property (nonatomic, strong) NSMutableArray *requestQueue;
//存放request的成功回调
@property (nonatomic, strong) NSMutableArray *successQueue;
//存放request的失败回调
@property (nonatomic, strong) NSMutableArray *failureQueue;

@property (nonatomic, strong) dispatch_semaphore_t semaphore;


//添加、删除队列，维护添加与删除request在同一个线程
@property (nonatomic, strong) dispatch_queue_t addDelQueue;

//requestQueue队列是否正在轮询
@property (nonatomic, assign) BOOL isRetaining;

//定时器，每隔60s查询一次realm数据库里面的request
//如果存在request，并且kIsConnectingNetwork为true的情况下，将这些request重新装入队列发送
@property (nonatomic, strong) NSTimer *timer;
@end

static id _instance = nil;


//最大并发数
static const int _maxCurrentNum = 3;

@implementation ZYRequestManager
+ (instancetype)sharedInstance
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        if (!_instance)
        {
            _instance = [[self alloc] init];
        }
    });
    return _instance;
}

- (instancetype)init
{
    if (self = [super init])
    {
        self.semaphore = dispatch_semaphore_create(_maxCurrentNum);
        self.isRetaining = false;
        [self startTimer];
    }
    return self;
}

//暴露给外界
- (void)sendRequest:(ZYRequest *)request successBlock:(SuccessBlock)successBlock failureBlock:(FailedBlock)failedBlock
{
    //如果是ZYRequestReliabilityStoreToDB类型
    //第一时间先存储到数据库，然后再发送该请求，如果成功再从数据库中移除
    //不成功再触发某机制从数据库中取出重新发送
    if (request.reliability == ZYRequestReliabilityStoreToDB)
    {
        [[ZYRequestCache sharedInstance] saveRequestToRealm:request];
    }
    
    [self queueAddRequest:request successBlock:successBlock failureBlock:failedBlock];
    
}

- (void)dealRequestQueue
{
//    if (self.isRetaining) return;
//    self.isRetaining = true;
    
    //在子线程轮询，以免阻塞主线程
    //让请求按队列先后顺序发送
    
        
    while (self.requestQueue.count > 0)
    {
        ZYRequest *request = self.requestQueue.firstObject;
        SuccessBlock successBlock = self.successQueue.firstObject;
        FailedBlock failedBlock = self.failureQueue.firstObject;
        [self queueRemoveFirstObj];
        NSLog(@"----------------[%d]", request.requestId);
        dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
        //利用AFN发送请求
        [[YQDHttpClinetCore sharedClient] requestWithPath:request.urlStr method:request.method parameters:request.params prepareExecute:nil success:^(NSURLSessionDataTask *task, id responseObject) {
            dispatch_semaphore_signal(self.semaphore);
            
//                NSLog(@"++++++++%d", request.requestId);
            //在这里可以根据状态码处理相应信息、序列化数据、是否需要缓存等
            if (request.cacheKey)
            {
                NSError *error = nil;
                NSData *data = [NSJSONSerialization dataWithJSONObject:responseObject options:NSJSONWritingPrettyPrinted error:&error];
                
                if (!error)
                {
                    [[ZYRequestCache sharedInstance] saveData:data ForKey:request.cacheKey];
                }
            }
            
            //在成功的时候移除realm数据库中的缓存
            if (request.reliability == ZYRequestReliabilityStoreToDB)
            {
                [[ZYRequestCache sharedInstance] deleteRequestFromRealmWithRequestId:request.requestId];
            }
            
            successBlock(responseObject);
            
        } failure:^(NSURLSessionDataTask *task, NSError *error) {
            
            dispatch_semaphore_signal(self.semaphore);
            
            //请求失败之后，根据约定的错误码判断是否需要再次请求
            //这里，-1001是AFN的超时error
            if (error.code == -1001 &&request.retryCount > 0)
            {
                [request reduceRetryCount];
                [self queueAddRequest:request successBlock:successBlock failureBlock:failedBlock];
                [self dealRequestQueue];
            }
            else  //处理错误信息
            {
                failedBlock(error);
            }
        }];
    }
        
//        if (self.requestQueue.count == 0)
//        {
//            dispatch_async(dispatch_get_main_queue(), ^{
//                self.isRetaining = false;
//            });
//        }
    
}

- (void)queueAddRequest:(ZYRequest *)request successBlock:successBlock failureBlock:failedBlock
{
    
    if (request == nil)
    {
        NSLog(@"ZYRequest 不能为nil");
        return;
    }
    
    dispatch_async(self.addDelQueue, ^{
        
        if ([self.requestQueue containsObject:request]) return;
        
        [self.requestQueue addObject:request];
        //做容错处理，如果block为空，设置默认block
        id tmpBlock = [successBlock copy];
        if (successBlock == nil)
        {
            tmpBlock = [^(id obj){} copy];
        }
        [self.successQueue addObject:tmpBlock];
        
        
        tmpBlock = [failedBlock copy];
        if (failedBlock == nil)
        {
            tmpBlock = [^(id obj){} copy];
        }
        [self.failureQueue addObject:tmpBlock];
        
        [self dealRequestQueue];
    });
}

- (void)queueRemoveFirstObj
{
    
    if (self.requestQueue.count >= 1)
    {
        [self.requestQueue removeObjectAtIndex:0];
        [self.successQueue removeObjectAtIndex:0];
        [self.failureQueue removeObjectAtIndex:0];
    }
}

#pragma mark - Timer
- (void)startTimer
{
    [self.timer invalidate];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:kTimerDuration target:self selector:@selector(updateTimer) userInfo:nil repeats:true];
    [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSDefaultRunLoopMode];
}

- (void)updateTimer
{
    NSArray *requestArr = [[ZYRequestCache sharedInstance] allRequestsFromRealmWihtClass:[ZYRequest class]];
    
    if (requestArr != nil && requestArr.count > 0)
    {
        //需要注意的是，存入数据库里面的request是不需要回调的
        //必定成功，当然如果需要更新时间戳的话，可以重新拼接参数的时间戳
        [requestArr enumerateObjectsUsingBlock:^(ZYRequest *obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [self queueAddRequest:[obj copy] successBlock:nil failureBlock:nil];
        }];
        [self dealRequestQueue];
    }
    
}

#pragma mark - getter && setter
- (NSMutableArray *)requestQueue
{
    if (!_requestQueue)
    {
        _requestQueue = [NSMutableArray array];
    }
    return _requestQueue;
}

- (NSMutableArray *)successQueue
{
    if (!_successQueue)
    {
        _successQueue = [NSMutableArray array];
    }
    return _successQueue;
}

- (NSMutableArray *)failureQueue
{
    if (!_failureQueue)
    {
        _failureQueue = [NSMutableArray array];
    }
    return _failureQueue;
}


- (dispatch_queue_t)addDelQueue
{
    if (!_addDelQueue)
    {
        _addDelQueue = dispatch_queue_create("com.addDel.www", DISPATCH_QUEUE_SERIAL);
    }
    return _addDelQueue;
}

@end
