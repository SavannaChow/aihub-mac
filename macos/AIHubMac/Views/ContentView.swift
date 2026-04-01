import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appModel: AppModel
    @AppStorage("content.sidebar.width") private var storedSidebarWidth = 260.0

    @State private var sidebarWidth: Double = 260
    @State private var hasLoadedStoredWidth = false
    @State private var isHoveringDivider = false

    private let minSidebarWidth = 60.0
    private let maxSidebarWidth = 420.0
    private let dividerWidth = 1.0
    private let detailMinWidth = 480.0

    var body: some View {
        GeometryReader { proxy in
            let resolvedSidebarWidth = clampedSidebarWidth(for: proxy.size.width)

            HStack(spacing: 0) {
                SidebarView()
                    .frame(width: resolvedSidebarWidth)
                    .frame(maxHeight: .infinity)

                divider(totalWidth: proxy.size.width)

                DetailContainerView()
                    .frame(minWidth: detailMinWidth, maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                appModel.selectFirstServiceIfNeeded()

                guard !hasLoadedStoredWidth else { return }
                sidebarWidth = clamped(storedSidebarWidth, totalWidth: proxy.size.width)
                hasLoadedStoredWidth = true
            }
            .onChange(of: proxy.size.width) { _, newWidth in
                let clampedWidth = clamped(sidebarWidth, totalWidth: newWidth)
                if abs(clampedWidth - sidebarWidth) > 0.5 {
                    sidebarWidth = clampedWidth
                }
            }
        }
    }

    private func resizeGesture(totalWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .global)
            .onChanged { value in
                let nextWidth = clamped(value.location.x, totalWidth: totalWidth)
                sidebarWidth = nextWidth
            }
            .onEnded { value in
                let finalWidth = clamped(value.location.x, totalWidth: totalWidth)
                sidebarWidth = finalWidth
                storedSidebarWidth = finalWidth
            }
    }

    @ViewBuilder
    private func divider(totalWidth: CGFloat) -> some View {
        ZStack {
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(width: dividerWidth)

            Color.clear
                .frame(width: 10)
        }
        .frame(width: 10)
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering {
                if !isHoveringDivider {
                    NSCursor.resizeLeftRight.push()
                    isHoveringDivider = true
                }
            } else if isHoveringDivider {
                NSCursor.pop()
                isHoveringDivider = false
            }
        }
        .gesture(resizeGesture(totalWidth: totalWidth))
    }

    private func clampedSidebarWidth(for totalWidth: CGFloat) -> CGFloat {
        CGFloat(clamped(sidebarWidth, totalWidth: totalWidth))
    }

    private func clamped(_ width: Double, totalWidth: CGFloat) -> Double {
        let maxAllowedByWindow = max(minSidebarWidth, Double(totalWidth) - detailMinWidth - dividerWidth)
        let effectiveMax = min(maxSidebarWidth, maxAllowedByWindow)
        return max(minSidebarWidth, min(effectiveMax, width))
    }
}
