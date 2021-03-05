//
//  AuthManager.swift
//  SwiftHub
//
//  Created by Sygnoos9 on 9/1/18.
//  Copyright © 2018 Khoren Markosyan. All rights reserved.
//

import Foundation
import KeychainAccess
import ObjectMapper
import RxSwift
import RxCocoa

//BehaviorRelay：https://beeth0ven.github.io/RxSwift-Chinese-Documentation/content/recipes/rxrelay.html
//BehaviorRelay 就是 BehaviorSubject 去掉终止事件 onError 或 onCompleted
let loggedIn = BehaviorRelay<Bool>(value: false)
/*
 *授权管理
 */
class AuthManager {

    /// The default singleton instance.
    static let shared = AuthManager()

    // MARK: - Properties
    fileprivate let tokenKey = "TokenKey"
    //keychain详解：https://www.cnblogs.com/junhuawang/p/8194484.html
    fileprivate let keychain = Keychain(service: Configs.App.bundleIdentifier)

    let tokenChanged = PublishSubject<Token?>()

    init() {
        loggedIn.accept(hasValidToken)
    }

    var token: Token? {
        get {
            guard let jsonString = keychain[tokenKey] else { return nil }
            return Mapper<Token>().map(JSONString: jsonString)
        }
        set {
            if let token = newValue, let jsonString = token.toJSONString() {
                keychain[tokenKey] = jsonString
            } else {
                keychain[tokenKey] = nil
            }
            tokenChanged.onNext(newValue)
            loggedIn.accept(hasValidToken)
        }
    }

    var hasValidToken: Bool {
        return token?.isValid == true
    }

    class func setToken(token: Token) {
        AuthManager.shared.token = token
    }

    class func removeToken() {
        AuthManager.shared.token = nil
    }

    class func tokenValidated() {
        AuthManager.shared.token?.isValid = true
    }
}
