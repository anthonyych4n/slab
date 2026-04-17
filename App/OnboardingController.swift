import Cocoa
import SwiftUI

final class OnboardingController {

    private static var window: NSWindow?

    static func show() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to Slab"
        window.contentView = NSHostingView(rootView: OnboardingView())
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }
}

private struct OnboardingView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "rectangle.split.3x1.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 40)
                .foregroundColor(.accentColor)

            Text("Welcome to Slab")
                .font(.largeTitle)
                .bold()

            Text("Slab brings Windows 11-style Snap Layouts to your Mac.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                OnboardingRow(icon: "cursorarrow.motionlines.click",
                              title: "Drag to snap",
                              detail: "Drag any window to a screen edge or corner.")
                OnboardingRow(icon: "square.grid.2x2",
                              title: "Layout picker",
                              detail: "Press ⌃⌥L to open the layout picker.")
                OnboardingRow(icon: "keyboard",
                              title: "Keyboard shortcuts",
                              detail: "Use ⌃⌥← → ↑ ↓ to snap instantly.")
            }
            .padding()
            .background(.quinary, in: RoundedRectangle(cornerRadius: 12))

            Button("Get Started") {
                NSApp.keyWindow?.close()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(32)
        .frame(width: 480, height: 360)
    }
}

private struct OnboardingRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundColor(.accentColor)
            VStack(alignment: .leading) {
                Text(title).bold()
                Text(detail).foregroundStyle(.secondary).font(.caption)
            }
        }
    }
}
