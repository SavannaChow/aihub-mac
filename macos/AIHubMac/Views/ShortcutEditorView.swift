import SwiftUI

struct ShortcutEditorView: View {
    let title: String
    @Binding var shortcut: ShortcutDescriptor

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))

            HStack {
                TextField(
                    "Key",
                    text: Binding(
                        get: { shortcut.key },
                        set: { shortcut.key = String($0.prefix(1)).lowercased() }
                    )
                )
                .frame(width: 48)
                .textFieldStyle(.roundedBorder)

                Toggle("Cmd", isOn: $shortcut.command)
                    .toggleStyle(.checkbox)
                Toggle("Opt", isOn: $shortcut.option)
                    .toggleStyle(.checkbox)
                Toggle("Ctrl", isOn: $shortcut.control)
                    .toggleStyle(.checkbox)
                Toggle("Shift", isOn: $shortcut.shift)
                    .toggleStyle(.checkbox)

                Spacer()

                Text(shortcut.displayString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
