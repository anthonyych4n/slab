import AppKit
import KeyboardShortcuts

// MARK: - Shortcut names

// Each `Name` is the persistent identity of a customizable shortcut. The
// `default:` value is what the user gets on first launch and what "Reset to
// Defaults" restores to. Once a user customizes a shortcut, KeyboardShortcuts
// persists their choice to UserDefaults keyed by the Name's raw value.
extension KeyboardShortcuts.Name {
    static let snapLeft     = Self("snapLeft",     default: .init(.leftArrow,  modifiers: [.control, .option]))
    static let snapRight    = Self("snapRight",    default: .init(.rightArrow, modifiers: [.control, .option]))
    static let snapTop      = Self("snapTop",      default: .init(.upArrow,    modifiers: [.control, .option]))
    static let snapBottom   = Self("snapBottom",   default: .init(.downArrow,  modifiers: [.control, .option]))
    static let snapTopLeft  = Self("snapTopLeft",  default: .init(.keypad7,    modifiers: [.control, .option]))
    static let snapTopRight = Self("snapTopRight", default: .init(.keypad9,    modifiers: [.control, .option]))
    static let snapBotLeft  = Self("snapBotLeft",  default: .init(.keypad1,    modifiers: [.control, .option]))
    static let snapBotRight = Self("snapBotRight", default: .init(.keypad3,    modifiers: [.control, .option]))
    static let snapFull     = Self("snapFull",     default: .init(.return,     modifiers: [.control, .option]))
    static let openPicker   = Self("openPicker",   default: .init(.l,          modifiers: [.control, .option]))
    static let unsnap        = Self("unsnap",        default: .init(.z, modifiers: [.control, .option]))
    static let restoreGroup  = Self("restoreGroup",  default: .init(.g, modifiers: [.control, .option]))
}

// MARK: - Actions

/// User-facing snap actions. `allCases` is the canonical ordering used in the
/// Preferences UI.
enum HotkeyAction: String, CaseIterable, Hashable {
    case snapLeft, snapRight, snapTop, snapBottom
    case snapTopLeft, snapTopRight, snapBotLeft, snapBotRight
    case snapFull
    case openPicker
    case unsnap
    case restoreGroup

    var shortcutName: KeyboardShortcuts.Name {
        switch self {
        case .snapLeft:     return .snapLeft
        case .snapRight:    return .snapRight
        case .snapTop:      return .snapTop
        case .snapBottom:   return .snapBottom
        case .snapTopLeft:  return .snapTopLeft
        case .snapTopRight: return .snapTopRight
        case .snapBotLeft:  return .snapBotLeft
        case .snapBotRight: return .snapBotRight
        case .snapFull:     return .snapFull
        case .openPicker:   return .openPicker
        case .unsnap:       return .unsnap
        case .restoreGroup: return .restoreGroup
        }
    }

    /// Label shown in the Preferences UI.
    var displayName: String {
        switch self {
        case .snapLeft:     return "Snap Left"
        case .snapRight:    return "Snap Right"
        case .snapTop:      return "Snap Up"
        case .snapBottom:   return "Snap Down"
        case .snapTopLeft:  return "Top-Left Quarter"
        case .snapTopRight: return "Top-Right Quarter"
        case .snapBotLeft:  return "Bottom-Left Quarter"
        case .snapBotRight: return "Bottom-Right Quarter"
        case .snapFull:     return "Full Screen"
        case .openPicker:   return "Open Layout Picker"
        case .unsnap:       return "Unsnap"
        case .restoreGroup: return "Restore Last Snap Group"
        }
    }
}

// MARK: - Manager

/// Wires each `HotkeyAction` to a `KeyboardShortcuts.onKeyDown` handler.
/// Handlers persist for the app's lifetime; teardown clears them on quit.
final class HotkeyManager {

    func setup(handler: @escaping (HotkeyAction) -> Void) {
        for action in HotkeyAction.allCases {
            KeyboardShortcuts.onKeyDown(for: action.shortcutName) {
                handler(action)
            }
        }
    }

    func teardown() {
        KeyboardShortcuts.removeAllHandlers()
    }

    /// Wipe any user customizations and restore the built-in defaults for
    /// every action. Used by the "Reset to Defaults" button.
    static func resetAllToDefaults() {
        for action in HotkeyAction.allCases {
            KeyboardShortcuts.reset(action.shortcutName)
        }
    }
}
