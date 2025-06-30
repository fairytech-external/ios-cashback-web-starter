//
//  ContentView.swift
//  ios-cashback-sample
//
//  Created by Kasel on 5/28/25.
//

import SwiftUI

struct ContentView: View {
    @State private var userId: String = ""
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack {
                TextField("텍스트를 입력하세요", text: $userId)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                Button("캐시백 페이지 오픈") {
                    UserDefaults.standard.set(userId, forKey: "userId")
                    navigationPath.append("fairy_cashback_page")
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding()
            .onOpenURL { url in
                // Deeplink 수신
                navigationPath.append(url.absoluteString)
            }.navigationDestination(for: String.self) { url in
                if url == "fairy_cashback_page" {
                    CashbackWebView(
                        userId: userId,
                        projectId: "<YOUR_PROJECT_ID>",
                        apiKey: "<YOUR_API_KEY>",
                        redirectTo: nil) {
                            navigationPath.removeLast()
                        }
                        .toolbar(.hidden, for: .navigationBar)
                } else {
                    let redirectTo = extractRedirectTo(from: url)
                    CashbackWebView(
                        userId: userId,
                        projectId: "<YOUR_PROJECT_ID>",
                        apiKey: "<YOUR_API_KEY>",
                        redirectTo: redirectTo) {
                            navigationPath.removeLast()
                        }
                        .toolbar(.hidden, for: .navigationBar)
                }
            }
        }
    }
    
    /// 딥링크로부터 redirect_to 쿼리 파라미터 추출
    private func extractRedirectTo(from urlString: String) -> String? {
        guard let url = URL(string: urlString),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let redirectTo = components.queryItems?.first(where: { $0.name == "redirect_to" })?.value
        else {
            return nil
        }
        return redirectTo
    }
}


#Preview {
    ContentView()
}
