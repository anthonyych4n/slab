import Cocoa
import SwiftUI

final class PreferencesWindow: NSWindow {

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 360),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        title = "Slab Preferences"
        contentView = NSHostingView(rootView: PreferencesView())
        center()
        isReleasedWhenClosed = false
    }
}
