import XCTest
import Foundation
@testable import MacCleanKit

final class BrokenLoginItemsTests: XCTestCase {

    private func makeItem(_ name: String) -> FileItem {
        let url = MCConstants.userLaunchAgents.appending(path: "\(name).plist")
        return FileItem(url: url, name: "\(name).plist", size: 100, allocatedSize: 100, isDirectory: false)
    }

    private func plistData(_ dict: [String: Any]) -> Data {
        try! PropertyListSerialization.data(fromPropertyList: dict, format: .binary, options: 0)
    }

    // MARK: - Healthy login items

    func testHealthyLoginItemIsNotFlagged() {
        let cat = BrokenLoginItemsCategory()
        let item = makeItem("com.spotify.webhelper")
        let plist = plistData([
            "Label": "com.spotify.webhelper",
            "ProgramArguments": ["/Applications/Spotify.app/Contents/MacOS/SpotifyHelper"],
        ])

        let result = cat.filterBroken(
            [item],
            loadData: { _ in plist },
            fileExists: { _ in true },
            appExistsForBundleID: { _ in true }
        )
        XCTAssertTrue(result.isEmpty, "Healthy login item must not be flagged")
    }

    // MARK: - Missing binary

    func testMissingBinaryIsFlagged() {
        let cat = BrokenLoginItemsCategory()
        let item = makeItem("com.deleted.app")
        let plist = plistData([
            "Label": "com.deleted.app",
            "Program": "/Applications/Deleted.app/Contents/MacOS/Deleted",
        ])
        let result = cat.filterBroken(
            [item],
            loadData: { _ in plist },
            fileExists: { _ in false }, // binary doesn't exist
            appExistsForBundleID: { _ in false }
        )
        XCTAssertEqual(result.count, 1)
    }

    // MARK: - Missing .app bundle

    func testMissingAppBundleIsFlagged() {
        let cat = BrokenLoginItemsCategory()
        let item = makeItem("com.deleted.app")
        let plist = plistData([
            "Label": "com.deleted.app",
            "Program": "/Applications/Deleted.app/Contents/MacOS/Deleted",
        ])
        // Binary path "exists" (filter passes that check), but parent .app doesn't.
        let result = cat.filterBroken(
            [item],
            loadData: { _ in plist },
            fileExists: { path in
                // Pretend the binary exists but not the .app
                !path.hasSuffix(".app")
            },
            appExistsForBundleID: { _ in false }
        )
        XCTAssertEqual(result.count, 1)
    }

    // MARK: - Corrupt plist

    func testCorruptPlistIsFlagged() {
        let cat = BrokenLoginItemsCategory()
        let item = makeItem("com.example.corrupt")
        let result = cat.filterBroken(
            [item],
            loadData: { _ in Data([0xFF, 0x00, 0xFF]) },
            fileExists: { _ in true },
            appExistsForBundleID: { _ in true }
        )
        XCTAssertEqual(result.count, 1)
    }

    // MARK: - Unreadable file

    func testUnreadableFileIsFlagged() {
        let cat = BrokenLoginItemsCategory()
        let item = makeItem("com.example.unreadable")
        let result = cat.filterBroken(
            [item],
            loadData: { _ in nil },
            fileExists: { _ in true },
            appExistsForBundleID: { _ in true }
        )
        XCTAssertEqual(result.count, 1)
    }

    // MARK: - ProgramArguments fallback

    func testProgramArgumentsFallbackResolvedCorrectly() {
        let cat = BrokenLoginItemsCategory()
        let item = makeItem("com.example.cli")
        let plist = plistData([
            "Label": "com.example.cli",
            "ProgramArguments": ["/usr/local/bin/example-cli", "--daemon"],
        ])
        // Binary doesn't exist → flagged.
        let result = cat.filterBroken(
            [item],
            loadData: { _ in plist },
            fileExists: { _ in false },
            appExistsForBundleID: { _ in false }
        )
        XCTAssertEqual(result.count, 1)
    }

    // MARK: - Non-plist files

    func testNonPlistIgnored() {
        let cat = BrokenLoginItemsCategory()
        let item = FileItem(
            url: URL(filePath: "/tmp/something.txt"),
            name: "something.txt",
            size: 0, allocatedSize: 0, isDirectory: false
        )
        let result = cat.filterBroken(
            [item],
            loadData: { _ in nil },
            fileExists: { _ in false },
            appExistsForBundleID: { _ in false }
        )
        XCTAssertTrue(result.isEmpty)
    }
}
