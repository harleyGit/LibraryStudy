//
//  TestObserverController.swift
//  RxSwiftCode
//
//  Created by GangHuang on 10/30/24.
//

import UIKit
import RxSwift


class TestObserverController: UIViewController {

    let usernameOutlet = UITextField(frame: .zero)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let usserNameValid = usernameOutlet.rx.text.orEmpty.map { name in
           name.count >= 20
        }.share(replay: 1)
    }
}

extension TestObserverController {
    
}
