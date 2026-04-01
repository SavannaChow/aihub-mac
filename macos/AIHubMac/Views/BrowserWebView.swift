import SwiftUI
import WebKit

struct BrowserWebView: NSViewRepresentable {
    @EnvironmentObject private var appModel: AppModel
    let service: AIService

    func makeNSView(context: Context) -> WKWebView {
        appModel.browser.attach(
            service: service,
            desktopMode: appModel.settings.desktopMode,
            preferredHomepage: appModel.settings.preferredHomepage
        )
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.allowsBackForwardNavigationGestures = appModel.settings.allowBackForwardNavigationGestures
    }
}

struct ExistingWebViewContainer: NSViewRepresentable {
    let webView: WKWebView

    func makeNSView(context: Context) -> WKWebView {
        webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
