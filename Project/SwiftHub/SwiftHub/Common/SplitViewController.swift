//
//  SplitViewController.swift
//  CakeBuilderBakery
//
//  Created by Khoren Markosyan on 3/13/17.
//  Copyright © 2017 GAVR. All rights reserved.
//

import UIKit


//双区域列表：https://juejin.cn/post/6844903945232449543
class SplitViewController: UISplitViewController {

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return globalStatusBarStyle.value
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        delegate = self
        preferredDisplayMode = .allVisible

        globalStatusBarStyle.mapToVoid().subscribe(onNext: { [weak self] () in
            //视图控制器状态属性改变
            self?.setNeedsStatusBarAppearanceUpdate()
        }).disposed(by: rx.disposeBag)
    }
}

extension SplitViewController: UISplitViewControllerDelegate {

    func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController: UIViewController, onto primaryViewController: UIViewController) -> Bool {
        return true
    }
}
