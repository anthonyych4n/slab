import XCTest
@testable import Slab

final class LayoutTests: XCTestCase {

    func testZoneFrameCoversFullScreen() {
        guard let screen = NSScreen.main else { return }
        let layout = FullScreenLayout()
        let zone = layout.zones[0]
        let frame = layout.appKitFrame(for: zone, on: screen)
        XCTAssertEqual(frame, screen.visibleFrame, accuracy: 1.0)
    }

    func testLeftRightHalvesFillScreen() {
        guard let screen = NSScreen.main else { return }
        let layout = LeftRightHalves()
        let leftFrame  = layout.appKitFrame(for: layout.zones[0], on: screen)
        let rightFrame = layout.appKitFrame(for: layout.zones[1], on: screen)
        let combined = leftFrame.union(rightFrame)
        XCTAssertEqual(combined.width,  screen.visibleFrame.width,  accuracy: 1.0)
        XCTAssertEqual(combined.height, screen.visibleFrame.height, accuracy: 1.0)
    }

    func testThreeColumnsFillScreen() {
        guard let screen = NSScreen.main else { return }
        let layout = ThreeColumns()
        let totalWidth = layout.zones.reduce(0.0) { $0 + layout.appKitFrame(for: $1, on: screen).width }
        XCTAssertEqual(totalWidth, screen.visibleFrame.width, accuracy: 1.0)
    }

    func testScreenManagerQuartzRoundtrip() {
        let rect = CGRect(x: 100, y: 200, width: 800, height: 600)
        let quartz  = ScreenManager.toQuartz(rect)
        let appKit  = ScreenManager.toAppKit(quartz)
        XCTAssertEqual(appKit.origin.x, rect.origin.x, accuracy: 0.1)
        XCTAssertEqual(appKit.width,    rect.width,     accuracy: 0.1)
        XCTAssertEqual(appKit.height,   rect.height,    accuracy: 0.1)
    }

    func testWindowHistoryPreservesFirstFrame() {
        let history = WindowHistory()
        let original = CGRect(x: 0, y: 0, width: 800, height: 600)
        let second   = CGRect(x: 100, y: 100, width: 400, height: 300)
        history.record(windowID: 1, frame: original)
        history.record(windowID: 1, frame: second)  // should be ignored
        XCTAssertEqual(history.original(for: 1), original)
    }

    func testWindowHistoryPrunesStale() {
        let history = WindowHistory()
        history.record(windowID: 1, frame: .zero)
        history.record(windowID: 2, frame: .zero)
        history.pruneStale(against: [2])
        XCTAssertNil(history.original(for: 1))
        XCTAssertNotNil(history.original(for: 2))
    }
}

extension XCTestCase {
    func XCTAssertEqual(_ lhs: CGRect, _ rhs: CGRect, accuracy: CGFloat) {
        XCTAssertEqual(lhs.minX, rhs.minX, accuracy: accuracy)
        XCTAssertEqual(lhs.minY, rhs.minY, accuracy: accuracy)
        XCTAssertEqual(lhs.width, rhs.width, accuracy: accuracy)
        XCTAssertEqual(lhs.height, rhs.height, accuracy: accuracy)
    }
}
