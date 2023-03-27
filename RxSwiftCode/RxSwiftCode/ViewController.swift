//
//  ViewController.swift
//  RxSwiftCode
//
//  Created by Harley Huang on 27/3/2023.
//

import UIKit

class ViewController: UIViewController {
    
    lazy var btn: UIButton = {
        let btn = UIButton.init(frame: CGRect.init(x: 100, y: 200, width: 200, height: 120))
        btn.setTitle("跳转",for: UIControl.State.normal)
        btn.backgroundColor = .red
        //btn.addTarget(self, action:#selector(tapped(:)), for:.touchUpInside)
        btn.addTarget(self, action: #selector(tapped), for: UIControl.Event.touchUpInside)
       // btn.addTarget(self, action: #selector(tapped(:)), for: .touchUpInside)
        return btn
    }()
    
    


    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
    
    
    @objc func tapped(sender: UIButton)  {
//        let disposeBag = DisposeBag()
//        let subject = AsyncSubject<String>()
//
//        subject.subscribe{
//            print("subscription: 1 Event:", $0)
//        }.disposed(by: disposeBag)
//
//        subject.onNext("🐩")
//        subject.onNext("🐶")
//        subject.onNext("🐱")
//        subject.onNext("🥜")
//        subject.onCompleted()
    }


}

