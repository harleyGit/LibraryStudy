//
//  NavigationController.swift
//  SwiftHub
//
//  Created by Khoren Markosyan on 1/4/17.
//  Copyright © 2017 Khoren Markosyan. All rights reserved.
//

import UIKit

class NavigationController: UINavigationController {

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return globalStatusBarStyle.value
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        interactivePopGestureRecognizer?.delegate = nil // Enable default iOS back swipe gesture

        //开启转场动画，建议在present或push前调用
        if #available(iOS 13.0, *) {
            hero.isEnabled = false
        } else {
            hero.isEnabled = true
        }
        //模态视图呈现和消失动画
        hero.modalAnimationType = .autoReverse(presenting: .fade)
        //导航控制器push和pop动画效果
        hero.navigationAnimationType = .autoReverse(presenting: .slide(direction: .left))

        //导航控制栏是否半透明
        navigationBar.isTranslucent = false
        navigationBar.backIndicatorImage = R.image.icon_navigation_back()
        navigationBar.backIndicatorTransitionMaskImage = R.image.icon_navigation_back()

        themeService.rx
            .bind({ $0.secondary }, to: navigationBar.rx.tintColor)
            .bind({ $0.primaryDark }, to: navigationBar.rx.barTintColor)
            .bind({ [NSAttributedString.Key.foregroundColor: $0.text] }, to: navigationBar.rx.titleTextAttributes)
            .disposed(by: rx.disposeBag)
    }
}
