import AppKit
import Combine
import WebKit

@MainActor
final class BrowserSessionController: NSObject, ObservableObject {
    @Published private(set) var activeServiceID: String?
    @Published private(set) var pageTitle = ""
    @Published private(set) var currentURL: URL?
    @Published private(set) var estimatedProgress = 0.0
    @Published private(set) var isLoading = false
    @Published private(set) var canGoBack = false
    @Published private(set) var canGoForward = false
    @Published private(set) var downloads: [DownloadItem] = []

    var openLinksInDefaultBrowser = false
    var allowBackForwardNavigationGestures = true {
        didSet {
            webViews.values.forEach { $0.allowsBackForwardNavigationGestures = allowBackForwardNavigationGestures }
        }
    }
    var suspendWhenBackgrounded = true
    var keepSingleActiveWebView = true
    var trustedHostsProvider: ((AIService) -> [String])?
    var trustHostRecorder: ((AIService, String) -> Void)?

    let websiteDataStore: WKWebsiteDataStore

    var webView: WKWebView? {
        activeServiceID.flatMap { webViews[$0] }
    }
    private var snapshots: [String: ServiceSnapshot] = [:]
    private var observationHandles: [NSKeyValueObservation] = []
    private var popupRequest: URLRequest?
    private var pendingDownloadDestination: URL?
    private var webViews: [String: WKWebView] = [:]
    private var servicesByID: [String: AIService] = [:]

    override init() {
        websiteDataStore = .default()
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidResignActive),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func attach(service: AIService, desktopMode: Bool, preferredHomepage: String) -> WKWebView {
        persistSnapshot()
        servicesByID[service.id] = service

        if keepSingleActiveWebView, activeServiceID != service.id {
            releaseNonActiveWebViews(keeping: service.id)
        }

        let webView = webViews[service.id] ?? makeWebView(
            service: service,
            desktopMode: desktopMode,
            preferredHomepage: preferredHomepage
        )
        activeServiceID = service.id
        bind(webView)
        return webView
    }

    func goBack() {
        webView?.goBack()
    }

    func goForward() {
        webView?.goForward()
    }

    func reload() {
        webView?.reload()
    }

    func stopLoading() {
        webView?.stopLoading()
    }

    func loadHome(for service: AIService, preferredHomepage: String) {
        let url = URL(string: preferredHomepage).flatMap { candidate in
            candidate.absoluteString.isEmpty ? nil : candidate
        } ?? URL(string: service.url)

        guard let url else { return }
        webView?.load(URLRequest(url: url))
    }

    func openCurrentPageInDefaultBrowser() {
        guard let url = currentURL else { return }
        NSWorkspace.shared.open(url)
    }

    func clearWebsiteData() async {
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        let date = Date(timeIntervalSince1970: 0)
        await withCheckedContinuation { continuation in
            websiteDataStore.removeData(ofTypes: dataTypes, modifiedSince: date) {
                continuation.resume()
            }
        }
        webView?.reload()
    }

    func clearWebsiteData(for service: AIService, trustedExceptionHosts: [String]) async {
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        let records = await withCheckedContinuation { continuation in
            websiteDataStore.fetchDataRecords(ofTypes: dataTypes) { records in
                continuation.resume(returning: records)
            }
        }

        let matchingRecords = ServiceSecurity.matchingDataRecords(
            for: service,
            records: records,
            trustedExceptionHosts: trustedExceptionHosts
        )

        if !matchingRecords.isEmpty {
            await withCheckedContinuation { continuation in
                websiteDataStore.removeData(ofTypes: dataTypes, for: matchingRecords) {
                    continuation.resume()
                }
            }
        }

        let httpCookieStore = websiteDataStore.httpCookieStore
        let cookies = await withCheckedContinuation { continuation in
            httpCookieStore.getAllCookies { cookies in
                continuation.resume(returning: cookies)
            }
        }

        let allowedHosts = ServiceSecurity.uniqueHosts(
            ServiceSecurity.trustedHosts(for: service) + trustedExceptionHosts
        )
        for cookie in cookies where ServiceSecurity.isHost(cookie.domain, allowedBy: allowedHosts) {
            await withCheckedContinuation { continuation in
                httpCookieStore.delete(cookie) {
                    continuation.resume()
                }
            }
        }

        if activeServiceID == service.id {
            webView?.reload()
        }
    }

    func clearCachesOnly() async {
        let cacheTypes: Set<String> = [
            WKWebsiteDataTypeDiskCache,
            WKWebsiteDataTypeMemoryCache,
            WKWebsiteDataTypeFetchCache,
            WKWebsiteDataTypeOfflineWebApplicationCache
        ]
        let date = Date(timeIntervalSince1970: 0)
        await withCheckedContinuation { continuation in
            websiteDataStore.removeData(ofTypes: cacheTypes, modifiedSince: date) {
                continuation.resume()
            }
        }
        webView?.reload()
    }

    func clearCookiesOnly() async {
        let cookieTypes: Set<String> = [
            WKWebsiteDataTypeCookies,
            WKWebsiteDataTypeSessionStorage,
            WKWebsiteDataTypeLocalStorage
        ]
        let date = Date(timeIntervalSince1970: 0)
        await withCheckedContinuation { continuation in
            websiteDataStore.removeData(ofTypes: cookieTypes, modifiedSince: date) {
                continuation.resume()
            }
        }
        webView?.reload()
    }

    func updateConfiguration(desktopMode: Bool) {
        webViews.values.forEach {
            $0.customUserAgent = desktopMode ? UserAgent.desktop : nil
            $0.reload()
        }
    }

    func snapshot(for serviceID: String) -> ServiceSnapshot? {
        snapshots[serviceID]
    }

    func persistSnapshot() {
        guard let activeServiceID else { return }
        snapshots[activeServiceID] = ServiceSnapshot(
            currentURL: webView?.url ?? currentURL,
            pageTitle: webView?.title ?? pageTitle
        )
    }

    func releaseWebView() {
        guard let activeServiceID else { return }
        releaseWebView(for: activeServiceID)
    }

    func releaseInactiveWebViews() {
        guard let activeServiceID else {
            releaseAllWebViews()
            return
        }
        releaseNonActiveWebViews(keeping: activeServiceID)
    }

    private func makeWebView(service: AIService, desktopMode: Bool, preferredHomepage: String) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = websiteDataStore
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.isTextInteractionEnabled = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = allowBackForwardNavigationGestures
        webView.allowsMagnification = true
        webView.setValue(false, forKey: "drawsBackground")
        webView.customUserAgent = desktopMode ? UserAgent.desktop : nil

        let fallbackURL = URL(string: preferredHomepage).flatMap { candidate in
            candidate.absoluteString.isEmpty ? nil : candidate
        } ?? URL(string: service.url)

        let targetURL = snapshots[service.id]?.currentURL ?? fallbackURL
        if let targetURL {
            webView.load(URLRequest(url: targetURL))
        }

        webViews[service.id] = webView
        return webView
    }

    private func releaseWebView(for serviceID: String) {
        if activeServiceID == serviceID {
            observationHandles.forEach { $0.invalidate() }
            observationHandles.removeAll()
        }

        if let webView = webViews[serviceID] {
            webView.navigationDelegate = nil
            webView.uiDelegate = nil
            webView.stopLoading()
        }

        webViews.removeValue(forKey: serviceID)
        if activeServiceID == serviceID {
            activeServiceID = nil
        }
        isLoading = false
        estimatedProgress = 0
        canGoBack = false
        canGoForward = false
    }

    private func releaseNonActiveWebViews(keeping serviceID: String) {
        for cachedServiceID in Array(webViews.keys) where cachedServiceID != serviceID {
            releaseWebView(for: cachedServiceID)
        }
    }

    private func releaseAllWebViews() {
        for cachedServiceID in Array(webViews.keys) {
            releaseWebView(for: cachedServiceID)
        }
    }

    func dismissDownload(_ item: DownloadItem.ID) {
        downloads.removeAll { $0.id == item }
    }

    @objc private func applicationDidResignActive() {
        guard suspendWhenBackgrounded else { return }
        let pauseScript =
            """
            try {
              const media = document.querySelectorAll('video, audio');
              media.forEach(item => item.pause && item.pause());
            } catch (e) {}
            """
        webViews.values.forEach { $0.evaluateJavaScript(pauseScript) }
    }

    private func bind(_ webView: WKWebView) {
        observationHandles.forEach { $0.invalidate() }
        observationHandles = [
            webView.observe(\.title, options: [.initial, .new]) { [weak self] webView, _ in
                Task { @MainActor [weak self, weak webView] in
                    guard let self, let webView else { return }
                    self.pageTitle = webView.title ?? ""
                }
            },
            webView.observe(\.url, options: [.initial, .new]) { [weak self] webView, _ in
                Task { @MainActor [weak self, weak webView] in
                    guard let self, let webView else { return }
                    self.currentURL = webView.url
                }
            },
            webView.observe(\.isLoading, options: [.initial, .new]) { [weak self] webView, _ in
                Task { @MainActor [weak self, weak webView] in
                    guard let self, let webView else { return }
                    self.isLoading = webView.isLoading
                }
            },
            webView.observe(\.estimatedProgress, options: [.initial, .new]) { [weak self] webView, _ in
                Task { @MainActor [weak self, weak webView] in
                    guard let self, let webView else { return }
                    self.estimatedProgress = webView.estimatedProgress
                }
            },
            webView.observe(\.canGoBack, options: [.initial, .new]) { [weak self] webView, _ in
                Task { @MainActor [weak self, weak webView] in
                    guard let self, let webView else { return }
                    self.canGoBack = webView.canGoBack
                }
            },
            webView.observe(\.canGoForward, options: [.initial, .new]) { [weak self] webView, _ in
                Task { @MainActor [weak self, weak webView] in
                    guard let self, let webView else { return }
                    self.canGoForward = webView.canGoForward
                }
            }
        ]
    }
}

extension BrowserSessionController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        persistSnapshot()
    }

    func webView(
        _ webView: WKWebView,
        navigationAction: WKNavigationAction,
        didBecome download: WKDownload
    ) {
        download.delegate = self
    }

    func webView(
        _ webView: WKWebView,
        navigationResponse: WKNavigationResponse,
        didBecome download: WKDownload
    ) {
        download.delegate = self
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
    ) {
        if let service = service(for: webView),
           let url = navigationAction.request.url,
           !isTrustedNavigation(for: service, url: url),
           !confirmUntrustedNavigation(for: service, url: url) {
            decisionHandler(.cancel)
            return
        }

        guard openLinksInDefaultBrowser else {
            decisionHandler(.allow)
            return
        }

        if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
            return
        }

        decisionHandler(.allow)
    }

    private func service(for webView: WKWebView) -> AIService? {
        guard let serviceID = webViews.first(where: { $0.value === webView })?.key else {
            return nil
        }

        return servicesByID[serviceID]
    }

    private func isTrustedNavigation(for service: AIService, url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return true }
        let allowedHosts = ServiceSecurity.uniqueHosts(
            ServiceSecurity.trustedHosts(for: service) + (trustedHostsProvider?(service) ?? [])
        )
        return ServiceSecurity.isHost(host, allowedBy: allowedHosts)
    }

    private func confirmUntrustedNavigation(for service: AIService, url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return true }

        let alert = NSAlert()
        alert.messageText = "Open Untrusted Host?"
        alert.informativeText = "\(service.name) is trying to open \(host), which is outside the trusted domains for this service. Only continue if you recognize the destination."
        alert.addButton(withTitle: "Trust and Continue")
        alert.addButton(withTitle: "Cancel")

        let result = alert.runModal() == .alertFirstButtonReturn
        if result {
            trustHostRecorder?(service, host)
        }
        return result
    }
}

extension BrowserSessionController: WKUIDelegate {
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if let url = navigationAction.request.url {
            popupRequest = URLRequest(url: url)
            webView.load(URLRequest(url: url))
        }
        return nil
    }

    func webViewDidClose(_ webView: WKWebView) {
        webView.stopLoading()
    }

    func webView(
        _ webView: WKWebView,
        runOpenPanelWith parameters: WKOpenPanelParameters,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping @MainActor ([URL]?) -> Void
    ) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        panel.begin { response in
            completionHandler(response == .OK ? panel.urls : nil)
        }
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping @MainActor () -> Void
    ) {
        let alert = NSAlert()
        alert.messageText = message
        alert.runModal()
        completionHandler()
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping @MainActor (Bool) -> Void
    ) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        completionHandler(alert.runModal() == .alertFirstButtonReturn)
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping @MainActor (String?) -> Void
    ) {
        let alert = NSAlert()
        alert.messageText = prompt
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(string: defaultText ?? "")
        input.frame = NSRect(x: 0, y: 0, width: 320, height: 24)
        alert.accessoryView = input

        let result = alert.runModal()
        completionHandler(result == .alertFirstButtonReturn ? input.stringValue : nil)
    }
}

extension BrowserSessionController: WKDownloadDelegate {
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping @MainActor (URL?) -> Void) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedFilename
        panel.canCreateDirectories = true
        panel.begin { [weak self] result in
            guard let self else {
                completionHandler(nil)
                return
            }

            if result == .OK, let url = panel.url {
                self.pendingDownloadDestination = url
                self.downloads.insert(
                    DownloadItem(
                        suggestedFilename: suggestedFilename,
                        originURL: response.url,
                        destinationURL: url,
                        status: .preparing
                    ),
                    at: 0
                )
                completionHandler(url)
            } else {
                completionHandler(nil)
            }
        }
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let destination = pendingDownloadDestination else { return }
        if let index = downloads.firstIndex(where: { $0.destinationURL == destination }) {
            downloads[index].status = .finished
        }
        pendingDownloadDestination = nil
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        if let destination = pendingDownloadDestination,
           let index = downloads.firstIndex(where: { $0.destinationURL == destination }) {
            downloads[index].status = .failed(error.localizedDescription)
        } else {
            downloads.insert(
                DownloadItem(
                    suggestedFilename: "Download",
                    originURL: nil,
                    destinationURL: nil,
                    status: .failed(error.localizedDescription)
                ),
                at: 0
            )
        }
        pendingDownloadDestination = nil
    }
}

private enum UserAgent {
    static let desktop =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
}
