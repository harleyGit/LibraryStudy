//
//  Networking.swift
//  SwiftHub
//
//  Created by Khoren Markosyan on 1/4/17.
//  Copyright © 2017 Khoren Markosyan. All rights reserved.
//

import Foundation
import Moya
import RxSwift
import Alamofire

class OnlineProvider<Target> where Target: Moya.TargetType {
    //网络是否可用
    fileprivate let online: Observable<Bool>
    fileprivate let provider: MoyaProvider<Target>

    //endpoint是Moya用来推断最终将要进行的网络请求的半内部数据结构：https://juejin.cn/post/6844903581284302856#heading-5
    init(endpointClosure: @escaping MoyaProvider<Target>.EndpointClosure = MoyaProvider<Target>.defaultEndpointMapping,
         requestClosure: @escaping MoyaProvider<Target>.RequestClosure = MoyaProvider<Target>.defaultRequestMapping,
         stubClosure: @escaping MoyaProvider<Target>.StubClosure = MoyaProvider<Target>.neverStub,
         session: Session = MoyaProvider<Target>.defaultAlamofireSession(),
         plugins: [PluginType] = [],
         trackInflights: Bool = false,
         online: Observable<Bool> = connectedToInternet()) {
        self.online = online
        /**
         *MoyaProvider初始化
         *MoyaProvider 就是 Moya 最顶层的请求头，对应的协议就是 MoyaProviderType。
         *endpointClosure：创建一个Endpoint实例，Moya将使用它来推断网络API调用
         *在某些时候，该Endpoints必须解析成一个实际的URLRequest给Alamofire，这就是requestClosure参数的用途。 requestClosure是一种可选的，用来修改网络的请求的最后方式。
         *requestClosure，它将Endpoint解析为实际的URLRequest。
         *stubClosure： 这将返回.never（默认值），.immediate或.delayed（seconds）之一，您可以将已存根的请求延迟一定的时间。 例如，.delayed（0.2）将延迟每个存根请求。 这可以很好地模拟单元测试中的网络延迟。
         */
        self.provider = MoyaProvider(endpointClosure: endpointClosure, requestClosure: requestClosure, stubClosure: stubClosure, session: session, plugins: plugins, trackInflights: trackInflights)
    }

    func request(_ token: Target) -> Observable<Moya.Response> {
        let actualRequest = provider.rx.request(token)
        return online
            .ignore(value: false)  // Wait until we're online
            .take(1)        // Take 1 to make sure we only invoke the API once.
            .flatMap { _ in // Turn the online state into a network request
                return actualRequest
                    .filterSuccessfulStatusCodes()
                    .do(onSuccess: { (response) in
                    }, onError: { (error) in
                        if let error = error as? MoyaError {
                            switch error {
                            case .statusCode(let response):
                                if response.statusCode == 401 {
                                    // Unauthorized
                                    if AuthManager.shared.hasValidToken {
                                        AuthManager.removeToken()
                                        Application.shared.presentInitialScreen(in: Application.shared.window)
                                    }
                                }
                            default: break
                            }
                        }
                    })
        }
    }
}

protocol NetworkingType {
    associatedtype T: TargetType, ProductAPIType
    var provider: OnlineProvider<T> { get }

    static func defaultNetworking() -> Self
    static func stubbingNetworking() -> Self
}

struct GithubNetworking: NetworkingType {
    typealias T = GithubAPI
    let provider: OnlineProvider<T>

    static func defaultNetworking() -> Self {
        return GithubNetworking(provider: newProvider(plugins))
    }

    static func stubbingNetworking() -> Self {
        return GithubNetworking(provider: OnlineProvider(endpointClosure: endpointsClosure(), requestClosure: GithubNetworking.endpointResolver(), stubClosure: MoyaProvider.immediatelyStub, online: .just(true)))
    }

    func request(_ token: T) -> Observable<Moya.Response> {
        let actualRequest = self.provider.request(token)
        return actualRequest
    }
}

struct TrendingGithubNetworking: NetworkingType {
    typealias T = TrendingGithubAPI
    let provider: OnlineProvider<T>

    static func defaultNetworking() -> Self {
        return TrendingGithubNetworking(provider: newProvider(plugins))
    }

    static func stubbingNetworking() -> Self {
        return TrendingGithubNetworking(provider: OnlineProvider(endpointClosure: endpointsClosure(), requestClosure: TrendingGithubNetworking.endpointResolver(), stubClosure: MoyaProvider.immediatelyStub, online: .just(true)))
    }

    func request(_ token: T) -> Observable<Moya.Response> {
        let actualRequest = self.provider.request(token)
        return actualRequest
    }
}

struct CodetabsNetworking: NetworkingType {
    typealias T = CodetabsApi
    let provider: OnlineProvider<T>

    static func defaultNetworking() -> Self {
        return CodetabsNetworking(provider: newProvider(plugins))
    }

    static func stubbingNetworking() -> Self {
        return CodetabsNetworking(provider: OnlineProvider(endpointClosure: endpointsClosure(), requestClosure: CodetabsNetworking.endpointResolver(), stubClosure: MoyaProvider.immediatelyStub, online: .just(true)))
    }

    func request(_ token: T) -> Observable<Moya.Response> {
        let actualRequest = self.provider.request(token)
        return actualRequest
    }
}

extension NetworkingType {
    //where 限制了T的类型
    static func endpointsClosure<T>(_ xAccessToken: String? = nil) -> (T) -> Endpoint where T: TargetType, T: ProductAPIType {
        return { target in
            let endpoint = MoyaProvider.defaultEndpointMapping(for: target)

            // Sign all non-XApp, non-XAuth token requests
            return endpoint
        }
    }

    static func APIKeysBasedStubBehaviour<T>(_: T) -> Moya.StubBehavior {
        return .never
    }

    static var plugins: [PluginType] {
        var plugins: [PluginType] = []
        if Configs.Network.loggingEnabled == true {
            plugins.append(NetworkLoggerPlugin())
        }
        return plugins
    }

    // (Endpoint<Target>, NSURLRequest -> Void) -> Void
    static func endpointResolver() -> MoyaProvider<T>.RequestClosure {
        return { (endpoint, closure) in
            do {
                var request = try endpoint.urlRequest() // endpoint.urlRequest
                request.httpShouldHandleCookies = false
                closure(.success(request))
            } catch {
                logError(error.localizedDescription)
            }
        }
    }
}

private func newProvider<T>(_ plugins: [PluginType], xAccessToken: String? = nil) -> OnlineProvider<T> where T: ProductAPIType {
    return OnlineProvider(endpointClosure: GithubNetworking.endpointsClosure(xAccessToken),
                          requestClosure: GithubNetworking.endpointResolver(),
                          stubClosure: GithubNetworking.APIKeysBasedStubBehaviour,
                          plugins: plugins)
}

// MARK: - Provider support

func stubbedResponse(_ filename: String) -> Data! {
    @objc class TestClass: NSObject { }

    let bundle = Bundle(for: TestClass.self)
    let path = bundle.path(forResource: filename, ofType: "json")
    return (try? Data(contentsOf: URL(fileURLWithPath: path!)))
}

private extension String {
    var URLEscapedString: String {
        return self.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlHostAllowed)!
    }
}

func url(_ route: TargetType) -> String {
    return route.baseURL.appendingPathComponent(route.path).absoluteString
}
