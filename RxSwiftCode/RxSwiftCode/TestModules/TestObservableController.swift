//
//  TestObservableController.swift
//  RxSwiftCode
//
//  Created by GangHuang on 10/30/24.
//

import UIKit
import RxSwift

class TestObservableController: UIViewController {
    
    // 管理订阅的销毁
    let disposeBag = DisposeBag()
    
    fileprivate lazy var observableBtn00: UIButton = createBtn(title: "Observable观察者",
                                                               action: #selector(tappedObservable(_:)))
    fileprivate lazy var observableBtn01: UIButton = createBtn(title: "按钮Observable观察者")
    fileprivate lazy var bindPictureBtn02: UIButton = createBtn(title: "图片绑定",
                                                                action: #selector(bindPictureDataAction(_:)))
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .systemBackground
        
        self.setupContentSubViews()
        self.subscribeEvent()
    }
}

//MARK: - UI
extension TestObservableController {
    
    private func setupContentSubViews() {
        self.view.addSubview(self.observableBtn00)
        self.view.addSubview(self.bindPictureBtn02)
        
        self.view.addSubview(self.observableBtn01)
        
        
        self.observableBtn00.frame = CGRect(x: 16, y: 100, width: 100, height: 60)
        self.bindPictureBtn02.frame = CGRect(x: self.observableBtn00.frame.maxX+6, y: 100, width: 100, height: 60)
        
        self.observableBtn01.frame = CGRect(x: 16, y: self.observableBtn00.frame.maxY + 10, width: 100, height: 60)
    }
    
    fileprivate func createBtn(title: String, action: Selector? = nil) -> UIButton {
        let observableBtn00 = UIButton(type: .system)
        observableBtn00.setTitle(title, for: .normal)
        observableBtn00.backgroundColor = .systemBlue
        observableBtn00.setTitleColor(.white, for: .normal)
        // 设置标题属性
        observableBtn00.titleLabel?.numberOfLines = 0 // 允许换行
        observableBtn00.titleLabel?.lineBreakMode = .byWordWrapping // 单词换行
        // 设置按钮的样式和对齐
        observableBtn00.contentHorizontalAlignment = .center // 可根据需求调整对齐方式
        observableBtn00.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        if let newAction = action {
            observableBtn00.addTarget(self, action: newAction, for: .touchUpInside)
        }
        
        return observableBtn00
    }
}

//MARK: - 订阅事件
extension TestObservableController {
    
    private func subscribeEvent() {
        self.observableBtn01SubscribeEvent()
    }
    
    private func observableBtn01SubscribeEvent() {
        // 按钮点击序列
        let observableBtn01Taps: Observable<Void> = self.observableBtn01.rx.tap.asObservable()
        // 每次点击后弹出提示框
        observableBtn01Taps.subscribe(onNext: { [weak self] in
            self?.showAlert()
        })// 确保订阅在视图控制器释放时自动销毁
        .disposed(by: disposeBag)
    }
}

//MARK: - Action
extension TestObservableController {
    
    @objc fileprivate func tappedObservable(_ sender: UIButton) {
        // 1: 创建序列
        _ = Observable<String>.create { (obserber) -> Disposable in
            // 3:发送信号 // AnyObserver的父类ObserverType的onNext方法
            obserber.onNext("Cooci -  框架班级")
            return Disposables.create()  // 这个销毁不影响我们这次的解读
            // 2: 订阅序列
        }.subscribe(onNext: { (text) in//subscribe方法来到ObservableType+Extensions.swift里的subscribe方法中
            print("订阅到:\(text)")
        })
    }
    
    @objc fileprivate func bindPictureDataAction(_ sender: UIButton) {
        let imageView = UIImageView(frame: CGRect(x: self.view.frame.width - 160, y: 100, width: 160, height: 200))
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(imageView)
        
        // 创建一个 Observable，生成随机图片
        let image: Observable<UIImage> = Observable<Int>.interval(.seconds(1), scheduler: MainScheduler.instance)
            .map { _ in
                return self.randomImage() // 生成随机图片
            }
        
        // 将 Observable 绑定到 imageView
        image.bind(to: imageView.rx.image)
            .disposed(by: disposeBag) // 确保订阅的管理
    }
    
    // 弹出提示框
    private func showAlert() {
        let alert = UIAlertController(title: "提示", message: "按钮被点击！", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    // 生成随机图片
    private func randomImage() -> UIImage {
        let size = CGSize(width: 200, height: 200)
        UIGraphicsBeginImageContext(size)
        
        let context = UIGraphicsGetCurrentContext()
        
        // 生成随机颜色
        let randomColor = UIColor(
            red: CGFloat.random(in: 0...1),
            green: CGFloat.random(in: 0...1),
            blue: CGFloat.random(in: 0...1),
            alpha: 1.0
        )
        
        context?.setFillColor(randomColor.cgColor)
        context?.fill(CGRect(origin: .zero, size: size))
        
        let image = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()
        
        return image
    }
}

//MARK: -
extension TestObservableController {
    
    
}
