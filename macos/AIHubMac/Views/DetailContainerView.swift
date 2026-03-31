import SwiftUI

struct DetailContainerView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
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
}
