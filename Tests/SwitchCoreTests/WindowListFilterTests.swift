import CoreGraphics
import SwitchCore
import XCTest

final class WindowListFilterTests: XCTestCase {
    func testFiltersOutUnsupportedEntries() {
        let records = [
            WindowRecord(
                windowID: 1,
                ownerPID: 111,
                ownerName: "Safari",
                title: "GitHub",
                layer: 0,
                alpha: 1,
                bounds: CGRect(x: 0, y: 0, width: 800, height: 600),
                isOnscreen: true
            ),
            WindowRecord(
                windowID: 2,
                ownerPID: 111,
                ownerName: "Safari",
                title: "",
                layer: 0,
                alpha: 1,
                bounds: CGRect(x: 0, y: 0, width: 800, height: 600),
                isOnscreen: true
            ),
            WindowRecord(
                windowID: 3,
                ownerPID: 222,
                ownerName: "Finder",
                title: "Downloads",
                layer: 3,
                alpha: 1,
                bounds: CGRect(x: 0, y: 0, width: 800, height: 600),
                isOnscreen: true
            ),
            WindowRecord(
                windowID: 4,
                ownerPID: 333,
                ownerName: "Notes",
                title: "Quick Note",
                layer: 0,
                alpha: 0,
                bounds: CGRect(x: 0, y: 0, width: 800, height: 600),
                isOnscreen: true
            ),
        ]

        let snapshots = WindowListFilter.filter(records: records, excludingPID: 999)

        XCTAssertEqual(snapshots.count, 1)
        XCTAssertEqual(snapshots.first?.windowID, 1)
        XCTAssertEqual(snapshots.first?.title, "GitHub")
    }

    func testRemovesOwnProcessAndDuplicateWindowIDs() {
        let records = [
            WindowRecord(
                windowID: 8,
                ownerPID: 444,
                ownerName: "Terminal",
                title: "Work",
                layer: 0,
                alpha: 1,
                bounds: CGRect(x: 10, y: 10, width: 400, height: 300),
                isOnscreen: true
            ),
            WindowRecord(
                windowID: 8,
                ownerPID: 444,
                ownerName: "Terminal",
                title: "Work Copy",
                layer: 0,
                alpha: 1,
                bounds: CGRect(x: 10, y: 10, width: 400, height: 300),
                isOnscreen: true
            ),
            WindowRecord(
                windowID: 9,
                ownerPID: 555,
                ownerName: "Mail",
                title: "Inbox",
                layer: 0,
                alpha: 1,
                bounds: CGRect(x: 30, y: 20, width: 500, height: 400),
                isOnscreen: true
            ),
        ]

        let snapshots = WindowListFilter.filter(records: records, excludingPID: 444)

        XCTAssertEqual(snapshots.map(\.windowID), [9])
    }
}
