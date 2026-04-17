import Cocoa
import ApplicationServices

final class PermissionsChecker {

    private static var pollTimer: Timer?
    private static var onGranted: (() -> Void)?

    /// Call once at launch. If access is already granted, `onGranted` fires immediately.
    /// Otherwise prompts the user and polls until granted.
    static func requestIfNeeded(onGranted: @escaping () -> Void) {
        self.onGranted = onGranted

        if AXIsProcessTrusted() {
            onGranted()
            return
        }

        // Prompt once — opens System Settings → Accessibility
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)

        // Poll until the user grants access
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if AXIsProcessTrusted() {
                pollTimer?.invalidate()
                pollTimer = nil
                DispatchQueue.main.async { onGranted() }
            }
        }
    }

    static func isGranted() -> Bool {
        return AXIsProcessTrusted()
    }
}
