//
//  Reachability.swift
//  SwiftHub
//
//  Created by Khoren Markosyan on 1/4/17.
//  Copyright © 2017 Khoren Markosyan. All rights reserved.
//

import Foundation
import RxSwift
import Alamofire

// An observable that completes when the app gets online (possibly completes immediately).
func connectedToInternet() -> Observable<Bool> {
    return ReachabilityManager.shared.reach
}

private class ReachabilityManager: NSObject {
    
    static let shared = ReachabilityManager()
    
    //ReplaySubject: https://www.hangge.com/blog/cache/detail_1929.html
    let reachSubject = ReplaySubject<Bool>.create(bufferSize: 1)
    var reach: Observable<Bool> {
        return reachSubject.asObservable()
    }
    
    override init() {
        super.init()
        
        //监听网络链接状态
        NetworkReachabilityManager.default?.startListening(onUpdatePerforming: { (status) in
            switch status {
            case .notReachable:// 不可用
                self.reachSubject.onNext(false)
            case .reachable:// 可用（关联了网络连接类型）
                self.reachSubject.onNext(true)
            case .unknown:// 未知状态
                self.reachSubject.onNext(false)
            }
        })
    }
}
