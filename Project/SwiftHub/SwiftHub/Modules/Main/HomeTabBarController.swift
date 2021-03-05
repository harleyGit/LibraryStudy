//
//  HomeTabBarController.swift
//  SwiftHub
//
//  Created by Khoren Markosyan on 1/5/18.
//  Copyright © 2018 Khoren Markosyan. All rights reserved.
//

import UIKit
import RAMAnimatedTabBarController
import Localize_Swift
import RxSwift

enum HomeTabBarItem: Int {
    case search, news, notifications, settings, login

    private func controller(with viewModel: ViewModel, navigator: Navigator) -> UIViewController {
        switch self {
        case .search:
            let vc = SearchViewController(viewModel: viewModel, navigator: navigator)
            return NavigationController(rootViewController: vc)
        case .news:
            let vc = EventsViewController(viewModel: viewModel, navigator: navigator)
            return NavigationController(rootViewController: vc)
        case .notifications:
            let vc = NotificationsViewController(viewModel: viewModel, navigator: navigator)
            return NavigationController(rootViewController: vc)
        case .settings:
            let vc = SettingsViewController(viewModel: viewModel, navigator: navigator)
            return NavigationController(rootViewController: vc)
        case .login:
            let vc = LoginViewController(viewModel: viewModel, navigator: navigator)
            return NavigationController(rootViewController: vc)
        }
    }

    var image: UIImage? {
        switch self {
        case .search: return R.image.icon_tabbar_search()
        case .news: return R.image.icon_tabbar_news()
        case .notifications: return R.image.icon_tabbar_activity()
        case .settings: return R.image.icon_tabbar_settings()
        case .login: return R.image.icon_tabbar_login()
        }
    }

    var title: String {
        switch self {
        case .search: return R.string.localizable.homeTabBarSearchTitle.key.localized()
        case .news: return R.string.localizable.homeTabBarEventsTitle.key.localized()
        case .notifications: return R.string.localizable.homeTabBarNotificationsTitle.key.localized()
        case .settings: return R.string.localizable.homeTabBarSettingsTitle.key.localized()
        case .login: return R.string.localizable.homeTabBarLoginTitle.key.localized()
        }
    }

    var animation: RAMItemAnimation {
        var animation: RAMItemAnimation
        switch self {
        case .search: animation = RAMFlipLeftTransitionItemAnimations()
        case .news: animation = RAMBounceAnimation()
        case .notifications: animation = RAMBounceAnimation()
        case .settings: animation = RAMRightRotationAnimation()
        case .login: animation = RAMBounceAnimation()
        }
        _ = themeService.rx
            .bind({ $0.secondary }, to: animation.rx.iconSelectedColor)
            .bind({ $0.secondary }, to: animation.rx.textSelectedColor)
        return animation
    }

    func getController(with viewModel: ViewModel, navigator: Navigator) -> UIViewController {
        //获取视图控制器
        let vc = controller(with: viewModel, navigator: navigator)
        //添加标题
        let item = RAMAnimatedTabBarItem(title: title, image: image, tag: rawValue)
        //动画选择，选择这其中的一个RAMFumeAnimation, RAMBounceAnimation, RAMRotationAnimation, RAMFrameItemAnimation, RAMTransitionAnimation
        // 你也可以为你的每一个item加载不同的动画，可以根据自己需求添加
        item.animation = animation
        _ = themeService.rx
            .bind({ $0.text }, to: item.rx.iconColor)
            .bind({ $0.text }, to: item.rx.textColor)
        vc.tabBarItem = item
        return vc
    }
}

//HomeTabBarController: https://www.jianshu.com/p/e5649029ea5f
class HomeTabBarController: RAMAnimatedTabBarController, Navigatable {

    var viewModel: HomeTabBarViewModel?
    var navigator: Navigator!

    init(viewModel: ViewModel?, navigator: Navigator) {
        self.viewModel = viewModel as? HomeTabBarViewModel
        self.navigator = navigator
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        makeUI()
        bindViewModel()
    }

    func makeUI() {
        //LCLLanguageChangeNotification国际化和本地化框架：https://www.oschina.net/p/localize-swift
        NotificationCenter.default
            .rx.notification(NSNotification.Name(LCLLanguageChangeNotification))
            .subscribe { [weak self] (event) in
                //RAMAnimatedTabBarController ： https://www.jianshu.com/p/e5649029ea5f
                self?.animatedItems.forEach({ (item) in
                    item.title = HomeTabBarItem(rawValue: item.tag)?.title
                })
                self?.setViewControllers(self?.viewControllers, animated: false)
                self?.setSelectIndex(from: 0, to: self?.selectedIndex ?? 0)
            }.disposed(by: rx.disposeBag)

        //rx：开始链接绑定：https://iweiyun.github.io/2018/11/01/rxcocoa-code/
        //bind：to：绑定主题属性到UI属性
        themeService.rx
            .bind({ $0.primaryDark }, to: tabBar.rx.barTintColor)
            .disposed(by: rx.disposeBag)

        themeService.typeStream.delay(DispatchTimeInterval.milliseconds(100), scheduler: MainScheduler.instance)
            .subscribe(onNext: { (theme) in
                switch theme {
                case .light(let color), .dark(let color):
                    self.changeSelectedColor(color.color, iconSelectedColor: color.color)
                }
            }).disposed(by: rx.disposeBag)
    }

    func bindViewModel() {
        guard let viewModel = viewModel else { return }

        let input = HomeTabBarViewModel.Input(whatsNewTrigger: rx.viewDidAppear.mapToVoid())
        let output = viewModel.transform(input: input)

        output.tabBarItems.delay(.milliseconds(50)).drive(onNext: { [weak self] (tabBarItems) in
            if let strongSelf = self {
                //根据viewModel获取对应的视图控制器
                let controllers = tabBarItems.map { $0.getController(with: viewModel.viewModel(for: $0), navigator: strongSelf.navigator) }
                //设置tabBar的根视图控制器
                strongSelf.setViewControllers(controllers, animated: false)
            }
        }).disposed(by: rx.disposeBag)

        output.openWhatsNew.drive(onNext: { [weak self] (block) in
            if Configs.Network.useStaging == false {
                self?.navigator.show(segue: .whatsNew(block: block), sender: self, transition: .modal)
            }
        }).disposed(by: rx.disposeBag)
    }
}
