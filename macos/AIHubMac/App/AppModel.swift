import AppKit
import Foundation
import Combine
import WebKit

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var services: [AIService]
    @Published private(set) var allServices: [AIService]
    @Published private(set) var hasCachedOfficialCatalog: Bool
    @Published var customServices: [AIService] {
        didSet {
            UserDefaultsStore.save(customServices: customServices)
            rebuildServices()
        }
    }
    @Published var selectedServiceID: String
    @Published private(set) var enabledServiceIDs: [String]
    @Published private(set) var sleepingServiceIDs: Set<String> = []
    @Published var settings: AppSettings {
        didSet {
            UserDefaultsStore.save(settings: settings)
            browser.openLinksInDefaultBrowser = settings.openLinksInDefaultBrowser
            browser.allowBackForwardNavigationGestures = settings.allowBackForwardNavigationGestures
            browser.suspendWhenBackgrounded = settings.suspendWhenBackgrounded
            browser.keepSingleActiveWebView = settings.keepSingleActiveWebView
        }
    }

    let browser: BrowserSessionController
    private var cancellables: Set<AnyCancellable> = []
    private var builtInServices: [AIService]
    private var keyMonitor: Any?
    private var trustedHostsByService: [String: [String]]

    init(
        services: [AIService] = AIService.defaults,
        browser: BrowserSessionController = BrowserSessionController()
    ) {
        let cachedBuiltInServices = UserDefaultsStore.loadCachedBuiltInServices() ?? services
        self.builtInServices = cachedBuiltInServices
        self.customServices = UserDefaultsStore.loadCustomServices()
        self.services = cachedBuiltInServices
        self.allServices = cachedBuiltInServices
        self.hasCachedOfficialCatalog = UserDefaultsStore.loadCachedBuiltInServices() != nil
        self.enabledServiceIDs = UserDefaultsStore.loadEnabledServiceIDs()
        self.trustedHostsByService = UserDefaultsStore.loadTrustedHostsByService()
        self.browser = browser

        let settings = UserDefaultsStore.loadSettings()
        self.settings = settings
        self.selectedServiceID = ""

        rebuildServices()

        let preferredServiceID = UserDefaultsStore.loadSelectedServiceID()
        self.selectedServiceID = self.services.first(where: { $0.id == preferredServiceID })?.id
            ?? self.services.first?.id
            ?? "chatgpt"

        browser.openLinksInDefaultBrowser = settings.openLinksInDefaultBrowser
        browser.allowBackForwardNavigationGestures = settings.allowBackForwardNavigationGestures
        browser.suspendWhenBackgrounded = settings.suspendWhenBackgrounded
        browser.keepSingleActiveWebView = settings.keepSingleActiveWebView
        browser.trustedHostsProvider = { [weak self] service in
            guard let self else { return [] }
            return self.trustedHosts(for: service.id)
        }
        browser.trustHostRecorder = { [weak self] service, host in
            self?.trust(host: host, for: service.id)
        }

        installKeyMonitor()

        browser.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

    }

    var selectedService: AIService? {
        services.first(where: { $0.id == selectedServiceID })
    }

    func isEnabled(serviceID: String) -> Bool {
        enabledServiceIDs.contains(serviceID)
    }

    func trustedHosts(for serviceID: String) -> [String] {
        trustedHostsByService[serviceID] ?? []
    }

    func isCustomService(_ service: AIService) -> Bool {
        customServices.contains(where: { $0.id == service.id })
    }

    func setServiceEnabled(_ isEnabled: Bool, serviceID: String) {
        if isEnabled {
            if !enabledServiceIDs.contains(serviceID) {
                enabledServiceIDs.append(serviceID)
            }
        } else {
            enabledServiceIDs.removeAll { $0 == serviceID }
        }

        UserDefaultsStore.save(enabledServiceIDs: enabledServiceIDs)
        rebuildServices()
    }

    func moveEnabledServices(from source: IndexSet, to destination: Int) {
        enabledServiceIDs.move(fromOffsets: source, toOffset: destination)
        UserDefaultsStore.save(enabledServiceIDs: enabledServiceIDs)
        rebuildServices()
    }

    func removeCustomService(id: String) {
        customServices.removeAll { $0.id == id }
        enabledServiceIDs.removeAll { $0 == id }
        sleepingServiceIDs.remove(id)
        trustedHostsByService.removeValue(forKey: id)
        UserDefaultsStore.save(enabledServiceIDs: enabledServiceIDs)
        UserDefaultsStore.save(trustedHostsByService: trustedHostsByService)
        rebuildServices()
        selectFirstServiceIfNeeded()
    }

    func addCustomService(
        id: String,
        name: String,
        url: String,
        subtitle: String,
        symbolName: String,
        accentHex: String
    ) throws {
        let service = try ServiceSecurity.validatedService(
            id: id,
            name: name,
            url: url,
            subtitle: subtitle,
            symbolName: symbolName,
            accentHex: accentHex
        )
        addCustomService(service)
    }

    func select(serviceID: String) {
        guard selectedServiceID != serviceID else { return }
        browser.persistSnapshot()
        selectedServiceID = serviceID
        UserDefaultsStore.save(selectedServiceID: serviceID)
    }

    func selectFirstServiceIfNeeded() {
        guard selectedService == nil, let first = services.first else { return }
        selectedServiceID = first.id
        UserDefaultsStore.save(selectedServiceID: first.id)
    }

    func updateDesktopMode(_ enabled: Bool) {
        settings.desktopMode = enabled
        browser.updateConfiguration(desktopMode: enabled)
    }

    func updateKeepSingleActiveWebView(_ enabled: Bool) {
        settings.keepSingleActiveWebView = enabled
        if enabled {
            browser.releaseInactiveWebViews()
        }
    }

    func cycleService(offset: Int) {
        guard !services.isEmpty,
              let currentIndex = services.firstIndex(where: { $0.id == selectedServiceID })
        else {
            return
        }

        let nextIndex = (currentIndex + offset + services.count) % services.count
        select(serviceID: services[nextIndex].id)
    }

    func sleepSelectedService() {
        guard let service = selectedService else { return }
        sleepingServiceIDs.insert(service.id)
        browser.persistSnapshot()
        browser.releaseWebView()
        objectWillChange.send()
    }

    func wakeSelectedService() {
        guard let service = selectedService else { return }
        sleepingServiceIDs.remove(service.id)
        objectWillChange.send()
    }

    func isSleeping(serviceID: String) -> Bool {
        sleepingServiceIDs.contains(serviceID)
    }

    func addCustomService(_ service: AIService) {
        customServices.append(service)
        if !enabledServiceIDs.contains(service.id) {
            enabledServiceIDs.append(service.id)
            UserDefaultsStore.save(enabledServiceIDs: enabledServiceIDs)
        }
        rebuildServices()
        select(serviceID: service.id)
    }

    func updateCustomService(_ service: AIService) {
        guard let index = customServices.firstIndex(where: { $0.id == service.id }) else {
            return
        }

        customServices[index] = service
        rebuildServices()
    }

    func removeCustomServices(at offsets: IndexSet) {
        let removedIDs = offsets.map { customServices[$0].id }
        customServices.remove(atOffsets: offsets)

        if removedIDs.contains(selectedServiceID) {
            selectFirstServiceIfNeeded()
        }
    }

    func importServices(from url: URL) throws {
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: url)
        let imported = try JSONDecoder().decode([AIService].self, from: data)
        let valid = try imported.compactMap { service -> AIService? in
            guard !service.id.isEmpty, !service.name.isEmpty else { return nil }
            return try ServiceSecurity.validatedService(
                id: service.id,
                name: service.name,
                url: service.url,
                subtitle: service.subtitle,
                symbolName: service.symbolName,
                accentHex: service.accentHex
            )
        }

        for service in valid {
            if let index = customServices.firstIndex(where: { $0.id == service.id }) {
                customServices[index] = service
            } else if !builtInServices.contains(where: { $0.id == service.id }) {
                customServices.append(service)
            }

            if !enabledServiceIDs.contains(service.id) {
                enabledServiceIDs.append(service.id)
            }
        }

        UserDefaultsStore.save(enabledServiceIDs: enabledServiceIDs)
        rebuildServices()
    }

    func exportDocument() -> ServiceCatalogDocument {
        ServiceCatalogDocument(services: allServices)
    }

    func refreshBuiltInServices() async throws {
        let remoteServices = try await RemoteServicesLoader.fetchServices()
        guard !remoteServices.isEmpty else { return }
        builtInServices = remoteServices
        UserDefaultsStore.save(cachedBuiltInServices: remoteServices)
        hasCachedOfficialCatalog = true
        rebuildServices()
    }

    func clearWebsiteData(for service: AIService) async {
        await browser.clearWebsiteData(
            for: service,
            trustedExceptionHosts: trustedHosts(for: service.id)
        )
    }

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }

            if self.settings.nextServiceShortcut.matches(event) {
                self.cycleService(offset: 1)
                return nil
            }

            if self.settings.previousServiceShortcut.matches(event) {
                self.cycleService(offset: -1)
                return nil
            }

            if event.keyCode == 125 {
                self.cycleService(offset: 1)
                return nil
            }

            if event.keyCode == 126 {
                self.cycleService(offset: -1)
                return nil
            }

            return event
        }
    }

    private func trust(host: String, for serviceID: String) {
        let updated = ServiceSecurity.uniqueHosts((trustedHostsByService[serviceID] ?? []) + [host])
        trustedHostsByService[serviceID] = updated
        UserDefaultsStore.save(trustedHostsByService: trustedHostsByService)
    }

    private func rebuildServices() {
        let filteredCustom = customServices.filter { service in
            !builtInServices.contains(where: { $0.id == service.id })
        }

        if filteredCustom != customServices {
            customServices = filteredCustom
            return
        }

        let rebuiltAllServices = builtInServices + filteredCustom.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        allServices = rebuiltAllServices

        let availableIDs = Set(rebuiltAllServices.map(\.id))
        let filteredEnabledIDs = enabledServiceIDs.filter { availableIDs.contains($0) }
        if filteredEnabledIDs != enabledServiceIDs {
            enabledServiceIDs = filteredEnabledIDs
            UserDefaultsStore.save(enabledServiceIDs: filteredEnabledIDs)
        }

        if enabledServiceIDs.isEmpty {
            let defaultVisibleIDs = rebuiltAllServices.prefix(4).map(\.id)
            enabledServiceIDs = defaultVisibleIDs
            UserDefaultsStore.save(enabledServiceIDs: defaultVisibleIDs)
        }

        let serviceByID = Dictionary(uniqueKeysWithValues: rebuiltAllServices.map { ($0.id, $0) })
        services = enabledServiceIDs.compactMap { serviceByID[$0] }

        if !services.contains(where: { $0.id == selectedServiceID }), let first = services.first {
            selectedServiceID = first.id
            UserDefaultsStore.save(selectedServiceID: first.id)
        }
    }
}
