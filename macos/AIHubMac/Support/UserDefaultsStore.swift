import Foundation

enum UserDefaultsStore {
    private static let settingsKey = "app_settings"
    private static let selectedServiceKey = "selected_service_id"
    private static let customServicesKey = "custom_services"
    private static let enabledServiceIDsKey = "enabled_service_ids"
    private static let trustedHostsKey = "trusted_hosts_by_service"
    private static let cachedBuiltInServicesKey = "cached_built_in_services"

    static func loadSettings() -> AppSettings {
        guard
            let data = UserDefaults.standard.data(forKey: settingsKey),
            let settings = try? JSONDecoder().decode(AppSettings.self, from: data)
        else {
            return AppSettings()
        }

        return settings
    }

    static func save(settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else {
            return
        }

        UserDefaults.standard.set(data, forKey: settingsKey)
    }

    static func loadSelectedServiceID() -> String? {
        UserDefaults.standard.string(forKey: selectedServiceKey)
    }

    static func save(selectedServiceID: String) {
        UserDefaults.standard.set(selectedServiceID, forKey: selectedServiceKey)
    }

    static func loadCustomServices() -> [AIService] {
        guard
            let data = UserDefaults.standard.data(forKey: customServicesKey),
            let services = try? JSONDecoder().decode([AIService].self, from: data)
        else {
            return []
        }

        return services
    }

    static func save(customServices: [AIService]) {
        guard let data = try? JSONEncoder().encode(customServices) else {
            return
        }

        UserDefaults.standard.set(data, forKey: customServicesKey)
    }

    static func loadEnabledServiceIDs() -> [String] {
        UserDefaults.standard.stringArray(forKey: enabledServiceIDsKey) ?? []
    }

    static func save(enabledServiceIDs: [String]) {
        UserDefaults.standard.set(enabledServiceIDs, forKey: enabledServiceIDsKey)
    }

    static func loadTrustedHostsByService() -> [String: [String]] {
        guard
            let data = UserDefaults.standard.data(forKey: trustedHostsKey),
            let value = try? JSONDecoder().decode([String: [String]].self, from: data)
        else {
            return [:]
        }

        return value
    }

    static func save(trustedHostsByService: [String: [String]]) {
        guard let data = try? JSONEncoder().encode(trustedHostsByService) else {
            return
        }

        UserDefaults.standard.set(data, forKey: trustedHostsKey)
    }

    static func loadCachedBuiltInServices() -> [AIService]? {
        guard
            let data = UserDefaults.standard.data(forKey: cachedBuiltInServicesKey),
            let services = try? JSONDecoder().decode([AIService].self, from: data),
            !services.isEmpty
        else {
            return nil
        }

        return services
    }

    static func save(cachedBuiltInServices: [AIService]) {
        guard let data = try? JSONEncoder().encode(cachedBuiltInServices) else {
            return
        }

        UserDefaults.standard.set(data, forKey: cachedBuiltInServicesKey)
    }
}
