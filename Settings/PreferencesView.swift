import SwiftUI
import KeyboardShortcuts

struct PreferencesView: View {

    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("General", systemImage: "gear") }
            HotkeysTab()
                .tabItem { Label("Hotkeys", systemImage: "keyboard") }
            LayoutsTab()
                .tabItem { Label("Layouts", systemImage: "rectangle.split.3x1") }
        }
        .frame(width: 560, height: 480)
        .padding()
    }
}

// MARK: - General Tab

private struct GeneralTab: View {
    @AppStorage("hotZoneThreshold")  private var threshold: Double = 10
    @AppStorage("snapOnDragEnabled") private var snapOnDrag: Bool = true

    // Launch at login uses SMAppService, not AppStorage
    @State private var launchAtLogin = Defaults.launchAtLogin

    var body: some View {
        Form {
            Section("Snapping") {
                Toggle("Snap on drag", isOn: $snapOnDrag)
                    .onChange(of: snapOnDrag) { Defaults.snapOnDragEnabled = $0 }

                HStack {
                    Text("Hot zone size")
                    Slider(value: $threshold, in: 4...30, step: 1)
                    Text("\(Int(threshold)) px")
                        .monospacedDigit()
                        .frame(width: 44, alignment: .trailing)
                }
                .onChange(of: threshold) { Defaults.hotZoneThreshold = CGFloat($0) }
            }

            Section("System") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { Defaults.launchAtLogin = $0 }
            }

            Section("Config") {
                HStack {
                    Button("Export Config…") { exportConfig() }
                    Button("Import Config…") { importConfig() }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func exportConfig() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "slab-config.json"
        panel.allowedContentTypes = [.json]
        if panel.runModal() == .OK, let url = panel.url {
            try? Defaults.exportConfig(to: url)
        }
    }

    private func importConfig() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        if panel.runModal() == .OK, let url = panel.url {
            try? Defaults.importConfig(from: url)
        }
    }
}

// MARK: - Hotkeys Tab

private struct HotkeysTab: View {

    // Group actions for visual structure — half/edge snaps, quadrants, then
    // utilities. Each row in a group uses the KeyboardShortcuts.Recorder,
    // which is the package's built-in capture-keystrokes-into-a-field view.
    var body: some View {
        Form {
            Section("Halves & Full") {
                row(.snapLeft); row(.snapRight); row(.snapTop)
                row(.snapBottom); row(.snapFull)
            }
            Section("Quadrants") {
                row(.snapTopLeft); row(.snapTopRight)
                row(.snapBotLeft); row(.snapBotRight)
            }
            Section("Utilities") {
                row(.openPicker); row(.unsnap); row(.restoreGroup)
            }
            Section {
                HStack {
                    Button("Reset to Defaults", role: .destructive) {
                        HotkeyManager.resetAllToDefaults()
                    }
                    Spacer()
                    Text("Click a row, press a key combo. Backspace clears it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private func row(_ action: HotkeyAction) -> some View {
        KeyboardShortcuts.Recorder(action.displayName, name: action.shortcutName)
    }
}

// MARK: - Layouts Tab

private struct LayoutsTab: View {
    @State private var customLayouts: [CustomLayout] = Defaults.customLayouts
    @State private var editorPresented = false
    /// nil = creating a new layout; non-nil = editing an existing one.
    @State private var editorTarget: CustomLayout?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Built-in Layouts")
                    .font(.headline)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                    ForEach(builtInLayouts) { layout in
                        LayoutThumbnail(layout: layout)
                    }
                }

                Divider().padding(.vertical, 4)

                HStack {
                    Text("Custom Layouts")
                        .font(.headline)
                    Spacer()
                    Button {
                        editorTarget = nil
                        editorPresented = true
                    } label: {
                        Label("Add…", systemImage: "plus")
                    }
                }

                if customLayouts.isEmpty {
                    Text("No custom layouts yet. Click Add… to design one.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                        ForEach(customLayouts) { layout in
                            customLayoutCard(layout)
                        }
                    }
                }
            }
            .padding()
        }
        .sheet(isPresented: $editorPresented) {
            CustomLayoutEditor(
                isPresented: $editorPresented,
                editing: editorTarget,
                onSave: { saveLayout($0) }
            )
        }
    }

    /// Custom layout card with the same thumbnail as built-ins, plus a hover
    /// overlay exposing Edit and Delete affordances.
    private func customLayoutCard(_ layout: CustomLayout) -> some View {
        LayoutThumbnail(layout: AnyLayoutTemplate(layout))
            .overlay(alignment: .topTrailing) {
                Menu {
                    Button("Edit…") {
                        editorTarget = layout
                        editorPresented = true
                    }
                    Button("Delete", role: .destructive) {
                        delete(layout)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .padding(4)
            }
    }

    // MARK: - Persistence

    private func saveLayout(_ layout: CustomLayout) {
        if let idx = customLayouts.firstIndex(where: { $0.id == layout.id }) {
            customLayouts[idx] = layout
        } else {
            customLayouts.append(layout)
        }
        Defaults.customLayouts = customLayouts
    }

    private func delete(_ layout: CustomLayout) {
        customLayouts.removeAll { $0.id == layout.id }
        Defaults.customLayouts = customLayouts
    }
}

// Small thumbnail for a layout. Uses absolute .position() so non-symmetric
// layouts (3-column, Main+Sidebar, quad) render correctly inside the card
// rather than overflowing into adjacent cells.
struct LayoutThumbnail: View {
    let layout: AnyLayoutTemplate

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    Color.clear
                    ForEach(layout.zones) { zone in
                        let w = zone.unitRect.width  * geo.size.width
                        let h = zone.unitRect.height * geo.size.height
                        // unitRect is Y-up; flip into SwiftUI's Y-down space.
                        let x = zone.unitRect.minX * geo.size.width
                        let y = geo.size.height - (zone.unitRect.minY + zone.unitRect.height) * geo.size.height
                        Rectangle()
                            .fill(Color.accentColor.opacity(0.18))
                            .overlay(Rectangle().strokeBorder(Color.accentColor.opacity(0.7), lineWidth: 1))
                            .frame(width: max(0, w - 2), height: max(0, h - 2))
                            .position(x: x + w / 2, y: y + h / 2)
                    }
                }
            }
            .frame(height: 50)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 4))

            Text(layout.name)
                .font(.caption)
                .lineLimit(1)
        }
    }
}
