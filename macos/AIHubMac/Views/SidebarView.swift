import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var showingServiceManager = false
    @State private var isEditingEnabledServices = false
    @State private var draftID = ""
    @State private var draftName = ""
    @State private var draftURL = ""
    @State private var draftSubtitle = ""
    @State private var draftSymbolName = "globe"
    @State private var draftAccentHex = "#2563EB"
    @State private var editingCustomServiceID: String?
    @State private var confirmingOfficialCatalogLoad = false
    @State private var loadingOfficialCatalog = false
    @State private var addErrorMessage: String?

    var body: some View {
        GeometryReader { proxy in
            let isCompactSidebar = !isEditingEnabledServices && proxy.size.width <= 76

            List(selection: selectionBinding) {
                if isEditingEnabledServices {
                    Section("Enabled AI Order") {
                        ForEach(appModel.services) { service in
                            HStack(spacing: 12) {
                                Image(systemName: service.symbolName)
                                    .foregroundStyle(service.accentColor)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(service.name)
                                    Text(service.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "line.3.horizontal")
                                    .foregroundStyle(.tertiary)
                                    .help("Drag to reorder")
                            }
                        }
                        .onMove(perform: appModel.moveEnabledServices)
                    }

                    Section("All AI Services") {
                        ForEach(appModel.allServices) { service in
                            HStack(spacing: 12) {
                                Image(systemName: service.symbolName)
                                    .foregroundStyle(service.accentColor)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(service.name)
                                    Text(service.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Toggle(
                                    "",
                                    isOn: Binding(
                                        get: { appModel.isEnabled(serviceID: service.id) },
                                        set: { appModel.setServiceEnabled($0, serviceID: service.id) }
                                    )
                                )
                                .labelsHidden()

                                if appModel.isCustomService(service) {
                                    Button {
                                        startEditing(service)
                                    } label: {
                                        Image(systemName: "pencil")
                                    }
                                    .buttonStyle(.borderless)
                                    .help("Edit custom service")

                                    Button(role: .destructive) {
                                        if editingCustomServiceID == service.id {
                                            resetDraft()
                                        }
                                        appModel.removeCustomService(id: service.id)
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.borderless)
                                    .help("Delete custom service")
                                }
                            }
                        }
                    }

                    if !appModel.hasCachedOfficialCatalog {
                        Section("Official Catalog") {
                            Button {
                                confirmingOfficialCatalogLoad = true
                            } label: {
                                HStack {
                                    if loadingOfficialCatalog {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Image(systemName: "arrow.down.circle")
                                    }
                                    Text("Load Official AI Catalog")
                                }
                            }
                            .disabled(loadingOfficialCatalog)

                            Text("Load the full official AI service list from \(RemoteServicesLoader.sourceURL.absoluteString). You only need to do this once, and it will be cached for later launches.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section(editingCustomServiceID == nil ? "Add Custom Service" : "Edit Custom Service") {
                        TextField("Service ID", text: $draftID)
                            .disabled(editingCustomServiceID != nil)
                        TextField("Display name", text: $draftName)
                        TextField("https://service-url.example", text: $draftURL)
                        TextField("Subtitle", text: $draftSubtitle)
                        TextField("Symbol name", text: $draftSymbolName)
                        TextField("Accent hex", text: $draftAccentHex)

                        HStack {
                            Button(editingCustomServiceID == nil ? "Add Service" : "Save Changes") {
                                saveCustomService()
                            }
                            .disabled(!isDraftReady)

                            if editingCustomServiceID != nil {
                                Button("Cancel") {
                                    resetDraft()
                                }
                            }
                        }

                        Text("Custom services can be regular websites too, like Gmail. Only HTTPS URLs are allowed, and non-trusted domains will trigger a warning before opening.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if isCompactSidebar {
                    ForEach(appModel.services) { service in
                        Button {
                            appModel.select(serviceID: service.id)
                        } label: {
                            Image(systemName: service.symbolName)
                                .foregroundStyle(service.accentColor)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(height: 28)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .tag(service.id)
                        .help(service.name)
                    }
                } else {
                    Section("AI Services") {
                        ForEach(appModel.services) { service in
                            Button {
                                appModel.select(serviceID: service.id)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: service.symbolName)
                                        .foregroundStyle(service.accentColor)
                                        .frame(width: 24)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(service.name)
                                        Text(service.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .tag(service.id)
                        }
                    }
                }

                if isCompactSidebar {
                    Section {
                        Color.clear
                            .frame(height: 10)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowBackground(Color.clear)
                    }

                    Section {
                        Button {
                            isEditingEnabledServices.toggle()
                        } label: {
                            Image(systemName: "slider.vertical.3")
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(height: 28)
                                .contentShape(Rectangle())
                        }
                        .help(isEditingEnabledServices ? "Finish editing visible services" : "Edit visible services")
                        .buttonStyle(.plain)

                        Button {
                            showingServiceManager = true
                        } label: {
                            Image(systemName: "sparkle.text.clipboard")
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(height: 28)
                                .contentShape(Rectangle())
                        }
                        .help("Manage custom services")
                        .buttonStyle(.plain)

                        SettingsLink {
                            Image(systemName: "gearshape")
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(height: 28)
                                .contentShape(Rectangle())
                        }
                        .help("Open settings")
                        .buttonStyle(.plain)
                    }
                } else {
                    Section("Custom") {
                        VStack(spacing: 14) {
                            Button {
                                isEditingEnabledServices.toggle()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "slider.vertical.3")
                                        .frame(width: 24)
                                    Text(isEditingEnabledServices ? "Done Editing" : "Edit Visible Services")
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .help(isEditingEnabledServices ? "Finish editing visible services" : "Edit visible services")
                            .buttonStyle(.plain)

                            Button {
                                showingServiceManager = true
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "sparkle.text.clipboard")
                                        .frame(width: 24)
                                    Text("Manage Custom Services")
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .help("Manage custom services")
                            .buttonStyle(.plain)

                            SettingsLink {
                                HStack(spacing: 12) {
                                    Image(systemName: "gearshape")
                                        .frame(width: 24)
                                    Text("Settings")
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .help("Open settings")
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .sheet(isPresented: $showingServiceManager) {
            ServiceManagerView()
                .environmentObject(appModel)
        }
        .alert("Add Service Error", isPresented: addErrorBinding) {
            Button("OK") {
                addErrorMessage = nil
            }
        } message: {
            Text(addErrorMessage ?? "Unknown error")
        }
        .alert("Load Official AI Catalog?", isPresented: $confirmingOfficialCatalogLoad) {
            Button("Load") {
                loadOfficialCatalog()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will download the official catalog from \(RemoteServicesLoader.sourceURL.absoluteString) and store it locally for future launches.")
        }
    }

    private var selectionBinding: Binding<String?> {
        Binding(
            get: { appModel.selectedServiceID },
            set: { newValue in
                guard let newValue else { return }
                appModel.select(serviceID: newValue)
            }
        )
    }

    private var isDraftReady: Bool {
        !draftID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !draftURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var addErrorBinding: Binding<Bool> {
        Binding(
            get: { addErrorMessage != nil },
            set: { if !$0 { addErrorMessage = nil } }
        )
    }

    private func saveCustomService() {
        do {
            if let editingCustomServiceID {
                let service = try ServiceSecurity.validatedService(
                    id: editingCustomServiceID,
                    name: draftName,
                    url: draftURL,
                    subtitle: draftSubtitle,
                    symbolName: draftSymbolName,
                    accentHex: draftAccentHex
                )
                appModel.updateCustomService(service)
            } else {
                try appModel.addCustomService(
                    id: draftID,
                    name: draftName,
                    url: draftURL,
                    subtitle: draftSubtitle,
                    symbolName: draftSymbolName,
                    accentHex: draftAccentHex
                )
            }
            resetDraft()
        } catch {
            addErrorMessage = error.localizedDescription
        }
    }

    private func startEditing(_ service: AIService) {
        editingCustomServiceID = service.id
        draftID = service.id
        draftName = service.name
        draftURL = service.url
        draftSubtitle = service.subtitle
        draftSymbolName = service.symbolName
        draftAccentHex = service.accentHex
    }

    private func resetDraft() {
        editingCustomServiceID = nil
        draftID = ""
        draftName = ""
        draftURL = ""
        draftSubtitle = ""
        draftSymbolName = "globe"
        draftAccentHex = "#2563EB"
    }

    private func loadOfficialCatalog() {
        loadingOfficialCatalog = true
        Task {
            do {
                try await appModel.refreshBuiltInServices()
            } catch {
                await MainActor.run {
                    addErrorMessage = error.localizedDescription
                }
            }

            await MainActor.run {
                loadingOfficialCatalog = false
            }
        }
    }
}
