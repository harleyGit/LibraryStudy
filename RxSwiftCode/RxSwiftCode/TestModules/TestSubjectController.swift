//
//  TestSubjectController.swift
//  RxSwiftCode
//
//  Created by GangHuang on 10/30/24.
//

import UIKit
import RxSwift

class TestSubjectController: UIViewController {
    
    fileprivate lazy var subjectBtn00: UIButton = createBtn(title: "AsyncSubject",
                                                            action: #selector(tapped(_:)))
    fileprivate lazy var replaySubjectBtn: UIButton = createBtn(title: "replaySubjectBtn",
                                                            action: #selector(testReplaySubjectAction(_:)))
    private let disposeBag = DisposeBag()
    
    private let replaySubject = ReplaySubject<String>.create(bufferSize: 1)
    private var isReplaySubjectFirst = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .systemBackground
        
        self.setupContentViews()
        
    }
    
    
    private func setupContentViews() {
        self.view.addSubview(self.subjectBtn00)
        self.view.addSubview(self.replaySubjectBtn)

        let viewW = self.view.frame.width
        let space: CGFloat = 6
        let leftMargin: CGFloat = 12
        
        let space3: CGFloat = CGFloat(space * 3)
        let leftMargin2: CGFloat = CGFloat(2 * leftMargin)
        let w = (viewW - space3 - leftMargin2 ) / 4
        let h: CGFloat = 60
        self.subjectBtn00.frame = CGRect(x: leftMargin, y: 100, width: w, height: h)
        self.replaySubjectBtn.frame = CGRect(x: self.subjectBtn00.frame.maxX + 4, y: self.subjectBtn00.frame.minY, width: w, height: h)
    }
    
    private func handleSubscribeEvent() {
        
        

        
    }
    
}

extension TestSubjectController {
    
    @objc func testReplaySubjectAction(_ sender: UIButton) {
        
        if self.isReplaySubjectFirst {            
            self.isReplaySubjectFirst = false

            self.replaySubject.subscribe{
                print("Subscription: 1 Event:", $0)
            }.disposed(by: self.disposeBag)
            self.replaySubject.onNext("🐱")
        }else {
            self.replaySubject.onNext("🐶")
        }
    }
    
    @objc func tapped(_ sender: UIButton)  {
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

//MARK: - Action
extension TestSubjectController {
    
    fileprivate func createBtn(title: String, action: Selector) -> UIButton {
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
        observableBtn00.addTarget(self, action: action, for: .touchUpInside)
        
        return observableBtn00
    }
}
