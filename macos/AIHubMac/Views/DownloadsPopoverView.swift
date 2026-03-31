import SwiftUI

struct DownloadsPopoverView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Downloads")
                .font(.headline)

            if appModel.browser.downloads.isEmpty {
                Text("No downloads yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(appModel.browser.downloads) { item in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.suggestedFilename)
                            Text(statusText(for: item.status))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let destination = item.destinationURL {
                                Text(destination.path)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(2)
                            }
                        }

                        Spacer()

                        Button {
                            appModel.browser.dismissDownload(item.id)
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 420)
    }

    private func statusText(for status: DownloadItem.Status) -> String {
        switch status {
        case .preparing:
            return "Preparing download"
        case .finished:
            return "Finished"
        case .failed(let message):
            return "Failed: \(message)"
        }
    }
}
