import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var isClearingData = false
    @State private var isClearingCache = false
    @State private var isClearingCookies = false

    var body: some View {
        Form {
            Section("Browsing") {
                Toggle("Prefer desktop user agent", isOn: desktopModeBinding)
                Toggle(
                    "Trackpad swipe back/forward",
                    isOn: $appModel.settings.allowBackForwardNavigationGestures
                )
                Toggle(
                    "Open clicked links in default browser",
                    isOn: $appModel.settings.openLinksInDefaultBrowser
                )
                Toggle(
                    "Use Cmd+Enter to send on supported services",
                    isOn: cmdEnterBinding
                )
                Toggle(
                    "Pause active web content when app goes to background",
                    isOn: suspendBinding
                )
                TextField(
                    "Optional custom homepage URL",
                    text: $appModel.settings.preferredHomepage
                )
                .textFieldStyle(.roundedBorder)
            }

            Section("Shortcuts") {
                ShortcutEditorView(
                    title: "Next AI service",
                    shortcut: $appModel.settings.nextServiceShortcut
                )
                ShortcutEditorView(
                    title: "Previous AI service",
                    shortcut: $appModel.settings.previousServiceShortcut
                )
                Text("These shortcuts cycle through the current AI list in the sidebar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Performance") {
                Toggle("Keep only one active web view", isOn: keepSingleActiveBinding)
                Text("This app keeps a single live WKWebView and shares cookies across services to reduce CPU use while preserving sign-in state.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Privacy") {
                Button(role: .destructive) {
                    clearWebsiteData()
                } label: {
                    if isClearingData {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Clear website data and cookies")
                    }
                }
                .disabled(isClearingData)

                Button {
                    clearCacheOnly()
                } label: {
                    if isClearingCache {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Clear cache only")
                    }
                }
                .disabled(isClearingCache)

                Button {
                    clearCookiesOnly()
                } label: {
                    if isClearingCookies {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Clear cookies and local storage")
                    }
                }
                .disabled(isClearingCookies)
            }
        }
        .formStyle(.grouped)
    }

    private var desktopModeBinding: Binding<Bool> {
        Binding(
            get: { appModel.settings.desktopMode },
            set: { newValue in
                appModel.updateDesktopMode(newValue)
            }
        )
    }

    private func clearWebsiteData() {
        isClearingData = true

        Task {
            await appModel.browser.clearWebsiteData()
            await MainActor.run {
                isClearingData = false
            }
        }
    }

    private var suspendBinding: Binding<Bool> {
        Binding(
            get: { appModel.settings.suspendWhenBackgrounded },
            set: { appModel.settings.suspendWhenBackgrounded = $0 }
        )
    }

    private var keepSingleActiveBinding: Binding<Bool> {
        Binding(
            get: { appModel.settings.keepSingleActiveWebView },
            set: { appModel.updateKeepSingleActiveWebView($0) }
        )
    }

    private var cmdEnterBinding: Binding<Bool> {
        Binding(
            get: { appModel.settings.useCommandEnterToSend },
            set: { appModel.updateCommandEnterToSend($0) }
        )
    }

    private func clearCacheOnly() {
        isClearingCache = true

        Task {
            await appModel.browser.clearCachesOnly()
            await MainActor.run {
                isClearingCache = false
            }
        }
    }

    private func clearCookiesOnly() {
        isClearingCookies = true

        Task {
            await appModel.browser.clearCookiesOnly()
            await MainActor.run {
                isClearingCookies = false
            }
        }
    }
}
