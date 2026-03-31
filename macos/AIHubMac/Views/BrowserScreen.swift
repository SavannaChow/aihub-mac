import SwiftUI

struct BrowserScreen: View {
    @EnvironmentObject private var appModel: AppModel
    let service: AIService

    var body: some View {
        VStack(spacing: 0) {
            BrowserToolbar(service: service)
            ZStack(alignment: .top) {
                if appModel.isSleeping(serviceID: service.id) {
                    ContentUnavailableView(
                        "This AI Is Sleeping",
                        systemImage: "moon.zzz",
                        description: Text("Wake it when you want to resume the page and its web activity.")
                    )
                } else {
                    BrowserWebView(service: service)
                        .id(webViewIdentity)
                }

                if appModel.browser.isLoading && !appModel.isSleeping(serviceID: service.id) {
                    ProgressView(value: appModel.browser.estimatedProgress, total: 1.0)
                        .progressViewStyle(.linear)
                        .padding(.horizontal)
                }
            }
        }
        .background(.background)
        .ignoresSafeArea(.container, edges: .top)
    }

    private var webViewIdentity: String {
        "\(service.id)-\(appModel.settings.desktopMode)"
    }
}
