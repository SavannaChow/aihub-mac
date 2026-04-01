import SwiftUI

struct DetailContainerView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        Group {
            if let service = appModel.selectedService {
                BrowserScreen(service: service)
            } else {
                ContentUnavailableView(
                    "No Service Selected",
                    systemImage: "rectangle.stack.badge.person.crop",
                    description: Text("Choose an AI service from the sidebar to begin.")
                )
            }
        }
        .sheet(item: popupBinding) { session in
            AuthenticationPopupView(session: session)
                .environmentObject(appModel)
        }
    }

    private var popupBinding: Binding<BrowserSessionController.PopupSession?> {
        Binding(
            get: { appModel.browser.popupSession },
            set: { newValue in
                if newValue == nil {
                    appModel.browser.closePopup()
                }
            }
        )
    }
}
