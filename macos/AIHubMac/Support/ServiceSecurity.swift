import Foundation
import WebKit

enum ServiceSecurityError: LocalizedError {
    case invalidURL
    case unsupportedScheme
    case missingHost

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The service URL is invalid."
        case .unsupportedScheme:
            return "Only HTTPS service URLs are allowed."
        case .missingHost:
            return "The service URL must include a valid host."
        }
    }
}

enum ServiceSecurity {
    static func validatedService(
        id: String,
        name: String,
        url: String,
        subtitle: String,
        symbolName: String,
        accentHex: String
    ) throws -> AIService {
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmedURL) else {
            throw ServiceSecurityError.invalidURL
        }

        guard components.scheme?.lowercased() == "https" else {
            throw ServiceSecurityError.unsupportedScheme
        }

        guard let host = components.host, !host.isEmpty else {
            throw ServiceSecurityError.missingHost
        }

        return AIService(
            id: id.trimmingCharacters(in: .whitespacesAndNewlines),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            url: components.url?.absoluteString ?? trimmedURL,
            subtitle: subtitle.trimmingCharacters(in: .whitespacesAndNewlines),
            symbolName: symbolName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "globe" : symbolName.trimmingCharacters(in: .whitespacesAndNewlines),
            accentHex: accentHex.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "#2563EB" : accentHex.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    static func trustedHosts(for service: AIService) -> [String] {
        let baseHost = URL(string: service.url)?.host.map { [$0] } ?? []

        switch service.id {
        case "chatgpt":
            return uniqueHosts(baseHost + ["chatgpt.com", "openai.com", "auth.openai.com"])
        case "claude":
            return uniqueHosts(baseHost + ["claude.ai", "anthropic.com"])
        case "gemini":
            return uniqueHosts(baseHost + ["gemini.google.com", "google.com", "accounts.google.com"])
        case "perplexity":
            return uniqueHosts(baseHost + ["perplexity.ai", "www.perplexity.ai"])
        case "copilot":
            return uniqueHosts(baseHost + ["copilot.microsoft.com", "login.live.com", "microsoft.com"])
        default:
            return uniqueHosts(baseHost)
        }
    }

    static func isHost(_ host: String, allowedBy trustedHosts: [String]) -> Bool {
        let normalizedHost = host.lowercased()
        return trustedHosts.contains { trustedHost in
            let normalizedTrustedHost = trustedHost.lowercased()
            return normalizedHost == normalizedTrustedHost || normalizedHost.hasSuffix(".\(normalizedTrustedHost)")
        }
    }

    @MainActor
    static func matchingDataRecords(
        for service: AIService,
        records: [WKWebsiteDataRecord],
        trustedExceptionHosts: [String]
    ) -> [WKWebsiteDataRecord] {
        let allowedHosts = uniqueHosts(trustedHosts(for: service) + trustedExceptionHosts)
        return records.filter { record in
            isHost(record.displayName, allowedBy: allowedHosts)
        }
    }

    static func uniqueHosts(_ hosts: [String]) -> [String] {
        Array(
            Set(
                hosts
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                    .filter { !$0.isEmpty }
            )
        ).sorted()
    }
}
