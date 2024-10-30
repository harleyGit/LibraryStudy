//
//  ViewController.swift
//  RxSwiftCode
//
//  Created by Harley Huang on 27/3/2023.
//

import UIKit
import RxSwift
import RxCocoa

enum RxTestModule: String {
    case trianbleModule = "三角形绘制模块"
    case textureModule00 = "纹理01-图片叠加"
    case pyramidModule00 = "角锥体"
    case drawLine = "绘制曲线"
    case filter = "滤镜"
    case cameraFilter = "相机滤镜"
}

class ViewController: UIViewController {
    
    fileprivate let items: [RxTestModule] = [
        .trianbleModule,
        .textureModule00,
        .pyramidModule00,
        .drawLine,
        .filter,
        .cameraFilter
    ]
    
    lazy fileprivate var listView: UITableView = {
        let m = UITableView.init(frame: view.bounds, style: .grouped)
        m.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        m.delegate = self
        m.dataSource = self
        return m
    }()
    
    lazy fileprivate var triangleBtn: UIButton = {
        let triangleBtn = UIButton(type: .system)
        triangleBtn.setTitle("三角形绘制", for: .normal)
        triangleBtn.backgroundColor = .systemBlue
        triangleBtn.setTitleColor(.white, for: .normal)
        //triangleBtn.addTarget(self, action: #selector(triangleTapped), for: .touchUpInside)
        return triangleBtn
    }()
    
    lazy fileprivate var circleBtn: UIButton = {
        let circleBtn = UIButton(type: .system)
        circleBtn.setTitle("圆形绘制", for: .normal)
        circleBtn.backgroundColor = .systemRed
        circleBtn.setTitleColor(.white, for: .normal)
        //circleBtn.addTarget(self, action: #selector(circleTapped), for: .touchUpInside)
        return circleBtn
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = UIColor.lightGray
        view.addSubview(listView)
        // self.setupContentSubViews()
    }
    
    func setupContentSubViews() {
        self.triangleBtn.frame = CGRect(x: 100, y: 100, width: 100, height: 60)
        self.view.addSubview(self.triangleBtn)
        
        self.circleBtn.frame = CGRect(x: 100, y: self.triangleBtn.frame.maxY + 20, width: 100, height: 60)
        self.view.addSubview(self.circleBtn)
    }
}

// MARK: - <UITableViewDataSource>
extension ViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let item = items[indexPath.item]
        cell.textLabel?.text = item.rawValue
        return cell
    }
}

//MARK: - <UITableViewDelegate>
extension ViewController {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let moduleName: RxTestModule = self.items[indexPath.row]
        switch moduleName {
        default: break
        }
    }
}


//MARK: - WKNavigationAction
extension ViewController {
    
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








