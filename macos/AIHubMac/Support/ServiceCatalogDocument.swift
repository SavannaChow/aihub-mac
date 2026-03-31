import SwiftUI
import UniformTypeIdentifiers

struct ServiceCatalogDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var services: [AIService]

    init(services: [AIService]) {
        self.services = services
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }

        services = try JSONDecoder().decode([AIService].self, from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try JSONEncoder().encode(services)
        return .init(regularFileWithContents: data)
    }
}
