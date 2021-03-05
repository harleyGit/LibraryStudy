//
//  Application.swift
//  SwiftHub
//
//  Created by Khoren Markosyan on 1/5/18.
//  Copyright © 2018 Khoren Markosyan. All rights reserved.
//

import UIKit

//final修饰符可以防止类（class）被继承，还可以防止子类重写父类的属性、方法以及下标。需要注意的是，final修饰符只能用于类，不能修饰结构体（struct）和枚举（enum），因为结构体和枚举只能遵循协议（protocol）。虽然协议也可以遵循其他协议，但是它并不能重写遵循的协议的任何成员，这就是结构体和枚举不需要final修饰的原因。
final class Application: NSObject {
    static let shared = Application()

    var window: UIWindow?

    var provider: SwiftHubAPI?
    let authManager: AuthManager
    let navigator: Navigator

    private override init() {
        authManager = AuthManager.shared
        navigator = Navigator.default
        super.init()
        updateProvider()
    }

    private func updateProvider() {
        let staging = Configs.Network.useStaging //判断是否为true， true值为测试
        let githubProvider = staging ? GithubNetworking.stubbingNetworking(): GithubNetworking.defaultNetworking()
        let trendingGithubProvider = staging ? TrendingGithubNetworking.stubbingNetworking(): TrendingGithubNetworking.defaultNetworking()
        let codetabsProvider = staging ? CodetabsNetworking.stubbingNetworking(): CodetabsNetworking.defaultNetworking()
        let restApi = RestApi(githubProvider: githubProvider, trendingGithubProvider: trendingGithubProvider, codetabsProvider: codetabsProvider)
        provider = restApi

        //正式环境网络请求配置
        if let token = authManager.token, Configs.Network.useStaging == false {
            switch token.type() {
            case .oAuth(let token), .personal(let token):
                provider = GraphApi(restApi: restApi, token: token)
            default: break
            }
        }
    }

    func presentInitialScreen(in window: UIWindow?) {
        updateProvider()
        guard let window = window, let provider = provider else { return }
        self.window = window

//        presentTestScreen(in: window)
//        return

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            //用户数据分析
            if let user = User.currentUser(), let login = user.login {
                analytics.identify(userId: login)
                analytics.set(.name(value: user.name ?? ""))
                analytics.set(.email(value: user.email ?? ""))
            }
            let authorized = self?.authManager.token?.isValid ?? false//是否被授权
            let viewModel = HomeTabBarViewModel(authorized: authorized, provider: provider)
            //设置根视图控制器
            self?.navigator.show(segue: .tabs(viewModel: viewModel), sender: nil, transition: .root(in: window))
        }
    }

    func presentTestScreen(in window: UIWindow?) {
        guard let window = window, let provider = provider else { return }
        let viewModel = UserViewModel(user: User(), provider: provider)
        navigator.show(segue: .userDetails(viewModel: viewModel), sender: nil, transition: .root(in: window))
    }
}
