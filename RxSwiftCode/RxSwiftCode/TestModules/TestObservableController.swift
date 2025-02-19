//
//  TestObservableController.swift
//  RxSwiftCode
//
//  Created by GangHuang on 10/30/24.
//

import UIKit
import RxSwift

// 定义一个错误类型
enum FetchError: Error {
    case networkError
    case dataCorruption
}

class TestObservableController: UIViewController {
    
    // 管理订阅的销毁
    let disposeBag = DisposeBag()
    
    fileprivate lazy var observableBtn00: UIButton = createBtn(title: "Observable观察者",
                                                               action: #selector(tappedObservable(_:)))
    fileprivate lazy var bindPictureBtn02: UIButton = createBtn(title: "图片绑定",
                                                                action: #selector(bindPictureDataAction(_:)))
    fileprivate lazy var signalBtn00: UIButton = createBtn(title: "Signal的范型枚举处理",
                                                           action: #selector(signalAction00(_:)))
    fileprivate lazy var observableBtn01: UIButton = createBtn(title: "按钮Observable观察者")
    
    
    
    
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
        self.view.addSubview(self.signalBtn00)
        
        self.view.addSubview(self.observableBtn01)
        
        
        self.observableBtn00.frame = CGRect(x: 16, y: 100, width: 100, height: 60)
        self.bindPictureBtn02.frame = CGRect(x: self.observableBtn00.frame.maxX+6, y: 100, width: 100, height: 60)
        self.signalBtn00.frame = CGRect(x: self.bindPictureBtn02.frame.maxX+6, y: 100, width: 100, height: 60)
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
    
    
    // 模拟一个 fetchData 函数，它返回一个 Observable<Result<Data, FetchError>>
    // fetchData 方法返回 Observable<Result<Data, FetchError>>，表示一个异步的数据获取操作，可能成功返回 Data，也可能失败返回 FetchError
    func testFetchData() -> Observable<Result<Data, FetchError>> {
        return Observable.create { observer in
            // 模拟异步操作
            DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                let success = Bool.random()  // 随机成功或失败
                
                if success {
                    let data = Data("Fetched Data".utf8)  // 假设这是成功的数据
                    observer.onNext(Result.success(data)) // 使用 Result.success(Data)
                } else {
                    observer.onNext(Result.failure(FetchError.networkError)) // 使用 Result.failure(Error)
                }
                observer.onCompleted()
            }
            
            return Disposables.create()
        }
    }
}

//MARK: - Action
extension TestObservableController {
    
    @objc fileprivate func signalAction00(_ sender: UIButton) {
        self.testFetchData()
            .subscribe(onNext: { result in
                switch result {
                case .success(let data):
                    if let string = String(data: data, encoding: .utf8) {
                        print("成功接收到数据：\(string)")
                    }
                case .failure(let error):
                    print("发生错误：\(error)")
                }
            }, onError: { error in
                print("Observable 错误：\(error)")
            }, onCompleted: {
                print("数据获取操作完成")
            })
            .disposed(by: disposeBag)
    }
    
    @objc fileprivate func tappedObservable(_ sender: UIButton) {
        // 1: 创建序列
        let currentObserver = Observable<String>.create { (obserber) -> Disposable in   // ‼️断点1.1
            // 3:发送信号 // AnyObserver的父类ObserverType的onNext方法
            obserber.onNext("Cooci -  框架班级")    // ‼️断点1.2
            obserber.onCompleted()  // ‼️断点1.3
            
            return Disposables.create()  // 这个销毁不影响我们这次的解读  // ‼️断点1.4
        }
        
        // 2: 订阅序列
        currentObserver.subscribe(onNext: { (text) in//subscribe方法来到ObservableType+Extensions.swift里的subscribe方法中  // ‼️断点2.1
            print("订阅到:\(text)")    // ‼️断点2.2
        }, onError: nil, onCompleted: { // ‼️断点2.3
            print("Completed 完成！！") // ‼️断点2.4
        }, onDisposed: nil).disposed(by: disposeBag) // ‼️断点2.5
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
