> 1. 常驻线程

&emsp;	AFNetworking3.0后不再需要常驻线程是因为采用了NSURLSession来进行封装，但是在`AFNetworking2.0`时用的是NSURLConnection来进行封装的。

&emsp;	从iOS9.0开始 deprecated 了NSURLConnection，替代方案就是NSURLSession。当然NSURLSession还解决了很多其他的问题。

```
self.operationQueue = [[NSOperationQueue alloc] init];
self.operationQueue.maxConcurrentOperationCount = 1;
self.session = [NSURLSession sessionWithConfiguration:self.sessionConfiguration delegate:self delegateQueue:self.operationQueue];

```
&emsp;	从上面的代码可以看出，NSURLSession发起的请求，不再需要在当前线程进行代理方法的回调,可以指定回调的delegateQueue，`这样我们就不用为了使用NSURLConnection等待代理回调方法而苦苦保活线程了`。

&emsp;	`NSURLConnection`的接口是异步的，然后会在发起的线程回调。而一个子线程，在同步代码执行完成之后，一般情况下，线程就退出了。那么想要接收到NSURLConnection的回调`(这个回调是其在代理方法中，不是block中)`，就必须让子线程至少存活到回调的时机。而AF让线程常驻的原因是，当发起多个http请求的时候，会统一在这个子线程进行回调的处理，所以干脆就让其一直存活下来。


<br/>

***
<br/>


>	2. 为什么AF3.0中需要设置
`self.operationQueue.maxConcurrentOperationCount = 1;`,而AF2.0却不需要？

这个问题不难，可以帮助面试官判断面试者是否真的认真研读了AF的两个大版本的源码。

&emsp;	功能不一样：AF3.0的operationQueue是用来接收NSURLSessionDelegate回调的，鉴于一些多线程数据访问的安全性考虑，设置了maxConcurrentOperationCount = 1来达到串行回调的效果。

&emsp;	而AF2.0的operationQueue是用来添加operation并进行并发请求的，每个operation后都有一个闭包回调区分了返回结果，所以不要设置为1。

```
- (AFHTTPRequestOperation *)POST:(NSString *)URLString
                      parameters:(id)parameters
                         success:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success
                         failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))failure
{
    AFHTTPRequestOperation *operation = [self HTTPRequestOperationWithHTTPMethod:@"POST" URLString:URLString parameters:parameters success:success failure:failure];
    [self.operationQueue addOperation:operation];
    return operation;
}
```

回顾下 NSOperation使用：
```
// 1.创建队列
NSOperationQueue *queue = [[NSOperationQueue alloc] init];

// 2.创建操作
// 使用 NSInvocationOperation 创建操作1
NSInvocationOperation *op1 = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(task2) object:nil];

// 3.使用 addOperation: 添加所有操作到队列中
[queue addOperation:op1]; // [op1 start]
[queue addOperation:op2]; // [op2 start]
[queue addOperation:op3]; // [op3 start]
 }
 
 - (void)task2 {
     for (int i = 0; i < 2; i++) {
         [NSThread sleepForTimeInterval:2]; // 模拟耗时操作
         NSLog(@"2---%@", [NSThread currentThread]); // 打印当前线程
     }
}
     

```

<br/>

***
<br/>


> 3. AFURLSessionManager与NSURLSession的关系，每次都需要新建mananger吗？


&emsp;	manager与session是1对1的关系，AF会在manager初始化的时候创建对应的NSURLSession。同样，AF也在注释中写明了可以提供一个配置好的manager单例来全局复用。

&emsp;	复用manager实际上就是复用了session，而复用session可以带来什么好处呢？

&emsp;	其实iOS9之后，session就开始支持http2.0。而http2.0的一个特点就是多路复用（可参考《Http系列(二) Http2中的多路复用》）。所以这里复用session其实就是在利用`http2.0的多路复用(考点：为什么要尽量共享Session，而不是每次新建Session)`特点，减少访问同一个服务器时，重新建立tcp连接的耗时和资源。

&emsp;	官方文档也推荐在不同的功能场景下，使用不同的session。比如：一个session处理普通的请求，一个session处理background请求；1个session处理浏览器公开的请求，一个session专门处理隐私请求等等场景。

-	TCP 3次握手：
![a29](https://raw.githubusercontent.com/harleyGit/StudyNotes/master/Pictures/a29.png)


-	TCP 4次挥手：
![a30](https://raw.githubusercontent.com/harleyGit/StudyNotes/master/Pictures/a30.png)


<br/>

***
<br/>


> 4. 安全链接之AFSecurityPolicy

[AFNetWorking源码之AFSecurityPolicy](https://segmentfault.com/a/1190000009199444)



















