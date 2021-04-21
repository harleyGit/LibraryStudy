//
//  ZYRequestRealm.h
//  RetryNetwork
//
//  Created by 王志盼 on 2017/12/26.
//  Copyright © 2017年 王志盼. All rights reserved.
//
//  需要注意的是，这里的实现都是放在子线程中实现的，所以，当在主线程调用这些方法的时候，如果不按照正确的做法会崩溃，请仔细阅读
//  realm中关于在同一线程读写的文档。
//  这边，我是借助ZYRequestCache来调用这些接口的，具体也可以看那里面的实现,仿照写，确保是在同一线程读写即可
//  在主线程调用接口存储数据a进入realm数据库，好的做法是copy一份数据a，不然你在主线程中再次使用数据a的时候，会造成线程错误
//  的崩溃
//  在主线程查询出来的数据，只能在主线程中使用realm去删除，如果想要在子线程中修改，那么请在子线程中查询，关于删除的正确调用
//  在ZYRequestCache有正确的实现，主要目的，还是避免在不同线程让realm数据库操作同一份数据

//  如果一定要在主线程调用，那么可以将ZYRequestRealm.m文件中的serialQueue属性改为主队列，就不会发生上面的错误了，但是如果在其他线程操作了没有进行copy的数据，会造成崩溃
#import <Foundation/Foundation.h>
#import <Realm/Realm.h>

@interface ZYRequestRealm : NSObject
+ (instancetype)sharedInstance;

//添加or更新对象
/**
 不能在其他线程改变、读取它正在存储的对象，在存取数据的时候，建议copy它再去存入数据库
 */
- (void)addOrUpdateObj:(RLMObject *)obj;
- (void)addorUpdateObjArray:(NSArray<RLMObject *> *)objArr;

//删除对象
/**
 需要注意的是，所有的添加、删除操作，我都是放在子线程中a的
 那么按照realm文档，如果要删除一个查询出来的对象，该对象也必须在子线程a中被查询出来
 */
- (void)deleteobjsWithBlock:(void(^)(void))block;


- (void)deleteObj:(RLMObject *)obj;

- (void)deleteObjArray:(NSArray<RLMObject *> *)objArr;

//删除RLMResults对象
- (void)deleteResultsObj:(RLMResults *)results;

//查询所有数据
- (NSArray<RLMObject *> *)queryAllObjsForClass:(Class)cls;

@end
