//
//  BaseViewModel.swift
//  SwiftTest
//
//  Created by Harley Huang on 29/1/2021.
//

import Foundation
import RxSwift
import RxCocoa

class BaseViewModel: NSObject {
    
    struct Input {
        let modules: Observable<Void>
    }
    
    struct Output {
        //Driver：https://www.hangge.com/blog/cache/detail_1942.html
        let titles: Driver<[String]>
        let values: Driver<[String]>
    }
    
    
    
    
    func transform(input: Input) -> Output {
        
        let titles = Observable.just(true).map { (status) -> [String] in
            if status {
                return ["首页", "新闻", "资产", "设置"]
            }else {
                return ["1", "2", "3"]
            }
        }.asDriver(onErrorJustReturn: [])
        
        
        
        let values = input.modules.take(1).map{ _ -> [String] in
            
            return ["one", "two","there","four"]
            
        }.asDriver(onErrorJustReturn: [])
        
        return Output(titles: titles, values: values)
    }
    
    
}

class ViewModel2 {
    struct Input {
        let whatsNewTrigger: Observable<Bool>
    }
    
    struct Output {
        let tabBarItems: Driver<[String]>
        let openWhatsNews: Driver<String>
    }
    
    func transform(input: Input) -> Output {
        let tabBarItems = input.whatsNewTrigger.map { (authorized) -> [String] in
            if authorized {
                return ["首页", "新闻", "资产", "我的"]
            }else {
                return ["首页", "新闻", "我的"]
            }
        //1. 通过返回值生成一个数组的observable的序列
        //2. .asDriver(onErrorJustReturn: []) 方法将任何 Observable 序列都转成 Driver
        //3. 转化为Driver数组序列
        }.asDriver(onErrorJustReturn: [])
        
        //take: https://www.hangge.com/blog/cache/detail_1933.html
        let openWhatsNews = Observable.of("头条新闻📰", "GitHub").take(1).asDriver(onErrorJustReturn: "Error")
        
        return Output.init(tabBarItems: tabBarItems, openWhatsNews: openWhatsNews)
    }
}



//RxSwfit Extensions
extension ObservableType {
    
    func mapToVoid() -> Observable<Void> {
        return map { _ in }
    }
}
