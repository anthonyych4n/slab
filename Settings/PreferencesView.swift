import SwiftUI

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
        .frame(width: 520, height: 360)
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
    private let rows: [(String, String)] = [
        ("Snap Left",        "⌃⌥ ←"),
        ("Snap Right",       "⌃⌥ →"),
        ("Snap Up",          "⌃⌥ ↑"),
        ("Snap Down",        "⌃⌥ ↓"),
        ("Top-Left Quarter", "⌃⌥ 7"),
        ("Top-Right Quarter","⌃⌥ 9"),
        ("Bot-Left Quarter", "⌃⌥ 1"),
        ("Bot-Right Quarter","⌃⌥ 3"),
        ("Full Screen",      "⌃⌥ ↩"),
        ("Open Layout Picker","⌃⌥ L"),
        ("Unsnap",           "⌃⌥ Z"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Action").bold()
                Spacer()
                Text("Shortcut").bold()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.08))

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(rows.indices, id: \.self) { i in
                        HStack {
                            Text(rows[i].0)
                            Spacer()
                            Text(rows[i].1)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(i % 2 == 0 ? Color.clear : Color.secondary.opacity(0.04))
                        if i < rows.count - 1 { Divider() }
                    }
                }
            }
            .frame(minHeight: 200)
        }
        .background(Color.secondary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.secondary.opacity(0.15)))
    }
}

// MARK: - Layouts Tab

private struct LayoutsTab: View {
    @State private var customLayouts = Defaults.customLayouts

    var body: some View {
        VStack(alignment: .leading) {
            Text("Built-in Layouts")
                .font(.headline)
                .padding(.bottom, 4)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(builtInLayouts) { layout in
                    LayoutThumbnail(layout: layout)
                }
            }

            Divider().padding(.vertical, 8)

            HStack {
                Text("Custom Layouts")
                    .font(.headline)
                Spacer()
                Button("Add…") { addCustomLayout() }
            }

            if customLayouts.isEmpty {
                Text("No custom layouts yet.")
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            } else {
                List(customLayouts, id: \.id) { layout in
                    HStack {
                        Image(systemName: layout.icon)
                        Text(layout.name)
                        Spacer()
                        Button("Delete") { delete(layout) }
                            .buttonStyle(.plain)
                            .foregroundStyle(.red)
                    }
                }
                .frame(height: 120)
            }
        }
        .padding()
    }

    private func addCustomLayout() {
        let new = CustomLayout(name: "Custom \(customLayouts.count + 1)", zones: [
            LayoutZone(id: "left",  label: "Left",  unitRect: CGRect(x: 0, y: 0, width: 0.5, height: 1)),
            LayoutZone(id: "right", label: "Right", unitRect: CGRect(x: 0.5, y: 0, width: 0.5, height: 1)),
        ])
        customLayouts.append(new)
        Defaults.customLayouts = customLayouts
    }

    private func delete(_ layout: CustomLayout) {
        customLayouts.removeAll { $0.id == layout.id }
        Defaults.customLayouts = customLayouts
    }
}

// Small thumbnail for a layout
struct LayoutThumbnail: View {
    let layout: AnyLayoutTemplate

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack {
                    ForEach(layout.zones) { zone in
                        Rectangle()
                            .fill(Color.accentColor.opacity(0.15))
                            .overlay(Rectangle().strokeBorder(Color.accentColor, lineWidth: 1))
                            .frame(
                                width:  zone.unitRect.width  * geo.size.width,
                                height: zone.unitRect.height * geo.size.height
                            )
                            .offset(
                                x: zone.unitRect.minX * geo.size.width  - geo.size.width  / 2 + zone.unitRect.width  * geo.size.width  / 2,
                                y: -(zone.unitRect.minY * geo.size.height - geo.size.height / 2 + zone.unitRect.height * geo.size.height / 2)
                            )
                    }
                }
            }
            .frame(height: 50)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(4)

            Text(layout.name)
                .font(.caption)
                .lineLimit(1)
        }
    }
}
