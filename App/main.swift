import Cocoa

// Manual app bootstrap — needed for NIB-less menubar apps on macOS 26 SDK.
// @NSApplicationMain and NSApplicationMain() both fail to wire the delegate
// without a storyboard/NIB present.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
