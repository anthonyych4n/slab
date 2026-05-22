import Cocoa

protocol MenuBarControllerDelegate: AnyObject {
    func menuBarDidRequestLayoutPicker()
    func menuBarDidRequestPreferences()
    func menuBarDidRequestRestoreGroup()
    func menuBarHasRestorableGroup() -> Bool
}

final class MenuBarController: NSObject, NSMenuDelegate {

    weak var delegate: MenuBarControllerDelegate?
    private var statusItem: NSStatusItem!

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem.button else {
            print("[Slab] ERROR: statusItem.button is nil")
            return
        }

        // Template SF Symbol — auto-tints to match the menu bar in light/dark
        // mode and feels native compared to a plain text label. Falls back to
        // the text title only if the symbol isn't available (very old systems).
        if let image = NSImage(systemSymbolName: "rectangle.split.2x1",
                               accessibilityDescription: "Slab") {
            image.isTemplate = true
            button.image = image
            button.title = ""
        } else {
            button.title = "Slab"
        }
        button.toolTip = "Slab – Window Snap"

        let menu = buildMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    // MARK: - Menu

    private func buildMenu() -> NSMenu {
        let menu = NSMenu(title: "Slab")

        // Snap toggle
        let snapItem = NSMenuItem(title: "Snap on Drag", action: #selector(toggleSnap), keyEquivalent: "")
        snapItem.target = self
        snapItem.state = Defaults.snapOnDragEnabled ? .on : .off
        menu.addItem(snapItem)

        menu.addItem(.separator())

        // Layout picker
        let pickerItem = NSMenuItem(title: "Open Layout Picker", action: #selector(openPicker), keyEquivalent: "l")
        pickerItem.keyEquivalentModifierMask = [.control, .option]
        pickerItem.target = self
        menu.addItem(pickerItem)

        // Restore last snap group (disabled when there's nothing to restore)
        let restoreItem = NSMenuItem(title: "Restore Last Snap Group",
                                     action: #selector(restoreGroup),
                                     keyEquivalent: "g")
        restoreItem.keyEquivalentModifierMask = [.control, .option]
        restoreItem.target = self
        restoreItem.isEnabled = delegate?.menuBarHasRestorableGroup() ?? false
        menu.addItem(restoreItem)

        // Shortcuts reference (disabled = just a label)
        let hintItem = NSMenuItem(title: "⌃⌥ ← → ↑ ↓  Snap  |  ⌃⌥Z Unsnap", action: nil, keyEquivalent: "")
        hintItem.isEnabled = false
        menu.addItem(hintItem)

        menu.addItem(.separator())

        // Preferences
        let prefsItem = NSMenuItem(title: "Preferences…", action: #selector(openPrefs), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

        // Launch at login
        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLogin), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = Defaults.launchAtLogin ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Quit Slab", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        return menu
    }

    // Rebuild menu each time it opens so state is always fresh
    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()
        let fresh = buildMenu()
        for item in fresh.items {
            let copy = item.copy() as! NSMenuItem
            menu.addItem(copy)
        }
    }

    // MARK: - Actions

    @objc private func toggleSnap() {
        Defaults.snapOnDragEnabled.toggle()
    }

    @objc private func openPicker() {
        delegate?.menuBarDidRequestLayoutPicker()
    }

    @objc private func restoreGroup() {
        delegate?.menuBarDidRequestRestoreGroup()
    }

    @objc private func openPrefs() {
        delegate?.menuBarDidRequestPreferences()
    }

    @objc private func toggleLogin() {
        Defaults.launchAtLogin.toggle()
    }
}
