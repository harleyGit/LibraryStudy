//
//  WhatsNewManager.swift
//  SwiftHub
//
//  Created by Sygnoos9 on 12/16/18.
//  Copyright © 2018 Khoren Markosyan. All rights reserved.
//

import Foundation
import WhatsNewKit

/**
 *  WhatsNewKit：使您能够轻松展示出色的更新应用程序功能。它是从头开始设计的，可以完全根据您的需求进行定制。
 * https://github.com/SvenTiigi/WhatsNewKit
 */
typealias WhatsNewBlock = (WhatsNew, WhatsNewConfiguration, KeyValueWhatsNewVersionStore?)
typealias WhatsNewConfiguration = WhatsNewViewController.Configuration

class WhatsNewManager: NSObject {

    /// The default singleton instance.
    static let shared = WhatsNewManager()

    func whatsNew(trackVersion track: Bool = true) -> WhatsNewBlock {
        return (items(), configuration(), track ? versionStore(): nil)
    }
    
    //功能更新条目内容
    private func items() -> WhatsNew {
        let whatsNew = WhatsNew(
            title: R.string.localizable.whatsNewTitle.key.localized(),
            items: [
                WhatsNew.Item(title: R.string.localizable.whatsNewItem4Title.key.localized(),
                              subtitle: R.string.localizable.whatsNewItem4Subtitle.key.localized(),
                              image: R.image.icon_whatsnew_trending()),
                WhatsNew.Item(title: R.string.localizable.whatsNewItem1Title.key.localized(),
                              subtitle: R.string.localizable.whatsNewItem1Subtitle.key.localized(),
                              image: R.image.icon_whatsnew_cloc()),
                WhatsNew.Item(title: R.string.localizable.whatsNewItem2Title.key.localized(),
                              subtitle: R.string.localizable.whatsNewItem2Subtitle.key.localized(),
                              image: R.image.icon_whatsnew_theme()),
                WhatsNew.Item(title: R.string.localizable.whatsNewItem3Title.key.localized(),
                              subtitle: R.string.localizable.whatsNewItem3Subtitle.key.localized(),
                              image: R.image.icon_whatsnew_github())
            ])
        return whatsNew
    }

    private func configuration() -> WhatsNewViewController.Configuration {
        var configuration = WhatsNewViewController.Configuration(
            detailButton: .init(title: R.string.localizable.whatsNewDetailButtonTitle.key.localized(),
                                action: .website(url: Configs.App.githubUrl)),//按钮详情点击跳转
            completionButton: .init(stringLiteral: R.string.localizable.whatsNewCompletionButtonTitle.key.localized())
        )
        // configuration.itemsView.layout = .centered
        configuration.itemsView.imageSize = .original
        configuration.apply(animation: .slideRight)
        if ThemeType.currentTheme().isDark {
            configuration.apply(theme: .darkRed)
            configuration.backgroundColor = .primaryDark()
        } else {
            configuration.apply(theme: .whiteRed)
            configuration.backgroundColor = .white
        }
        return configuration
    }

    //商店显示时的版本号
    private func versionStore() -> KeyValueWhatsNewVersionStore {
        let versionStore = KeyValueWhatsNewVersionStore(keyValueable: UserDefaults.standard,
                                                        prefixIdentifier: Configs.App.bundleIdentifier)
        return versionStore
    }
}
