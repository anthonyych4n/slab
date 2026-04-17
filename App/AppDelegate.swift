import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {

    private var menuBarController: MenuBarController!
    private var windowManager: WindowManager!
    private var snapDetector: SnapDetector!
    private var hotkeyManager: HotkeyManager!
    private var preferencesWindow: PreferencesWindow?
    private var layoutPickerWindow: LayoutPickerWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        try? "launched".write(toFile: "/tmp/slab_launched.txt", atomically: true, encoding: .utf8)
        NSApp.setActivationPolicy(.accessory)

        menuBarController = MenuBarController()
        menuBarController.delegate = self
        menuBarController.setup()

        PermissionsChecker.requestIfNeeded { [weak self] in
            self?.initializeManagers()
        }

        if Defaults.isFirstLaunch {
            OnboardingController.show()
            Defaults.isFirstLaunch = false
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        snapDetector?.stop()
        hotkeyManager?.teardown()
    }

    private func initializeManagers() {
        windowManager = WindowManager()
        layoutPickerWindow = LayoutPickerWindow(windowManager: windowManager)
        snapDetector = SnapDetector(windowManager: windowManager)
        snapDetector.onRequestLayoutPicker = { [weak self] in self?.showLayoutPicker() }
        snapDetector.start()

        hotkeyManager = HotkeyManager()
        hotkeyManager.setup { [weak self] action in
            self?.handleHotkeyAction(action)
        }
    }

    private func handleHotkeyAction(_ action: HotkeyAction) {
        guard let wm = windowManager else { return }
        switch action {
        case .snapLeft:     wm.snapFrontmost(to: .leftHalf)
        case .snapRight:    wm.snapFrontmost(to: .rightHalf)
        case .snapTop:      wm.snapFrontmost(to: .topHalf)
        case .snapBottom:   wm.snapFrontmost(to: .bottomHalf)
        case .snapTopLeft:  wm.snapFrontmost(to: .topLeft)
        case .snapTopRight: wm.snapFrontmost(to: .topRight)
        case .snapBotLeft:  wm.snapFrontmost(to: .bottomLeft)
        case .snapBotRight: wm.snapFrontmost(to: .bottomRight)
        case .snapFull:     wm.snapFrontmost(to: .full)
        case .openPicker:   showLayoutPicker()
        case .unsnap:       wm.unsnapFrontmost()
        }
    }

    func showLayoutPicker() {
        layoutPickerWindow?.show()
    }

    func showPreferences() {
        if preferencesWindow == nil {
            preferencesWindow = PreferencesWindow()
        }
        preferencesWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension AppDelegate: MenuBarControllerDelegate {
    func menuBarDidRequestLayoutPicker() { showLayoutPicker() }
    func menuBarDidRequestPreferences() { showPreferences() }
}
