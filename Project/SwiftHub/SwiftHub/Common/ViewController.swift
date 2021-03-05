//
//  ViewController.swift
//  SwiftHub
//
//  Created by Khoren Markosyan on 1/4/17.
//  Copyright © 2017 Khoren Markosyan. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import DZNEmptyDataSet
import NVActivityIndicatorView
import Hero
import Localize_Swift
import GoogleMobileAds

class ViewController: UIViewController, Navigatable, NVActivityIndicatorViewable {

    var viewModel: ViewModel?
    var navigator: Navigator!

    init(viewModel: ViewModel?, navigator: Navigator) {
        self.viewModel = viewModel
        self.navigator = navigator
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(nibName: nil, bundle: nil)
    }

    let isLoading = BehaviorRelay(value: false)
    let error = PublishSubject<ApiError>()

    var automaticallyAdjustsLeftBarButtonItem = true
    var canOpenFlex = true

    var navigationTitle = "" {
        didSet {
            navigationItem.title = navigationTitle
        }
    }

    let spaceBarButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: nil, action: nil)
    
    //PublishSubject：https://www.jianshu.com/p/cac5549cb09a
    let emptyDataSetButtonTap = PublishSubject<Void>()
    var emptyDataSetTitle = R.string.localizable.commonNoResults.key.localized()
    var emptyDataSetDescription = ""
    //没有内容时的图片资源
    var emptyDataSetImage = R.image.image_no_result()
    var emptyDataSetImageTintColor = BehaviorRelay<UIColor?>(value: nil)

    let languageChanged = BehaviorRelay<Void>(value: ())

    let orientationEvent = PublishSubject<Void>()
    let motionShakeEvent = PublishSubject<Void>()

    lazy var searchBar: SearchBar = {
        let view = SearchBar()
        return view
    }()

    lazy var backBarButton: BarButtonItem = {
        let view = BarButtonItem()
        view.title = ""
        return view
    }()

    lazy var closeBarButton: BarButtonItem = {
        let view = BarButtonItem(image: R.image.icon_navigation_close(),
                                 style: .plain,
                                 target: self,
                                 action: nil)
        return view
    }()

    //广告横幅View：https://developers.google.com/admob/ios/x-ad-rendering?hl=zh-cn
    lazy var bannerView: GADBannerView = {
        let view = GADBannerView(adSize: kGADAdSizeSmartBannerPortrait)
        view.rootViewController = self
        view.adUnitID = Keys.adMob.apiKey
        view.hero.id = "BannerView"
        return view
    }()

    lazy var contentView: View = {
        let view = View()
        //        view.hero.id = "CententView"
        self.view.addSubview(view)
        view.snp.makeConstraints { (make) in
            make.edges.equalTo(self.view.safeAreaLayoutGuide)
        }
        return view
    }()

    //堆叠视图：https://jjeremy-xue.medium.com/swift-說說-堆疊視圖-uistack-view-557c09f24645
    lazy var stackView: StackView = {
        let subviews: [UIView] = []
        let view = StackView(arrangedSubviews: subviews)
        view.spacing = 0
        self.contentView.addSubview(view)
        view.snp.makeConstraints({ (make) in
            make.edges.equalToSuperview()
        })
        return view
    }()

    override public func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        makeUI()
        bindViewModel()

        closeBarButton.rx.tap.asObservable().subscribe(onNext: { [weak self] () in
            self?.navigator.dismiss(sender: self)
        }).disposed(by: rx.disposeBag)

        // Observe device orientation change
        NotificationCenter.default
            .rx.notification(UIDevice.orientationDidChangeNotification).mapToVoid()
            .bind(to: orientationEvent).disposed(by: rx.disposeBag)

        orientationEvent.subscribe { [weak self] (event) in
            self?.orientationChanged()
        }.disposed(by: rx.disposeBag)

        // Observe application did become active notification
        NotificationCenter.default
            .rx.notification(UIApplication.didBecomeActiveNotification)
            .subscribe { [weak self] (event) in
                self?.didBecomeActive()
            }.disposed(by: rx.disposeBag)

        NotificationCenter.default
            .rx.notification(UIAccessibility.reduceMotionStatusDidChangeNotification)
            .subscribe(onNext: { (event) in
                logDebug("Motion Status changed")
            }).disposed(by: rx.disposeBag)

        // Observe application did change language notification
        NotificationCenter.default
            .rx.notification(NSNotification.Name(LCLLanguageChangeNotification))
            .subscribe { [weak self] (event) in
                self?.languageChanged.accept(())
            }.disposed(by: rx.disposeBag)

        // One finger swipe gesture for opening Flex
        let swipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleOneFingerSwipe(swipeRecognizer:)))
        swipeGesture.numberOfTouchesRequired = 1
        self.view.addGestureRecognizer(swipeGesture)

        // Two finger swipe gesture for opening Flex and Hero debug
        let twoSwipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleTwoFingerSwipe(swipeRecognizer:)))
        twoSwipeGesture.numberOfTouchesRequired = 2
        self.view.addGestureRecognizer(twoSwipeGesture)
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if automaticallyAdjustsLeftBarButtonItem {
            adjustLeftBarButtonItem()
        }
        updateUI()
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateUI()

        logResourcesCount()
    }

    deinit {
        logDebug("\(type(of: self)): Deinited")
        logResourcesCount()
    }

    override public func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
        logDebug("\(type(of: self)): Received Memory Warning")
    }

    func makeUI() {
        hero.isEnabled = true
        navigationItem.backBarButtonItem = backBarButton

        bannerView.load(GADRequest())
        //asDriver():将普通序列转换为 Driver, https://beeth0ven.github.io/RxSwift-Chinese-Documentation/content/rxswift_core/observable/driver.html
        LibsManager.shared.bannersEnabled.asDriver().drive(onNext: { [weak self] (enabled) in
            guard let self = self else { return }
            self.bannerView.removeFromSuperview()
            self.stackView.removeArrangedSubview(self.bannerView)
            if enabled {
                self.stackView.addArrangedSubview(self.bannerView)
            }
        }).disposed(by: rx.disposeBag)

        motionShakeEvent.subscribe(onNext: { () in
            let theme = themeService.type.toggled()
            themeService.switch(theme)
        }).disposed(by: rx.disposeBag)

        themeService.rx
            .bind({ $0.primaryDark }, to: view.rx.backgroundColor)
            .bind({ $0.secondary }, to: [backBarButton.rx.tintColor, closeBarButton.rx.tintColor])
            .bind({ $0.text }, to: self.rx.emptyDataSetImageTintColorBinder)
            .disposed(by: rx.disposeBag)

        updateUI()
    }

    func bindViewModel() {
        //viewModel?.loading和isLoading的数据类型相同，通过bind方法导致2个观察序列保持状态相同
        //加载状态绑定
        viewModel?.loading.asObservable().bind(to: isLoading).disposed(by: rx.disposeBag)
        //错误绑定：返回回来的解析错误数据绑定到error上，进行显示
        viewModel?.parsedError.asObservable().bind(to: error).disposed(by: rx.disposeBag)

        languageChanged.subscribe(onNext: { [weak self] () in
            self?.emptyDataSetTitle = R.string.localizable.commonNoResults.key.localized()
        }).disposed(by: rx.disposeBag)

        //显示是否是在加载状态中
        isLoading.subscribe(onNext: { isLoading in
            UIApplication.shared.isNetworkActivityIndicatorVisible = isLoading
        }).disposed(by: rx.disposeBag)
    }

    func updateUI() {

    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            motionShakeEvent.onNext(())
        }
    }

    func orientationChanged() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.updateUI()
        }
    }

    func didBecomeActive() {
        self.updateUI()
    }

    // MARK: Adjusting Navigation Item
    //左边返回按钮显示与否，以及
    func adjustLeftBarButtonItem() {
        if self.navigationController?.viewControllers.count ?? 0 > 1 { // Pushed
            self.navigationItem.leftBarButtonItem = nil
        } else if self.presentingViewController != nil { // presented
            self.navigationItem.leftBarButtonItem = closeBarButton
        }
    }

    @objc func closeAction(sender: AnyObject) {
        self.dismiss(animated: true, completion: nil)
    }
}

extension ViewController {

    var inset: CGFloat {
        return Configs.BaseDimensions.inset
    }

    func emptyView(withHeight height: CGFloat) -> View {
        let view = View()
        view.snp.makeConstraints { (make) in
            make.height.equalTo(height)
        }
        return view
    }

    @objc func handleOneFingerSwipe(swipeRecognizer: UISwipeGestureRecognizer) {
        if swipeRecognizer.state == .recognized, canOpenFlex {
            LibsManager.shared.showFlex()
        }
    }

    @objc func handleTwoFingerSwipe(swipeRecognizer: UISwipeGestureRecognizer) {
        if swipeRecognizer.state == .recognized {
            LibsManager.shared.showFlex()
            HeroDebugPlugin.isEnabled = !HeroDebugPlugin.isEnabled
        }
    }
}

extension Reactive where Base: ViewController {

    /// Bindable sink for `backgroundColor` property
    var emptyDataSetImageTintColorBinder: Binder<UIColor?> {
        return Binder(self.base) { view, attr in
            view.emptyDataSetImageTintColor.accept(attr)
        }
    }
}

//DZNEmptyDataSetSource：空白页处理， https://blog.csdn.net/jichunw/article/details/80089067
extension ViewController: DZNEmptyDataSetSource {

    //标题为空的数据集
    func title(forEmptyDataSet scrollView: UIScrollView!) -> NSAttributedString! {
        return NSAttributedString(string: emptyDataSetTitle)
    }

    //描述为空的数据集
    func description(forEmptyDataSet scrollView: UIScrollView!) -> NSAttributedString! {
        return NSAttributedString(string: emptyDataSetDescription)
    }

    //空数据按钮图片
    func image(forEmptyDataSet scrollView: UIScrollView!) -> UIImage! {
        return emptyDataSetImage
    }

    //设置默认空白界面布局图片的前景色,默认为nil.
    func imageTintColor(forEmptyDataSet scrollView: UIScrollView!) -> UIColor! {
        return emptyDataSetImageTintColor.value
    }

    //设置默认空白界面的背景颜色。默认为 [UIColor clearColor]
    func backgroundColor(forEmptyDataSet scrollView: UIScrollView!) -> UIColor! {
        return .clear
    }

    func verticalOffset(forEmptyDataSet scrollView: UIScrollView!) -> CGFloat {
        return -60
    }
}

extension ViewController: DZNEmptyDataSetDelegate {

    func emptyDataSetShouldDisplay(_ scrollView: UIScrollView!) -> Bool {
        return !isLoading.value
    }

    //实现该方法告诉代理该视图允许滚动,默认为NO。
    func emptyDataSetShouldAllowScroll(_ scrollView: UIScrollView!) -> Bool {
        return true
    }

    func emptyDataSet(_ scrollView: UIScrollView!, didTap button: UIButton!) {
        emptyDataSetButtonTap.onNext(())
    }
}
