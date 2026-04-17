import Cocoa
import HotKey

enum HotkeyAction: String, CaseIterable {
    case snapLeft, snapRight, snapTop, snapBottom
    case snapTopLeft, snapTopRight, snapBotLeft, snapBotRight
    case snapFull
    case openPicker
    case unsnap
}

final class HotkeyManager {

    // Strong references — HotKey deregisters on deinit
    private var hotKeys: [HotkeyAction: HotKey] = [:]
    private var lastActionTime: [HotkeyAction: Date] = [:]
    private var cycleState: [HotkeyAction: Int] = [:]

    private typealias Binding = (key: Key, mods: NSEvent.ModifierFlags)

    private let defaults: [HotkeyAction: Binding] = [
        .snapLeft:    (key: .leftArrow,  mods: [.control, .option]),
        .snapRight:   (key: .rightArrow, mods: [.control, .option]),
        .snapTop:     (key: .upArrow,    mods: [.control, .option]),
        .snapBottom:  (key: .downArrow,  mods: [.control, .option]),
        .snapTopLeft: (key: .keypad7,    mods: [.control, .option]),
        .snapTopRight:(key: .keypad9,    mods: [.control, .option]),
        .snapBotLeft: (key: .keypad1,    mods: [.control, .option]),
        .snapBotRight:(key: .keypad3,    mods: [.control, .option]),
        .snapFull:    (key: .return,     mods: [.control, .option]),
        .openPicker:  (key: .l,          mods: [.control, .option]),
        .unsnap:      (key: .z,          mods: [.control, .option]),
    ]

    func setup(handler: @escaping (HotkeyAction) -> Void) {
        for (action, binding) in defaults {
            let hk = HotKey(key: binding.key, modifiers: binding.mods)
            hk.keyDownHandler = { [weak self] in
                self?.handle(action, using: handler)
            }
            hotKeys[action] = hk
        }
    }

    func teardown() {
        hotKeys.removeAll()
    }

    private func handle(_ action: HotkeyAction, using handler: (HotkeyAction) -> Void) {
        handler(action)
    }
}
