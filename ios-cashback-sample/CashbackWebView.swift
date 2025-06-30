//
//  CashbackWebView.swift
//  ios-cashback-sample
//
//  Created by Kasel on 5/28/25.
//

import SwiftUI
import WebKit
import SwiftUI
import WebKit

private let FAIRY_CASHBACK_DOMAIN = "cashback-ui.moment.fairytech.ai"
private let FAIRY_CASHBACK_PATH = "/main"

struct CashbackWebView: UIViewRepresentable {
    let userId: String
    let projectId: String
    let apiKey: String
    let redirectTo: String?
    let onFinish: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(userId: userId,
                    projectId: projectId,
                    apiKey: apiKey,
                    onFinish: onFinish)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let controller = WKUserContentController()
        let preferences = WKPreferences()
        
        // 1) JS 팝업/새 창 허용
        preferences.javaScriptCanOpenWindowsAutomatically = true
        config.preferences = preferences
        
        // 2) 페이지 내 JS 실행 허용
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        
        // 3) DOM storage (localStorage / sessionStorage) 활성화
        // WKWebView는 기본적으로 켜져 있지만, 웹킷 버전에 따라 동작이 다를 수 있어 명시적으로 설정
        config.websiteDataStore = .default()
        
        // JS bridge: window.fairyCashbackBridge.finish() / reload(redirectTo)
        let js = """
        window.fairyCashbackBridge = {
            finish: function() {
                window.webkit.messageHandlers.finish.postMessage({});
            },
            reload: function(redirectTo) {
                window.webkit.messageHandlers.reload.postMessage({redirectTo: redirectTo});
            }
        };
        """
        controller.addUserScript(WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        controller.add(context.coordinator, name: "finish")
        controller.add(context.coordinator, name: "reload")

        config.userContentController = controller
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        
        // 4) 쿠키 공유 허용
        // iOS14 이상에서는 default() 스토어가 쿠키를 자동으로 관리하지만,
        // iOS13 이하를 지원해야 할 때는 수동으로 Cookie를 동기화해줘야 합니다.
        let webView = WKWebView(frame: .zero, configuration: config)
        let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
        // (예시) 저장된 쿠키 불러오기
        HTTPCookieStorage.shared.cookies?.forEach { cookie in
            cookieStore.setCookie(cookie)
        }

        webView.isInspectable = true
        context.coordinator.webView = webView
        context.coordinator.load(redirectTo: redirectTo)
        webView.uiDelegate = context.coordinator
        
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKScriptMessageHandler, WKUIDelegate {
        var webView: WKWebView?
        let userId: String
        let projectId: String
        let apiKey: String
        let onFinish: () -> Void

        init(userId: String, projectId: String, apiKey: String, onFinish: @escaping () -> Void) {
            self.userId = userId
            self.projectId = projectId
            self.apiKey = apiKey
            self.onFinish = onFinish
        }

        func load(redirectTo: String? = nil) {
            var components = URLComponents()
            components.scheme = "https"
            components.host   = FAIRY_CASHBACK_DOMAIN
            components.path   = FAIRY_CASHBACK_PATH

            if let redirectTo = redirectTo {
                components.queryItems = [
                    URLQueryItem(name: "redirect_to", value: redirectTo)
                ]
            }

            guard let finalUrl = components.url else { return }
            var request = URLRequest(url: finalUrl)
            
            request.setValue(userId, forHTTPHeaderField: "x-moment-user-id")
            request.setValue(projectId, forHTTPHeaderField: "x-moment-project-id")
            request.setValue(apiKey, forHTTPHeaderField: "x-moment-web-api-key")
            request.setValue("IOS", forHTTPHeaderField: "x-moment-platform")

            webView?.load(request)
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "finish" {
                onFinish()
            } else if message.name == "reload" {
                let redirectTo = (message.body as? [String: Any])?["redirectTo"] as? String
                load(redirectTo: redirectTo)
            }
        }
        
        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            guard let url = navigationAction.request.url else { return nil }

            if let host = url.host, host.contains(FAIRY_CASHBACK_DOMAIN) {
                // 내부 링크는 웹뷰에서 처리
                return nil
            } else {
                // 외부 링크는 Safari 등으로 오픈
                UIApplication.shared.open(url)
                return nil
            }
        }
    }
}


