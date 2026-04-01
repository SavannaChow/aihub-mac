import Foundation

struct AppSettings: Codable, Equatable {
    var desktopMode = true
    var allowBackForwardNavigationGestures = true
    var keepSingleActiveWebView = true
    var openLinksInDefaultBrowser = false
    var openAuthenticationPopupsExternally = false
    var useCommandEnterToSend = false
    var preferredHomepage = ""
    var suspendWhenBackgrounded = true
    var nextServiceShortcut = ShortcutDescriptor.nextDefault
    var previousServiceShortcut = ShortcutDescriptor.previousDefault
}
