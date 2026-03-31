import Foundation

struct RemoteServicesCatalog: Codable {
    let version: String
    let ai_services: [[String]]
}

enum RemoteServicesLoader {
    static let sourceURL = URL(string: "https://silentcoderhere.github.io/aihub-config-data/ai_services_list.json")!

    static func fetchServices() async throws -> [AIService] {
        let (data, _) = try await URLSession.shared.data(from: sourceURL)
        let catalog = try JSONDecoder().decode(RemoteServicesCatalog.self, from: data)

        return catalog.ai_services.compactMap { row in
            guard row.count >= 5 else { return nil }

            let name = row[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let url = row[1].trimmingCharacters(in: .whitespacesAndNewlines)
            let subtitle = row[2].trimmingCharacters(in: .whitespacesAndNewlines)
            let description = row[3].trimmingCharacters(in: .whitespacesAndNewlines)
            let accent = "#\(row[4].trimmingCharacters(in: .whitespacesAndNewlines))"

            guard !name.isEmpty else { return nil }

            return try? ServiceSecurity.validatedService(
                id: slugify(name),
                name: name,
                url: url,
                subtitle: "\(subtitle) • \(description)",
                symbolName: symbol(for: name),
                accentHex: accent
            )
        }
    }

    private static func slugify(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    private static func symbol(for name: String) -> String {
        switch name.lowercased() {
        case let name where name.contains("chatgpt"):
            return "sparkles.rectangle.stack"
        case let name where name.contains("claude"):
            return "text.bubble"
        case let name where name.contains("gemini"):
            return "wand.and.stars"
        case let name where name.contains("copilot"):
            return "square.and.pencil"
        case let name where name.contains("perplexity"):
            return "globe"
        case let name where name.contains("deepseek"):
            return "magnifyingglass.circle"
        default:
            return "cpu"
        }
    }
}
