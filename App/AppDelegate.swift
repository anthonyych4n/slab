import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {

    private var menuBarController: MenuBarController!
    private var windowManager: WindowManager!
    private var snapDetector: SnapDetector!
    private var snapAssist: SnapAssistController!
    private var hotkeyManager: HotkeyManager!
    private var preferencesWindow: PreferencesWindow?
    private var layoutPickerWindow: LayoutPickerWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
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
        snapAssist?.dismiss()
    }

    private func initializeManagers() {
        windowManager = WindowManager()
        snapAssist = SnapAssistController(windowManager: windowManager)
        layoutPickerWindow = LayoutPickerWindow(windowManager: windowManager)

        snapDetector = SnapDetector(windowManager: windowManager)
        snapDetector.onDidSnap = { [weak self] layout, zone, window, screen in
            self?.snapAssist.begin(
                layout: layout,
                filledZone: zone,
                filledWindow: window,
                screen: screen
            )
        }
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
        case .restoreGroup: wm.groupStore.restoreLast(using: wm)
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
    func menuBarDidRequestRestoreGroup() {
        guard let wm = windowManager else { return }
        wm.groupStore.restoreLast(using: wm)
    }
    func menuBarHasRestorableGroup() -> Bool {
        windowManager?.groupStore.hasRestorableGroup ?? false
    }
}
