//
//  ViewController.swift
//  RxSwiftCode
//
//  Created by Harley Huang on 8/30/21.
//

import UIKit
import RxSwift
import RxCocoa
//https://www.jianshu.com/p/543c35ebc4b5

class ViewController: UIViewController {
    
    let disposeBag = DisposeBag()
    
    lazy var btnTest: UIButton = {()-> UIButton in
        let btn = UIButton.init(type: .custom)
        btn.setTitle("测试Button", for: .normal)
        btn.frame = CGRect.init(x: 100, y: 240, width: 200, height: 160)
        btn.addTarget(self, action: #selector(_methodTest0), for: .touchUpInside)
        btn.backgroundColor = .cyan
        
        return btn
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.addSubview(self.btnTest)
        
        
        
        self.btnTest.rx.tap.subscribe(onNext: { [weak self] in
            print("点了,小鸡炖蘑菇")
            self?.view.backgroundColor = UIColor.systemBackground
        })
        .disposed(by: disposeBag)
    }
    
    
    @objc func _methodTest0() {
        
    }
    
}

