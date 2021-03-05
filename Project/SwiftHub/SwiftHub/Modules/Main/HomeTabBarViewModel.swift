//
//  HomeTabBarViewModel.swift
//  SwiftHub
//
//  Created by Khoren Markosyan on 7/11/18.
//  Copyright © 2018 Khoren Markosyan. All rights reserved.
//

import Foundation
import RxCocoa
import RxSwift
import WhatsNewKit

class HomeTabBarViewModel: ViewModel, ViewModelType {

    struct Input {
        let whatsNewTrigger: Observable<Void>
    }

    struct Output {
        //Driver：https://www.hangge.com/blog/cache/detail_1942.html
        let tabBarItems: Driver<[HomeTabBarItem]>   //包含底部功能按钮模块
        let openWhatsNew: Driver<WhatsNewBlock> //更新功能模块
    }

    let authorized: Bool
    //WhatsNewKit：应用程序更新后显示“新功能”信息的macOS对话框
    let whatsNewManager: WhatsNewManager

    init(authorized: Bool, provider: SwiftHubAPI) {
        self.authorized = authorized
        whatsNewManager = WhatsNewManager.shared
        super.init(provider: provider)
    }

    func transform(input: Input) -> Output {

        //just： https://juejin.cn/post/6844903893059502094
        //map: 观察序列转换成一种新的格式
        let tabBarItems = Observable.just(authorized).map { (authorized) -> [HomeTabBarItem] in
            if authorized {
                return [.news, .search, .notifications, .settings]
            } else {
                return [.search, .login, .settings]
            }
        //1. 通过返回值生成一个数组的observable的序列
        //2. .asDriver(onErrorJustReturn: []) 方法将任何 Observable 序列都转成 Driver
        //3. 转化为Driver数组序列
        }.asDriver(onErrorJustReturn: [])

        //版本新功能展示
        let whatsNew = whatsNewManager.whatsNew()
        //take: https://www.hangge.com/blog/cache/detail_1933.html
        let whatsNewItems = input.whatsNewTrigger.take(1).map { _ in
            whatsNew
            
        }

        return Output(tabBarItems: tabBarItems,
                      openWhatsNew: whatsNewItems.asDriverOnErrorJustComplete())
    }

    func viewModel(for tabBarItem: HomeTabBarItem) -> ViewModel {
        switch tabBarItem {
        case .search:
            let viewModel = SearchViewModel(provider: provider)
            return viewModel
        case .news:
            let user = User.currentUser()!
            let viewModel = EventsViewModel(mode: .user(user: user), provider: provider)
            return viewModel
        case .notifications:
            let viewModel = NotificationsViewModel(mode: .mine, provider: provider)
            return viewModel
        case .settings:
            let viewModel = SettingsViewModel(provider: provider)
            return viewModel
        case .login:
            let viewModel = LoginViewModel(provider: provider)
            return viewModel
        }
    }
}
