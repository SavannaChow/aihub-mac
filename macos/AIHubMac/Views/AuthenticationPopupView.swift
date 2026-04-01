import SwiftUI
import WebKit

struct AuthenticationPopupView: View {
    @EnvironmentObject private var appModel: AppModel
    let session: BrowserSessionController.PopupSession

    @StateObject private var observer: PopupWebViewObserver
    @State private var addressText = ""

    init(session: BrowserSessionController.PopupSession) {
        self.session = session
        _observer = StateObject(wrappedValue: PopupWebViewObserver(webView: session.webView))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button {
                    session.webView.goBack()
                } label: {
                    Image(systemName: "chevron.backward")
                }
                .disabled(!observer.canGoBack)

                Button {
                    session.webView.goForward()
                } label: {
                    Image(systemName: "chevron.forward")
                }
                .disabled(!observer.canGoForward)

                Button {
                    if observer.isLoading {
                        session.webView.stopLoading()
                    } else {
                        session.webView.reload()
                    }
                } label: {
                    Image(systemName: observer.isLoading ? "xmark" : "arrow.clockwise")
                }

                TextField("Address", text: $addressText, onCommit: loadAddress)
                    .textFieldStyle(.roundedBorder)

                Button("Open in Default Browser") {
                    appModel.browser.openPopupInDefaultBrowser()
                }

                Button("Close") {
                    appModel.browser.closePopup()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Authentication")
                        .font(.headline)
                    Text(session.serviceName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if observer.isLoading {
                    ProgressView(value: observer.estimatedProgress, total: 1.0)
                        .frame(width: 140)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 10)

            Divider()

            ExistingWebViewContainer(webView: session.webView)
                .frame(minWidth: 720, minHeight: 720)
        }
        .background(.background)
        .onAppear {
            addressText = observer.currentURL?.absoluteString ?? ""
        }
        .onChange(of: observer.currentURL) { _, newValue in
            addressText = newValue?.absoluteString ?? ""
        }
    }

    private func loadAddress() {
        let trimmed = addressText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let raw = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: raw) else { return }
        session.webView.load(URLRequest(url: url))
    }
}

@MainActor
private final class PopupWebViewObserver: ObservableObject {
    @Published var currentURL: URL?
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var isLoading = false
    @Published var estimatedProgress = 0.0

    private weak var webView: WKWebView?
    private var observations: [NSKeyValueObservation] = []

    init(webView: WKWebView) {
        self.webView = webView

        observations = [
            webView.observe(\.url, options: [.initial, .new]) { [weak self] webView, _ in
                Task { @MainActor in
                    self?.currentURL = webView.url
                }
            },
            webView.observe(\.canGoBack, options: [.initial, .new]) { [weak self] webView, _ in
                Task { @MainActor in
                    self?.canGoBack = webView.canGoBack
                }
            },
            webView.observe(\.canGoForward, options: [.initial, .new]) { [weak self] webView, _ in
                Task { @MainActor in
                    self?.canGoForward = webView.canGoForward
                }
            },
            webView.observe(\.isLoading, options: [.initial, .new]) { [weak self] webView, _ in
                Task { @MainActor in
                    self?.isLoading = webView.isLoading
                }
            },
            webView.observe(\.estimatedProgress, options: [.initial, .new]) { [weak self] webView, _ in
                Task { @MainActor in
                    self?.estimatedProgress = webView.estimatedProgress
                }
            }
        ]
    }

    deinit {
        observations.forEach { $0.invalidate() }
    }
}
