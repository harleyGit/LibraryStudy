//
//  ViewController.swift
//  RxSwiftCode
//
//  Created by Harley Huang on 27/3/2023.
//

import UIKit
import RxSwift
import RxCocoa

class ViewController: UIViewController {
    
    lazy var btn: UIButton = {
        let btn = UIButton.init(frame: CGRect.init(x: 100, y: 200, width: 200, height: 120))
        btn.setTitle("跳转",for: UIControl.State.normal)
        btn.backgroundColor = .red
        //btn.addTarget(self, action:#selector(tapped(:)), for:.touchUpInside)
        btn.addTarget(self, action: #selector(tappedObservable(sender:)), for: UIControl.Event.touchUpInside)
        // btn.addTarget(self, action: #selector(tapped(:)), for: .touchUpInside)
        return btn
    }()
    
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.addSubview(self.btn)
    }
    
    @objc func tappedObservable(sender: UIButton) {
        // 1: 创建序列
        _ = Observable<String>.create { (obserber) -> Disposable in
            // 3:发送信号 // AnyObserver的父类ObserverType的onNext方法
            obserber.onNext("Cooci -  框架班级")
            return Disposables.create()  // 这个销毁不影响我们这次的解读
            // 2: 订阅序列
        }.subscribe(onNext: { (text) in
            print("订阅到:\(text)")
        })
        
    }
    
    
    @objc func tapped(sender: UIButton)  {
        let disposeBag = DisposeBag()
        let subject = AsyncSubject<String>()
        
        subject.subscribe{
            print("subscription: 1 Event:", $0)
        }.disposed(by: disposeBag)
        
        subject.onNext("🐩")
        subject.onNext("🐶")
        subject.onNext("🐱")
        subject.onNext("🥜")
        subject.onCompleted()
    }
    
    
}

