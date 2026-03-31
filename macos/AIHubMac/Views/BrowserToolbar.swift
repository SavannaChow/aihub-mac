import SwiftUI

struct BrowserToolbar: View {
    @EnvironmentObject private var appModel: AppModel
    let service: AIService
    @State private var showingDownloads = false
    @State private var clearingServiceData = false

    var body: some View {
        HStack(spacing: 10) {
            Button(action: appModel.browser.goBack) {
                Image(systemName: "chevron.left")
            }
            .disabled(!appModel.browser.canGoBack)

            Button(action: appModel.browser.goForward) {
                Image(systemName: "chevron.right")
            }
            .disabled(!appModel.browser.canGoForward)

            if appModel.browser.isLoading {
                Button(action: appModel.browser.stopLoading) {
                    Image(systemName: "xmark")
                }
            } else {
                Button(action: appModel.browser.reload) {
                    Image(systemName: "arrow.clockwise")
                }
            }

            Button {
                appModel.browser.loadHome(
                    for: service,
                    preferredHomepage: appModel.settings.preferredHomepage
                )
            } label: {
                Image(systemName: "house")
            }

            Circle()
                .fill(service.accentColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 1) {
                Text(appModel.browser.pageTitle.isEmpty ? service.name : appModel.browser.pageTitle)
                    .font(.headline)
                    .lineLimit(1)
                Text(appModel.browser.currentURL?.absoluteString ?? service.url)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .textSelection(.enabled)
            }

            Spacer()

            Button(action: appModel.browser.openCurrentPageInDefaultBrowser) {
                Image(systemName: "safari")
            }
            .help("Open current page in default browser")

            Button {
                clearCurrentServiceData()
            } label: {
                if clearingServiceData {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "eraser.line.dashed")
                }
            }
            .help("Clear website data for this service only")
            .disabled(clearingServiceData)

            if appModel.isSleeping(serviceID: service.id) {
                Button {
                    appModel.wakeSelectedService()
                } label: {
                    Image(systemName: "play.circle")
                }
                .help("Wake this AI")
            } else {
                Button {
                    appModel.sleepSelectedService()
                } label: {
                    Image(systemName: "moon.zzz")
                }
                .help("Sleep this AI")
            }

            Button {
                showingDownloads.toggle()
            } label: {
                Image(systemName: "arrow.down.circle")
            }
            .help("Show downloads")
            .popover(isPresented: $showingDownloads, arrowEdge: .top) {
                DownloadsPopoverView()
                    .environmentObject(appModel)
            }
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func clearCurrentServiceData() {
        clearingServiceData = true
        Task {
            await appModel.clearWebsiteData(for: service)
            await MainActor.run {
                clearingServiceData = false
            }
        }
    }
}
