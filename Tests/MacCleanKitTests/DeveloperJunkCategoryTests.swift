import XCTest
@testable import MacCleanKit

final class DeveloperJunkCategoryTests: XCTestCase {
    private var paths: [String] {
        DeveloperJunkCategory().targets.map { $0.path.path(percentEncoded: false) }
    }

    func testIncludesExpectedSafeCaches() {
        let p = paths
        func has(_ suffix: String) -> Bool { p.contains { $0.hasSuffix(suffix) } }
        XCTAssertTrue(has("/.npm/_cacache"))
        XCTAssertTrue(has("/.cargo/registry/cache"))
        XCTAssertTrue(has("/.cargo/registry/src"))
        XCTAssertTrue(has("/.gradle/caches"))
        XCTAssertTrue(has("/Library/Caches/Homebrew"))
        XCTAssertTrue(has("/Library/Caches/pip"))
        XCTAssertTrue(has("/.claude/cache"))
        XCTAssertTrue(has("/.codex/.tmp"))
        XCTAssertTrue(p.contains { $0.contains("Application Support/Antigravity/") && $0.hasSuffix("/Cache") })
        XCTAssertTrue(p.contains { $0.contains("Application Support/Cursor/") && $0.hasSuffix("/Cache") })
    }

    // Load-bearing safety test: never target user data.
    func testNeverTargetsUserData() {
        let forbidden = [
            "/.claude/projects", "/.claude/file-history",
            "/.codex/sessions", "/.codex/archived_sessions",
            "/extensions", "/Antigravity/User", "/Cursor/User",
            "com.docker.docker", "Docker.raw",
        ]
        for path in paths {
            for bad in forbidden {
                XCTAssertFalse(path.contains(bad), "Developer Junk must never target \(bad), found in \(path)")
            }
        }
    }

    func testTargetsAreRecursive() {
        // Recursive so each cache dir's contents are enumerated and sized;
        // non-recursive lists subdirs as ~0-byte items (e.g. npm's content-v2),
        // badly under-reporting reclaimable space.
        XCTAssertTrue(DeveloperJunkCategory().targets.allSatisfy { $0.recursive })
    }
}
