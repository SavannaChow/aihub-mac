import SwiftUI

struct AIService: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let url: String
    let subtitle: String
    let symbolName: String
    let accentHex: String

    var accentColor: Color {
        Color(hex: accentHex) ?? .accentColor
    }
}

extension AIService {
    var isBuiltIn: Bool {
        Self.defaults.contains(where: { $0.id == id })
    }
}

extension AIService {
    static let defaults: [AIService] = [
        AIService(
            id: "chatgpt",
            name: "ChatGPT",
            url: "https://chatgpt.com/",
            subtitle: "OpenAI",
            symbolName: "sparkles.rectangle.stack",
            accentHex: "#10A37F"
        ),
        AIService(
            id: "claude",
            name: "Claude",
            url: "https://claude.ai/",
            subtitle: "Anthropic",
            symbolName: "text.bubble",
            accentHex: "#D97706"
        ),
        AIService(
            id: "gemini",
            name: "Gemini",
            url: "https://gemini.google.com/",
            subtitle: "Google",
            symbolName: "wand.and.stars",
            accentHex: "#2563EB"
        ),
        AIService(
            id: "perplexity",
            name: "Perplexity",
            url: "https://www.perplexity.ai/",
            subtitle: "Search-native AI",
            symbolName: "globe",
            accentHex: "#0F766E"
        )
    ]
}
