import AppKit
import Foundation

struct ShortcutDescriptor: Codable, Equatable {
    var key: String
    var command: Bool
    var option: Bool
    var control: Bool
    var shift: Bool

    func matches(_ event: NSEvent) -> Bool {
        guard let pressed = event.charactersIgnoringModifiers?.lowercased(), !key.isEmpty else {
            return false
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        return pressed == key.lowercased()
            && flags.contains(.command) == command
            && flags.contains(.option) == option
            && flags.contains(.control) == control
            && flags.contains(.shift) == shift
    }

    var displayString: String {
        var parts: [String] = []
        if command { parts.append("Cmd") }
        if option { parts.append("Opt") }
        if control { parts.append("Ctrl") }
        if shift { parts.append("Shift") }
        parts.append(key.uppercased())
        return parts.joined(separator: "+")
    }

    static let nextDefault = ShortcutDescriptor(
        key: "]",
        command: true,
        option: false,
        control: false,
        shift: true
    )

    static let previousDefault = ShortcutDescriptor(
        key: "[",
        command: true,
        option: false,
        control: false,
        shift: true
    )
}
