import Foundation

struct DownloadItem: Identifiable, Equatable {
    let id = UUID()
    let suggestedFilename: String
    let originURL: URL?
    var destinationURL: URL?
    var status: Status

    enum Status: Equatable {
        case preparing
        case finished
        case failed(String)
    }
}
