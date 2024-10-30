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
    case observable = "可观察序列"
    case subject = "桥梁subject-既可做观察者和订阅者"
    case observable_signal = "observable的signal序列"
    case drawLine = "绘制曲线"
    case filter = "滤镜"
    case cameraFilter = "相机滤镜"
}

class ViewController: UIViewController {
    
    fileprivate let items: [RxTestModule] = [
        .observable,
        .subject,
        .observable_signal,
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
        var controller = UIViewController()
        switch moduleName {
        case.observable:
            controller = TestObservableController()
        case .subject:
            controller = TestSubjectController()
        case .observable_signal:
            controller = TestObservableSignalController()
        default: break
        }
        
        self.navigationController?.pushViewController(controller, animated: true)
    }
}
