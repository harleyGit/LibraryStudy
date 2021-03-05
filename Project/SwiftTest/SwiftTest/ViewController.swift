//
//  ViewController.swift
//  SwiftTest
//
//  Created by Harley Huang on 22/1/2021.
//6214832148367449

import UIKit
///RX_NO_MODULE这个宏的字面意思应该是没有rx的模块意思,但是没有找到具体实现在哪里,如果谁知道麻烦告知
#if !RX_NO_MODULE
import RxTheme
import RxSwift
import RxRelay
import RxCocoa
import RxViewController
#endif


class ViewController: UIViewController {
    let disposeBag = DisposeBag()
    
    //创建一个bufferSize为2的ReplaySubject
    let subject = ReplaySubject<String>.create(bufferSize: 1)
    
    
    
    lazy var btn: UIButton = {
        let view = UIButton.init(frame: CGRect.init(x: 100, y: 100, width: 150, height: 80))
        view.addTarget(self, action: #selector(clickAction), for: .touchUpInside)
        view.setTitle("主题颜色改变", for: .normal)
        //view.backgroundColor = UIColor.purple
        /**
         *这里把return和参数都省略了
         let multipyClosure = {
         (color: UIColor) in
         return color
         }
         */
        themeService.rx.bind({$0.secondary}, to: view.rx.backgroundColor).disposed(by: disposeBag)
        
        
        
        return view
        
    }()
    
    lazy var inputText: UITextField = {
        let view = UITextField.init(frame: CGRect.init(x: 100, y: 220, width: 200, height: 80))
        view.backgroundColor = UIColor.purple
        view.textColor = UIColor.white
        view.placeholder = "请输入。。。。。"
        
        return view
    }()
    
    
    var _token: String?
    
    var token: String? {
        get {
            guard let tokenStr = _token else {
                return nil
            }
            return tokenStr
        }
        
        set {
            if let token = newValue {
                _token = token + " Super"
            }else {
                _token = nil
            }
        }
    }
    
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return globalStatusBarStyle.value
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.addSubview(inputText)
        self.view.addSubview(btn)
        
        
        
        
        //rxTest1()
    }
    
    
    fileprivate func driveToAndShareReplayTest() {
        
        let textChange = inputText.rx.text.orEmpty.map { (text) -> String in
            print("<<<<<<<<<< \(text)")
            return "Good \(text)"
        }.share(replay: 1)
        
        //绑定到UIButton的title
        textChange.asDriver(onErrorJustReturn: "error").map { "\($0)" }.drive(btn.rx.title())// 这里改用 `drive` 而不是 `bindTo`，和bindTo作用是一样的
            .disposed(by: disposeBag)
        
        delay(10, closure: {
            textChange.subscribe(onNext: {(value) in
                print("============ \(value)")
            }).disposed(by: self.disposeBag)
        })
    }
    
    /// 延迟函数
    func delay(_ delay: Double, closure: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            closure()
        }
    }
    
    
    
    
    @objc func clickAction() {
        
        // 这样可以确保必备条件都已经满足了
        
        
        let _relay = BehaviorRelay(value: 0)
        //Driver是SharedSequence的别名，用来描述不同类型的序列，最后又调用了asDriver方法，而该方法在ObservableConvertibleType的扩展中，一直追踪会发现很多类都是继承自ObservableConvertibleType下
        var _loading: SharedSequence<DriverSharingStrategy, Bool>
        
        
        _loading = _relay.asDriver().map {
            print("<<<< \($0 > 0)")
            return $0 > 0
            
        }.distinctUntilChanged()
        
        
        
        _relay.accept(3)
        
        
    }
    
    
    //范型类型String和Void
    func argumentStr_Void() {
        let languageChanged = BehaviorRelay<Void>(value: ())
        languageChanged.subscribe(onNext: { () in
            print("语言改变。。。。。。")
        }).disposed(by: disposeBag)
        
        languageChanged.accept(())
        
        print("-----------------------")
        
        let languageChanged2 = BehaviorRelay<String>(value: "0000")
        languageChanged2.subscribe(onNext: {(language) in
            print("语言是\(language)")
        }).disposed(by: disposeBag)
        
        languageChanged2.accept("汉语")
    }
    
    
    //BehaviorRelay、状态绑定
    func behaviorReplayTest() {
        
        
        //        let subject = BehaviorRelay<String>(value: "1111")
        //        subject.accept("2222")
        //
        //        subject.asObservable().subscribe({
        //            print("值为： \($0)")
        //        }).disposed(by: disposeBag)
        //
        //        subject.accept("3333")
        //        print("\(subject.value)")
        
        let error = PublishSubject<Bool>()
        let isLoading = BehaviorRelay(value: false)
        
        error.asObservable().bind(to: isLoading).disposed(by: disposeBag)
        
        isLoading.subscribe(onNext: { isLoading in
            print("\(isLoading ? "加载中。。。。" : "停止加载")")
        }).disposed(by: disposeBag)
        
        error.onNext(true)
        
        
        
        enum SubjectType: Int {
            case teacther, student
        }
        
        let segmentSelection = BehaviorRelay<Int>(value: 0)
        
        segmentSelection.map{ SubjectType(rawValue: $0)! }
    }
    
    //driver
    func driverTest() {
        
        let viewModel2 = ViewModel2()
        
        let input = ViewModel2.Input.init(whatsNewTrigger: Observable.just(true))
        let output = viewModel2.transform(input: input)
        
        output.tabBarItems.delay(.milliseconds(50)).drive(onNext: {(tabBarItems) in
            tabBarItems.map { (value) in
                print("<<<<<< tabBarItem: \(value)")
            }
        }).disposed(by: disposeBag)
        
        output.openWhatsNews.drive(onNext: { value in
            print("========= openWhatsNews: \(value)")
        }).disposed(by: disposeBag)
        
        
    }
    
    
    //set、get方法
    func setAndGetTest() {
        print("token1 : \(String(describing: self._token))")
        
        self.token = "sasds111"
        
        print("token2 : \(String(describing: self._token))")
        
        self.token = nil
        
        print("token3 : \(String(describing: self._token))")
    }
    
    
    //rxTest1 方法必须放在viewDidLoad方法中，否则rx.viewWillAppear.mapToVoid()无法其作用
    func rxTest1() {
        let baseVM = BaseViewModel()
        
        //rx: 进入RxSwift世界入口，https://iweiyun.github.io/2018/11/01/rxcocoa-code/
        let input = BaseViewModel.Input(modules: rx.viewWillAppear.mapToVoid())
        let output = baseVM.transform(input: input)
        
        output.titles.delay(.milliseconds(50)).drive(onNext: {[weak self] (titles) in
            if let strongSelf = self {
                print(">>>>>>>> titles: \(titles), strongSelf: \(strongSelf)")
            }
        }).disposed(by: disposeBag)
        
        
        output.values.drive(onNext: {(values) in
            print("========== values: \(values)")
        }).disposed(by: disposeBag)
        
        
    }
    
    
    
    //ReplaySubject
    func replaySubjectTest() {
        
        //连续发送3个next事件
        subject.onNext("111")
        
        //skip: https://www.hangge.com/blog/cache/detail_1933.html
        //skip: 忽略1个序列，但是若是缓存序列则是对它无用
        subject.skip(1).subscribe(onNext: { (connected) in
            print("连接状态： \(connected)")
            
        }).disposed(by: disposeBag)
    }
    
    
    
    
    //主题颜色改变
    @objc func  changeTheme() {
        
        themeService.switch(ThemeType.light(color: .pink))
        
    }
    
    
    
    
    
}

