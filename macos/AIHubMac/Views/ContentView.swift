import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 240, ideal: 260)
        } detail: {
            DetailContainerView()
        }
        .onAppear {
            appModel.selectFirstServiceIfNeeded()
        }
    }
}
