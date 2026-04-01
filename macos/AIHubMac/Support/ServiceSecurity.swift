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
    private static let commonIdentityProviderHosts = [
        "accounts.google.com",
        "appleid.apple.com",
        "github.com",
        "login.live.com",
        "login.microsoftonline.com",
        "login.microsoft.com",
        "auth.openai.com",
        "auth0.com",
        "okta.com",
        "onelogin.com"
    ]

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
            return uniqueHosts(baseHost + commonIdentityProviderHosts + [
                "chatgpt.com",
                "openai.com",
                "chat.openai.com",
                "oaistatic.com",
                "oaiusercontent.com"
            ])
        case "claude":
            return uniqueHosts(baseHost + commonIdentityProviderHosts + [
                "claude.ai",
                "anthropic.com"
            ])
        case "gemini":
            return uniqueHosts(baseHost + commonIdentityProviderHosts + [
                "gemini.google.com",
                "google.com",
                "gstatic.com",
                "googleusercontent.com"
            ])
        case "perplexity":
            return uniqueHosts(baseHost + commonIdentityProviderHosts + [
                "perplexity.ai",
                "www.perplexity.ai"
            ])
        case "copilot":
            return uniqueHosts(baseHost + commonIdentityProviderHosts + [
                "copilot.microsoft.com",
                "microsoft.com",
                "bing.com"
            ])
        default:
            return uniqueHosts(baseHost + commonIdentityProviderHosts)
        }
    }

    static func isHost(_ host: String, allowedBy trustedHosts: [String]) -> Bool {
        let normalizedHost = normalized(host)
        return trustedHosts.contains { trustedHost in
            let normalizedTrustedHost = normalized(trustedHost)
            return normalizedHost == normalizedTrustedHost || normalizedHost.hasSuffix(".\(normalizedTrustedHost)")
        }
    }

    static func shouldTrust(url: URL, allowedHosts: [String]) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return true }

        if !["http", "https"].contains(scheme) {
            return true
        }

        guard let host = url.host, !host.isEmpty else {
            return true
        }

        return isHost(host, allowedBy: allowedHosts)
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
                    .map(normalized)
                    .filter { !$0.isEmpty }
            )
        ).sorted()
    }

    private static func normalized(_ host: String) -> String {
        host
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }
}
