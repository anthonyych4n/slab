import SwiftUI
import Cocoa

struct AppPickerView: View {
    let layout: AnyLayoutTemplate
    let availableWindows: [WindowInfo]
    let onAssign: (LayoutZone, WindowInfo) -> Void
    let onApply: () -> Void
    let onCancel: () -> Void

    @State private var selectedZone: LayoutZone?
    @State private var assignments: [String: WindowInfo] = [:]  // zone.id → WindowInfo

    var body: some View {
        VStack(spacing: 0) {
            // Zone grid
            ZoneGridView(
                layout: layout,
                assignments: assignments,
                selectedZone: selectedZone,
                onZoneTap: { zone in
                    selectedZone = (selectedZone?.id == zone.id) ? nil : zone
                }
            )
            .frame(height: 120)
            .padding(12)

            Divider()

            // Window list
            if let zone = selectedZone {
                Text("Assign to \(zone.label):")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(availableWindows) { win in
                            WindowRow(window: win, isAssigned: assignments.values.contains(win)) {
                                assignments[zone.id] = win
                                onAssign(zone, win)
                                selectedZone = nil
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                }
            } else {
                Text("Tap a zone to assign a window.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Divider()

            // Buttons
            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Apply") { onApply() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(assignments.isEmpty)
            }
            .padding(12)
        }
    }
}

// MARK: - Zone Grid

private struct ZoneGridView: View {
    let layout: AnyLayoutTemplate
    let assignments: [String: WindowInfo]
    let selectedZone: LayoutZone?
    let onZoneTap: (LayoutZone) -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(layout.zones) { zone in
                    let isSelected  = selectedZone?.id == zone.id
                    let isAssigned  = assignments[zone.id] != nil
                    let assignedWin = assignments[zone.id]

                    ZoneCell(
                        zone: zone,
                        size: geo.size,
                        isSelected: isSelected,
                        isAssigned: isAssigned,
                        assignedApp: assignedWin?.appName
                    )
                    .onTapGesture { onZoneTap(zone) }
                }
            }
        }
    }
}

private struct ZoneCell: View {
    let zone: LayoutZone
    let size: CGSize
    let isSelected: Bool
    let isAssigned: Bool
    let assignedApp: String?

    var body: some View {
        let w = zone.unitRect.width  * size.width
        let h = zone.unitRect.height * size.height
        let x = zone.unitRect.minX   * size.width  - size.width  / 2 + w / 2
        let y = -(zone.unitRect.minY * size.height - size.height / 2 + h / 2)

        RoundedRectangle(cornerRadius: 4)
            .fill(fillColor)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(borderColor, lineWidth: isSelected ? 2 : 1)
            )
            .overlay(
                VStack(spacing: 2) {
                    Text(assignedApp ?? zone.label)
                        .font(.system(size: 9))
                        .lineLimit(1)
                        .foregroundStyle(isAssigned ? .primary : .secondary)
                }
            )
            .frame(width: w - 4, height: h - 4)
            .offset(x: x, y: y)
    }

    private var fillColor: Color {
        if isSelected { return Color.accentColor.opacity(0.3) }
        if isAssigned { return Color.accentColor.opacity(0.15) }
        return Color.secondary.opacity(0.08)
    }

    private var borderColor: Color {
        isSelected ? Color.accentColor : Color.secondary.opacity(0.3)
    }
}

// MARK: - Window Row

private struct WindowRow: View {
    let window: WindowInfo
    let isAssigned: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                if let icon = window.appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(window.appName)
                        .font(.system(size: 12, weight: .medium))
                    if !window.windowTitle.isEmpty && window.windowTitle != window.appName {
                        Text(window.windowTitle)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if isAssigned {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isAssigned ? Color.accentColor.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }
}
