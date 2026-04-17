import Foundation
import ServiceManagement

enum Defaults {

    // MARK: - General

    static var isFirstLaunch: Bool {
        get { UserDefaults.standard.object(forKey: "isFirstLaunch") == nil
              || UserDefaults.standard.bool(forKey: "isFirstLaunch") }
        set { UserDefaults.standard.set(newValue, forKey: "isFirstLaunch") }
    }

    static var snapOnDragEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "snapOnDragEnabled").map { $0 as! Bool } ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "snapOnDragEnabled") }
    }

    /// Width/height of hot zone area at screen edges, in points.
    static var hotZoneThreshold: CGFloat {
        get {
            let v = UserDefaults.standard.double(forKey: "hotZoneThreshold")
            return v > 0 ? CGFloat(v) : 20.0
        }
        set { UserDefaults.standard.set(Double(newValue), forKey: "hotZoneThreshold") }
    }

    // MARK: - Custom Layouts

    static var customLayouts: [CustomLayout] {
        get {
            guard let data = UserDefaults.standard.data(forKey: "customLayouts"),
                  let layouts = try? JSONDecoder().decode([CustomLayout].self, from: data)
            else { return [] }
            return layouts
        }
        set {
            let data = try? JSONEncoder().encode(newValue)
            UserDefaults.standard.set(data, forKey: "customLayouts")
        }
    }

    // MARK: - Config Import / Export

    private struct Config: Codable {
        var hotZoneThreshold: Double
        var snapOnDragEnabled: Bool
        var customLayouts: [CustomLayout]
    }

    static func exportConfig(to url: URL) throws {
        let config = Config(
            hotZoneThreshold: Double(hotZoneThreshold),
            snapOnDragEnabled: snapOnDragEnabled,
            customLayouts: customLayouts
        )
        let data = try JSONEncoder().encode(config)
        try data.write(to: url)
    }

    static func importConfig(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let config = try JSONDecoder().decode(Config.self, from: data)
        hotZoneThreshold   = CGFloat(config.hotZoneThreshold)
        snapOnDragEnabled  = config.snapOnDragEnabled
        customLayouts      = config.customLayouts
    }

    // MARK: - Launch at Login

    static var launchAtLogin: Bool {
        get {
            if #available(macOS 13, *) {
                return SMAppService.mainApp.status == .enabled
            }
            return false
        }
        set {
            if #available(macOS 13, *) {
                do {
                    if newValue { try SMAppService.mainApp.register() }
                    else        { try SMAppService.mainApp.unregister() }
                } catch {
                    print("[Slab] Launch-at-login error: \(error)")
                }
            }
        }
    }
}
