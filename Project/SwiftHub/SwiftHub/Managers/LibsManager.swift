//
//  LibsManager.swift
//  SwiftHub
//
//  Created by Khoren Markosyan on 1/4/17.
//  Copyright © 2017 Khoren Markosyan. All rights reserved.
//

import Foundation
import RxSwift
import RxCocoa
import SnapKit
import IQKeyboardManagerSwift
import CocoaLumberjack
import Kingfisher
#if DEBUG
import FLEX
#endif
import FirebaseCrashlytics
import NVActivityIndicatorView
import NSObject_Rx
import RxViewController
import RxOptional
import RxGesture
import SwifterSwift
import SwiftDate
import Hero
import KafkaRefresh
import Mixpanel
import Firebase
import DropDown
import Toast_Swift

//DropDown： 自然下拉组件替代UIPickView(时间选择器)
typealias DropDownView = DropDown

/// The manager class for configuring all libraries used in app.
class LibsManager: NSObject {
    /// The default singleton instance.
    static let shared = LibsManager()
    //bool(forKey defaultName: String): 对于指定的字符串"YES" or "1" will return YES
    //BehaviorRelay：https://beeth0ven.github.io/RxSwift-Chinese-Documentation/content/recipes/rxrelay.html
    let bannersEnabled = BehaviorRelay(value: UserDefaults.standard.bool(forKey: Configs.UserDefaultsKeys.bannersEnabled))
    private override init() {
        super.init()
        
        if UserDefaults.standard.object(forKey: Configs.UserDefaultsKeys.bannersEnabled) == nil {
            bannersEnabled.accept(true)
        }
        
        bannersEnabled.skip(1).subscribe(onNext: { (enabled) in
            UserDefaults.standard.set(enabled, forKey: Configs.UserDefaultsKeys.bannersEnabled)
            analytics.set(.adsEnabled(value: enabled))
        }).disposed(by: rx.disposeBag)
    }
    
    func setupLibs(with window: UIWindow? = nil) {
        let libsManager = LibsManager.shared
        //日志
        libsManager.setupCocoaLumberjack()
        //分析
        libsManager.setupAnalytics()
        //广告
        libsManager.setupAds()
        //主题颜色设置
        libsManager.setupTheme()
        //刷新样式
        libsManager.setupKafkaRefresh()
        //UI样式修改和控件读取
        libsManager.setupFLEX()
        //键盘
        libsManager.setupKeyboardManager()
        //精美加载loading动画
        libsManager.setupActivityView()
        //下拉滚动列表
        libsManager.setupDropDown()
        //提示框样式
        libsManager.setupToast()
    }
    
    func setupTheme() {
        themeService.rx
            .bind({ $0.statusBarStyle }, to: UIApplication.shared.rx.statusBarStyle)
            .disposed(by: rx.disposeBag)
    }
    
    //DropDown：https://github.com/AssistoLab/DropDown
    func setupDropDown() {
        themeService.attrsStream.subscribe(onNext: { (theme) in
            DropDown.appearance().backgroundColor = theme.primary
            DropDown.appearance().selectionBackgroundColor = theme.primaryDark
            DropDown.appearance().textColor = theme.text
            DropDown.appearance().selectedTextColor = theme.text
            DropDown.appearance().separatorColor = theme.separator
        }).disposed(by: rx.disposeBag)
    }
    
    //https://github.com/scalessec/Toast-Swift
    func setupToast() {
        //点击提示框是否消失
        ToastManager.shared.isTapToDismissEnabled = true
        ToastManager.shared.position = .top
        var style = ToastStyle()
        style.backgroundColor = UIColor.Material.red
        style.messageColor = UIColor.Material.white
        style.imageSize = CGSize(width: 20, height: 20)
        ToastManager.shared.style = style
    }
    
    func setupKafkaRefresh() {
        //KafkaRefresh 刷新动画等自定义：https://github.com/HsiaohuiHsiang/KafkaRefresh/blob/master/CREADME.md
        if let defaults = KafkaRefreshDefaults.standard() {
            //头刷新控件样式
            defaults.headDefaultStyle = .replicatorAllen
            //尾刷新控件样式
            defaults.footDefaultStyle = .replicatorDot
            themeService.rx
                .bind({ $0.secondary }, to: defaults.rx.themeColor)
                .disposed(by: rx.disposeBag)
        }
    }
    
    //https://kantai235.github.io/NVActivityIndicatorViewOfSwift/
    func setupActivityView() {
        //Loading动画：https://kantai235.github.io/NVActivityIndicatorViewOfSwift/
        NVActivityIndicatorView.DEFAULT_TYPE = .ballRotateChase
        NVActivityIndicatorView.DEFAULT_COLOR = .secondary()
    }
    
    func setupKeyboardManager() {
        //键盘处理： https://www.jianshu.com/p/5cb68b8dba84
        IQKeyboardManager.shared.enable = true
    }
    
    func setupKingfisher() {
        // Set maximum disk cache size for default cache. Default value is 0, which means no limit.
        ImageCache.default.diskStorage.config.sizeLimit = UInt(500 * 1024 * 1024) // 500 MB
        
        // Set longest time duration of the cache being stored in disk. Default value is 1 week
        ImageCache.default.diskStorage.config.expiration = .days(7) // 1 week
        
        // Set timeout duration for default image downloader. Default value is 15 sec.
        ImageDownloader.default.downloadTimeout = 15.0 // 15 sec
    }
    
    func setupCocoaLumberjack() {
        //DDLog：https://blog.csdn.net/shengpeng3344/article/details/105148752
        //日志语句将发送到Console.app和Xcode控制台（就像普通的NSLog一样）
        DDLog.add(DDOSLogger.sharedInstance)
        /**
         *日志语句将写入一个文件中
         */
        let fileLogger: DDFileLogger = DDFileLogger() // File Logger
        //rollingFrequency 滚日志文件的频率。 频率以NSTimeInterval的形式给出，它是一个双精度浮点数，指定以秒为单位的间隔。 一旦日志文件变得这么旧，它就会被重新生成。例如10min = 60x10就重新生成一个日志文件
        fileLogger.rollingFrequency = TimeInterval(60*60*24)  // 24 hours
        //maximumNumberOfLogFiles 要保存在磁盘上的归档日志文件的最大数量。如果这个属性设置为3，将只保留3个归档日志文件(加上当前活动的日志文件)在磁盘上，你可以设置0将其禁用
        fileLogger.logFileManager.maximumNumberOfLogFiles = 7
        DDLog.add(fileLogger)
    }
    
    //https://www.jianshu.com/p/dc7e08907989
    //http://neater.github.io/blog/2014/07/31/flex!iosdiao-shi-li-qi/
    func setupFLEX() {
        #if DEBUG
        FLEXManager.shared.isNetworkDebuggingEnabled = true
        #endif
    }
    
    /**
     *Firebase 添加至您的 iOS 项目: https://firebase.google.com/docs/ios/setup?hl=zh-cn
     *
     */
    func setupAnalytics() {
        
        //配置一个 FirebaseApp 共享实例
        //Firebase作用：https://juejin.cn/post/6844903475411681294
        //configure(): 配置默认的Firebase应用。如果任何配置步骤失败，则引发异常。默认应用名为“ __FIRAPP_DEFAULT”。在应用启动后和使用Firebase服务之前，应调用此方法。该方法应从主线程调用，并包含同步文件I / O（从磁盘读取GoogleService-Info.plist）
        FirebaseApp.configure()
        Mixpanel.initialize(token: Keys.mixpanel.apiKey)
        //setLoggerLevel: 设置内部Firebase日志记录的日志记录级别。 Firebase将仅记录在loggerLevel或以下记录的消息。这些消息既记录到Xcode控制台，又记录到设备的日志。请注意，如果应用程序是从AppStore运行的，则即使loggerLevel设置为更高（更详细）的设置，它也永远不会记录在FIRLoggerLevelNotice之上。
        //https://firebase.google.com/docs/reference/swift/firebasecore/api/reference/Classes/FirebaseConfiguration?hl=zh_CN#/c:objc(cs)FIRConfiguration(im)setLoggerLevel:
        FirebaseConfiguration.shared.setLoggerLevel(.min)
    }
    
    func setupAds() {
        //初始化移动广告:https://firebase.google.com/docs/admob/ios/quick-start?hl=zh-cn
        GADMobileAds.sharedInstance().start(completionHandler: nil)
    }
}

extension LibsManager {
    
    func showFlex() {
        #if DEBUG
        FLEXManager.shared.showExplorer()
        analytics.log(.flexOpened)
        #endif
    }
    
    func removeKingfisherCache() -> Observable<Void> {
        return ImageCache.default.rx.clearCache()
    }
    
    func kingfisherCacheSize() -> Observable<Int> {
        return ImageCache.default.rx.retrieveCacheSize()
    }
}
