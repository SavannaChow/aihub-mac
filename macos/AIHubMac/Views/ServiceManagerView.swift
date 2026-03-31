import SwiftUI
import UniformTypeIdentifiers

struct ServiceManagerView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var draftID = ""
    @State private var draftName = ""
    @State private var draftURL = ""
    @State private var draftSubtitle = ""
    @State private var draftSymbolName = "globe"
    @State private var draftAccentHex = "#2563EB"
    @State private var editingCustomServiceID: String?
    @State private var importing = false
    @State private var exporting = false
    @State private var confirmingRefresh = false
    @State private var refreshingCatalog = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Manage Services")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button("Done") { dismiss() }
            }

            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Custom Services")
                        .font(.headline)

                    List {
                        ForEach(appModel.customServices) { service in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(service.name)
                                    Text(service.url)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Button {
                                    startEditing(service)
                                } label: {
                                    Image(systemName: "pencil")
                                }
                                .buttonStyle(.borderless)
                                .help("Edit custom service")
                            }
                        }
                        .onDelete(perform: appModel.removeCustomServices)
                    }
                    .frame(minWidth: 280, minHeight: 260)

                    HStack {
                        Button("Import JSON") {
                            importing = true
                        }
                        Button("Export All") {
                            exporting = true
                        }
                        Button("Refresh Official Catalog") {
                            confirmingRefresh = true
                        }
                        .disabled(refreshingCatalog)
                    }

                    Text("Official catalog source: \(RemoteServicesLoader.sourceURL.absoluteString)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Text(editingCustomServiceID == nil ? "Add Custom Service" : "Edit Custom Service")
                        .font(.headline)

                    TextField("id", text: $draftID)
                        .disabled(editingCustomServiceID != nil)
                    TextField("name", text: $draftName)
                    TextField("url", text: $draftURL)
                    TextField("subtitle", text: $draftSubtitle)
                    TextField("symbol name", text: $draftSymbolName)
                    TextField("accent hex", text: $draftAccentHex)

                    HStack {
                        Button(editingCustomServiceID == nil ? "Add Service" : "Save Changes") {
                            saveDraft()
                        }
                        .disabled(!isDraftValid)

                        if editingCustomServiceID != nil {
                            Button("Cancel") {
                                resetDraft()
                            }
                        }
                    }

                    Text("Import/export format is a plain JSON array of `AIService` objects. Imported services are validated to HTTPS URLs before they are added.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 280)
            }
        }
        .padding(20)
        .fileImporter(
            isPresented: $importing,
            allowedContentTypes: [UTType.json]
        ) { result in
            do {
                let url = try result.get()
                try appModel.importServices(from: url)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        .fileExporter(
            isPresented: $exporting,
            document: appModel.exportDocument(),
            contentType: .json,
            defaultFilename: "aihub-services"
        ) { result in
            if case .failure(let error) = result {
                errorMessage = error.localizedDescription
            }
        }
        .alert("Refresh Official Catalog?", isPresented: $confirmingRefresh) {
            Button("Refresh") {
                refreshOfficialCatalog()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will download the latest official service list from \(RemoteServicesLoader.sourceURL.absoluteString). Continue only if you trust that source.")
        }
        .alert("Service Manager Error", isPresented: errorBinding) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    private var isDraftValid: Bool {
        !draftID.isEmpty && !draftName.isEmpty && !draftURL.isEmpty
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func saveDraft() {
        guard isDraftValid else { return }
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
            errorMessage = error.localizedDescription
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

    private func refreshOfficialCatalog() {
        refreshingCatalog = true
        Task {
            do {
                try await appModel.refreshBuiltInServices()
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }

            await MainActor.run {
                refreshingCatalog = false
            }
        }
    }
}
