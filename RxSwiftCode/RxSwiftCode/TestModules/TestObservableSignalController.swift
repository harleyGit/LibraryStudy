//
//  TestObservableSignalController.swift
//  RxSwiftCode
//
//  Created by GangHuang on 10/30/24.
//

import UIKit
import RxSwift
import RxCocoa

class TestObservableSignalController: UIViewController {
    
    let textField: UITextField = {
        let tf = UITextField()
        tf.borderStyle = .roundedRect
        tf.placeholder = "输入姓名"
        return tf
    }()
    let nameLabel: UILabel = {
        let label = UILabel()
        label.text = "姓名: "
        label.font = UIFont.systemFont(ofSize: 16)
        return label
    }()
    let nameSizeLabel: UILabel = {
        let label = UILabel()
        label.text = "姓名长度: 0"
        label.font = UIFont.systemFont(ofSize: 16)
        return label
    }()
    
    
    let disposeBag = DisposeBag() // 管理订阅的销毁
    let button: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("点击我", for: .normal)
        return btn
    }()
    // 将按钮点击事件转换为 Driver
    lazy var buttonEvent: Driver<Void> = button.rx.tap.asDriver()
    
    let signalbutton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("点击我-signal", for: .normal)
        return btn
    }()
    lazy var signalButtonEvent: Signal<Void> = signalbutton.rx.tap.asSignal()
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        
        self.bindToUI()
        
        self.bindToBtn()
        
        self.bindSignalBtn()
        
        setupFrames()
    }
    
    func bindToUI() {
        let state: Driver<String?> = textField.rx.text.asDriver()
        
        let observer = nameLabel.rx.text
        state.drive(observer)
        
        
        // ... 假设以下代码是在用户输入姓名后运行
        
        let newObserver = nameSizeLabel.rx.text
        state.map { $0?.count.description }.drive(newObserver)
    }
    
    func bindToBtn() {
        // 第一个观察者
        let observer: () -> Void = { [weak self] in
            self?.showAlert("弹出提示框1")
        }
        self.buttonEvent.drive(onNext: observer)
            .disposed(by: disposeBag) // 确保订阅的管理
    }
    
    func bindSignalBtn() {
        let observer: () -> Void = {  [weak self] in
            self?.showAlert00("🍎弹出提示框1")
        }
        self.signalButtonEvent.emit(onNext: observer)
    }
    
    // 设置视图的 frame
    func setupFrames() {
        // 添加子视图
        view.addSubview(textField)
        view.addSubview(nameLabel)
        view.addSubview(nameSizeLabel)
        self.view.addSubview(self.button)
        self.view.addSubview(signalbutton)
        
        // 设置 textField 的 frame
        textField.frame = CGRect(x: 20, y: 100, width: view.frame.width - 40, height: 40)
        // 设置 nameLabel 的 frame
        nameLabel.frame = CGRect(x: 20, y: 150, width: 200, height: 30)
        // 设置 nameSizeLabel 的 frame
        nameSizeLabel.frame = CGRect(x: 20, y: 190, width: view.frame.width - 40, height: 30)
        
        self.button.frame = CGRectMake(20, self.nameSizeLabel.frame.maxY+40, 60, 44)
        
        self.signalbutton.frame = CGRect(x: 20, y: button.frame.maxY+40, width: 60, height: 44)
    }
    
    // 弹出提示框
    func showAlert(_ message: String) {
        let alert = UIAlertController(title: "提示", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
        
        /*
         当用户点击一个按钮后，我们创建一个新的观察者，来响应点击事件。此时会发生什么？Driver 会把上一次的点击事件回放给新观察者。所以，这里的 newObserver 在订阅时，就会接受到上次的点击事件，然后弹出提示框。这似乎不太合理。
         */
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // 假设在用户点击 button 后运行
            let newObserver: () -> Void = { [weak self] in
                self?.showAlert("弹出提示框2")
            }
            self.buttonEvent.drive(onNext: newObserver)
                .disposed(by: self.disposeBag) // 确保订阅的管理
        }
    }
    
    // 弹出提示框
    func showAlert00(_ message: String) {
        let alert = UIAlertController(title: "提示", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
        
        /*
         在同样的场景中，Signal 不会把上一次的点击事件回放给新观察者，而只会将订阅后产生的点击事件，发布给新观察者。这正是我们所需要的。
         */
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // ... 假设以下代码是在用户点击 button 后运行
            
            let newObserver: () -> Void = {
                let newObserver: () -> Void = { [weak self] in
                    self?.showAlert00("signal0-0--弹出提示框2")
                }
                self.signalButtonEvent.emit(onNext: newObserver)
            }
        }
    }
}
