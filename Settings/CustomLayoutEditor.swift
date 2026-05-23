import SwiftUI

// MARK: - Editor sheet

/// Modal editor for creating or modifying a custom layout. Two panels:
///   • Canvas — visual editing with selectable, draggable, resizable zones.
///   • Inspector — numeric X/Y/W/H percentage fields for the selected zone.
///
/// The two panels stay in sync via shared state, so users can drag a corner
/// to coarse-position and then type exact values for fine-tuning.
struct CustomLayoutEditor: View {
    @Binding var isPresented: Bool
    /// Pass nil to create a new layout, or an existing one to edit it.
    let editing: CustomLayout?
    let onSave: (CustomLayout) -> Void

    @State private var name: String = "Custom Layout"
    @State private var zones: [EditableZone] = []
    @State private var selectedZoneID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                canvasPanel
                Divider()
                inspector
                    .frame(width: 240)
            }
            Divider()
            toolbar
        }
        .frame(width: 760, height: 500)
        .onAppear(perform: bootstrap)
    }

    // MARK: Bootstrap

    private func bootstrap() {
        if let layout = editing {
            name = layout.name
            zones = layout.zones.map(EditableZone.init(from:))
            selectedZoneID = zones.first?.id
        } else {
            // Sensible starter: left/right halves. Users typically iterate
            // from a working layout rather than starting from empty.
            zones = [
                EditableZone(label: "Left",  unitRect: CGRect(x: 0,   y: 0, width: 0.5, height: 1)),
                EditableZone(label: "Right", unitRect: CGRect(x: 0.5, y: 0, width: 0.5, height: 1)),
            ]
            selectedZoneID = zones.first?.id
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "rectangle.dashed.badge.record")
                .foregroundStyle(Color.accentColor)
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(editing == nil ? "New Custom Layout" : "Edit Custom Layout")
                    .font(.headline)
                Text("Drag a zone to move it. Drag a corner to resize. Or type exact values.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Cancel") { isPresented = false }
                .keyboardShortcut(.cancelAction)
            Button("Save") { save() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(zones.isEmpty || name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: Canvas

    private var canvasPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Name field above the canvas — it's part of the layout's
            // identity, not just a metadata field, so foreground it.
            HStack {
                Text("Name")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("Layout name", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            // 16:10 aspect ratio canvas. Fixed-aspect mock-display rather
            // than the user's actual screen size so the editor reads the
            // same on any monitor.
            GeometryReader { geo in
                let canvas = aspectFitRect(in: geo.size, aspect: 16.0 / 10.0)
                ZStack(alignment: .topLeading) {
                    // Background canvas
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color.secondary.opacity(0.25), lineWidth: 1)
                        )
                        .frame(width: canvas.width, height: canvas.height)
                        .position(x: canvas.midX, y: canvas.midY)
                        // Tap on empty canvas deselects.
                        .onTapGesture { selectedZoneID = nil }

                    // Zones
                    ForEach($zones) { $zone in
                        ZoneCanvasView(
                            zone: $zone,
                            canvas: canvas,
                            isSelected: zone.id == selectedZoneID,
                            onSelect: { selectedZoneID = zone.id }
                        )
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .frame(minHeight: 280)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
    }

    /// Fit a target aspect inside available size, returning the framed rect.
    private func aspectFitRect(in size: CGSize, aspect: CGFloat) -> CGRect {
        let availableAspect = size.width / size.height
        if availableAspect > aspect {
            // Constrained by height
            let h = size.height
            let w = h * aspect
            return CGRect(x: (size.width - w) / 2, y: 0, width: w, height: h)
        } else {
            let w = size.width
            let h = w / aspect
            return CGRect(x: 0, y: (size.height - h) / 2, width: w, height: h)
        }
    }

    // MARK: Inspector

    private var inspector: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Zones")
                .font(.headline)
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 6)

            // Zone list
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(zones) { zone in
                        zoneListRow(zone)
                    }
                }
                .padding(.horizontal, 8)
            }
            .frame(maxHeight: 160)

            Divider().padding(.vertical, 8)

            // Detail editor for selected zone
            if let idx = zones.firstIndex(where: { $0.id == selectedZoneID }) {
                zoneInspector(boundZone: $zones[idx])
            } else {
                Text("Select a zone to edit its dimensions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                Spacer()
            }
        }
    }

    private func zoneListRow(_ zone: EditableZone) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.accentColor.opacity(zone.id == selectedZoneID ? 0.65 : 0.30))
                .frame(width: 12, height: 12)
            Text(zone.label.isEmpty ? "Untitled" : zone.label)
                .font(.system(size: 12))
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(zone.id == selectedZoneID ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { selectedZoneID = zone.id }
    }

    private func zoneInspector(boundZone: Binding<EditableZone>) -> some View {
        // Percentage values shown directly; clamping happens in EditableZone's
        // setters so users can't type invalid values.
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Label").font(.caption).foregroundStyle(.secondary).frame(width: 50, alignment: .leading)
                TextField("Label", text: boundZone.label)
                    .textFieldStyle(.roundedBorder)
            }
            percentField("X",      value: boundZone.unitX)
            percentField("Y",      value: boundZone.unitY)
            percentField("Width",  value: boundZone.unitW)
            percentField("Height", value: boundZone.unitH)
        }
        .padding(14)
    }

    private func percentField(_ label: String, value: Binding<CGFloat>) -> some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(.secondary).frame(width: 50, alignment: .leading)
            TextField("", value: Binding(
                get: { value.wrappedValue * 100 },
                set: { value.wrappedValue = clamp01($0 / 100) }
            ), format: .number.precision(.fractionLength(0...2)))
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
            Text("%").font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: Toolbar

    private var toolbar: some View {
        HStack(spacing: 8) {
            Button { addZone() } label: {
                Label("Add Zone", systemImage: "plus.rectangle")
            }
            Button { splitSelected(horizontal: true) } label: {
                Label("Split Horizontal", systemImage: "rectangle.split.1x2")
            }
            .disabled(selectedZoneID == nil)
            Button { splitSelected(horizontal: false) } label: {
                Label("Split Vertical", systemImage: "rectangle.split.2x1")
            }
            .disabled(selectedZoneID == nil)
            Spacer()
            Button(role: .destructive) { deleteSelected() } label: {
                Label("Delete Zone", systemImage: "trash")
            }
            .disabled(selectedZoneID == nil || zones.count <= 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: Actions

    private func addZone() {
        // Drop a new 30%×30% zone in the middle of the canvas. User can drag
        // it or re-type to wherever they want.
        let new = EditableZone(
            label: "Zone \(zones.count + 1)",
            unitRect: CGRect(x: 0.35, y: 0.35, width: 0.3, height: 0.3)
        )
        zones.append(new)
        selectedZoneID = new.id
    }

    private func splitSelected(horizontal: Bool) {
        guard let id = selectedZoneID,
              let idx = zones.firstIndex(where: { $0.id == id }) else { return }
        let zone = zones[idx]
        if horizontal {
            // Horizontal split = a top half and a bottom half (cut along Y).
            let topRect = CGRect(x: zone.unitRect.minX,
                                 y: zone.unitRect.minY + zone.unitRect.height / 2,
                                 width: zone.unitRect.width,
                                 height: zone.unitRect.height / 2)
            let botRect = CGRect(x: zone.unitRect.minX,
                                 y: zone.unitRect.minY,
                                 width: zone.unitRect.width,
                                 height: zone.unitRect.height / 2)
            let top = EditableZone(label: "\(zone.label) Top",    unitRect: topRect)
            let bot = EditableZone(label: "\(zone.label) Bottom", unitRect: botRect)
            zones.remove(at: idx)
            zones.insert(contentsOf: [top, bot], at: idx)
            selectedZoneID = top.id
        } else {
            let leftRect  = CGRect(x: zone.unitRect.minX,
                                   y: zone.unitRect.minY,
                                   width: zone.unitRect.width / 2,
                                   height: zone.unitRect.height)
            let rightRect = CGRect(x: zone.unitRect.minX + zone.unitRect.width / 2,
                                   y: zone.unitRect.minY,
                                   width: zone.unitRect.width / 2,
                                   height: zone.unitRect.height)
            let left  = EditableZone(label: "\(zone.label) Left",  unitRect: leftRect)
            let right = EditableZone(label: "\(zone.label) Right", unitRect: rightRect)
            zones.remove(at: idx)
            zones.insert(contentsOf: [left, right], at: idx)
            selectedZoneID = left.id
        }
    }

    private func deleteSelected() {
        guard let id = selectedZoneID,
              let idx = zones.firstIndex(where: { $0.id == id }) else { return }
        zones.remove(at: idx)
        selectedZoneID = zones.first?.id
    }

    private func save() {
        let layout = CustomLayout(
            id: editing?.id ?? UUID().uuidString,
            name: name.trimmingCharacters(in: .whitespaces),
            icon: "rectangle.dashed",
            zones: zones.map { $0.toLayoutZone() }
        )
        onSave(layout)
        isPresented = false
    }
}

// MARK: - Editable zone (working model)

/// Mutable working model used by the editor. Converted to `LayoutZone`
/// (which is immutable) on save. Uses individual percentage accessors so
/// the inspector can two-way bind each field independently.
struct EditableZone: Identifiable {
    let id: UUID
    var label: String
    var unitRect: CGRect

    init(id: UUID = UUID(), label: String, unitRect: CGRect) {
        self.id = id
        self.label = label
        self.unitRect = unitRect
    }

    init(from zone: LayoutZone) {
        // Use the saved id only if it parses as a UUID; legacy ids (e.g.
        // "left", "right" from built-in layouts) get a fresh UUID so the
        // editor's internal Identifiable behavior stays consistent.
        self.id = UUID(uuidString: zone.id) ?? UUID()
        self.label = zone.label
        self.unitRect = zone.unitRect
    }

    func toLayoutZone() -> LayoutZone {
        LayoutZone(id: id.uuidString, label: label, unitRect: unitRect)
    }

    // Two-way accessors so the numeric inspector can edit individual axes.
    var unitX: CGFloat {
        get { unitRect.minX }
        set { unitRect.origin.x = clamp01(newValue) }
    }
    var unitY: CGFloat {
        get { unitRect.minY }
        set { unitRect.origin.y = clamp01(newValue) }
    }
    var unitW: CGFloat {
        get { unitRect.width }
        set { unitRect.size.width = clamp01(max(0.05, newValue)) }
    }
    var unitH: CGFloat {
        get { unitRect.height }
        set { unitRect.size.height = clamp01(max(0.05, newValue)) }
    }
}

// MARK: - Canvas zone (with drag-move + corner-resize)

private struct ZoneCanvasView: View {
    @Binding var zone: EditableZone
    let canvas: CGRect
    let isSelected: Bool
    let onSelect: () -> Void

    /// Cached unitRect at the start of a gesture so deltas apply against a
    /// stable baseline instead of accumulating.
    @State private var gestureStart: CGRect?

    var body: some View {
        // unitRect is Y-up; the canvas is Y-down. Flip when projecting.
        let frame = projected(zone.unitRect, into: canvas)

        ZStack {
            // Zone body
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.accentColor.opacity(isSelected ? 0.30 : 0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(
                            Color.accentColor.opacity(isSelected ? 0.95 : 0.55),
                            lineWidth: isSelected ? 1.5 : 1.0
                        )
                )
            // Label
            Text(zone.label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.primary)
                .padding(.horizontal, 4)
                .lineLimit(1)
        }
        .frame(width: frame.width, height: frame.height)
        .position(x: frame.midX, y: frame.midY)
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .gesture(moveGesture(currentFrame: frame))
        .overlay(alignment: .topLeading) {
            if isSelected {
                // Four corner handles. Each resizes the zone toward the
                // canvas corner it represents — top-left moves origin and
                // shrinks size, bottom-right just grows size, etc.
                ZStack {
                    handle(at: .topLeading,     frame: frame)
                    handle(at: .topTrailing,    frame: frame)
                    handle(at: .bottomLeading,  frame: frame)
                    handle(at: .bottomTrailing, frame: frame)
                }
            }
        }
    }

    private func handle(at corner: Corner, frame: CGRect) -> some View {
        let p = cornerPoint(corner, in: frame)
        return Circle()
            .fill(Color.accentColor)
            .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
            .frame(width: 10, height: 10)
            .position(x: p.x - frame.minX, y: p.y - frame.minY)
            .gesture(resizeGesture(corner: corner, currentFrame: frame))
    }

    // MARK: Gestures

    private func moveGesture(currentFrame: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                onSelect()
                if gestureStart == nil { gestureStart = zone.unitRect }
                guard let start = gestureStart else { return }
                // Translation comes in SwiftUI's Y-down space. Convert to
                // unit deltas, flipping Y for the unitRect's Y-up convention.
                let dx = value.translation.width  / canvas.width
                let dy = -value.translation.height / canvas.height
                var r = start
                r.origin.x = clamp01(start.origin.x + dx)
                r.origin.y = clamp01(start.origin.y + dy)
                // Don't let the zone slide past the canvas edge.
                r.origin.x = min(r.origin.x, 1 - r.width)
                r.origin.y = min(r.origin.y, 1 - r.height)
                zone.unitRect = r
            }
            .onEnded { _ in gestureStart = nil }
    }

    private func resizeGesture(corner: Corner, currentFrame: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if gestureStart == nil { gestureStart = zone.unitRect }
                guard let start = gestureStart else { return }
                let dx = value.translation.width  / canvas.width
                let dy = -value.translation.height / canvas.height
                var r = start
                let minSize: CGFloat = 0.05
                switch corner {
                case .topLeading:
                    // Move left edge, raise top (Y-up = grow Y/H from top).
                    r.origin.x   = clamp01(min(start.origin.x + dx, start.maxX - minSize))
                    let newWidth = clamp01(start.width - dx)
                    r.size.width = max(minSize, newWidth)
                    let newHeight = clamp01(start.height + dy)
                    r.size.height = max(minSize, newHeight)
                case .topTrailing:
                    let newWidth = clamp01(start.width + dx)
                    r.size.width = max(minSize, newWidth)
                    let newHeight = clamp01(start.height + dy)
                    r.size.height = max(minSize, newHeight)
                case .bottomLeading:
                    r.origin.x   = clamp01(min(start.origin.x + dx, start.maxX - minSize))
                    let newWidth = clamp01(start.width - dx)
                    r.size.width = max(minSize, newWidth)
                    r.origin.y   = clamp01(min(start.origin.y - dy, start.maxY - minSize))
                    let newHeight = clamp01(start.height + dy)
                    r.size.height = max(minSize, newHeight)
                case .bottomTrailing:
                    let newWidth = clamp01(start.width + dx)
                    r.size.width = max(minSize, newWidth)
                    r.origin.y   = clamp01(min(start.origin.y - dy, start.maxY - minSize))
                    let newHeight = clamp01(start.height + dy)
                    r.size.height = max(minSize, newHeight)
                }
                // Final clamp so we never extend past the canvas.
                r.size.width  = min(r.size.width,  1 - r.origin.x)
                r.size.height = min(r.size.height, 1 - r.origin.y)
                zone.unitRect = r
            }
            .onEnded { _ in gestureStart = nil }
    }

    // MARK: Projection

    /// Map a unitRect (Y-up, 0..1) into the canvas's pixel coordinates
    /// (Y-down). The canvas rect is the actual drawn frame within its
    /// parent GeometryReader.
    private func projected(_ unit: CGRect, into canvas: CGRect) -> CGRect {
        CGRect(
            x: canvas.minX + unit.minX * canvas.width,
            y: canvas.minY + (1 - unit.minY - unit.height) * canvas.height,
            width: unit.width  * canvas.width,
            height: unit.height * canvas.height
        )
    }

    private func cornerPoint(_ corner: Corner, in r: CGRect) -> CGPoint {
        switch corner {
        case .topLeading:     return CGPoint(x: r.minX, y: r.minY)
        case .topTrailing:    return CGPoint(x: r.maxX, y: r.minY)
        case .bottomLeading:  return CGPoint(x: r.minX, y: r.maxY)
        case .bottomTrailing: return CGPoint(x: r.maxX, y: r.maxY)
        }
    }

    private enum Corner { case topLeading, topTrailing, bottomLeading, bottomTrailing }
}

// MARK: - Helpers

private func clamp01(_ v: CGFloat) -> CGFloat { max(0, min(1, v)) }
