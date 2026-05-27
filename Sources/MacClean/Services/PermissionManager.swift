import Foundation
import MacCleanKit
import AppKit

public final class PermissionManager: @unchecked Sendable {
    public static let shared = PermissionManager()

    private init() {}

    public func canReadTCCProtectedPaths() -> Bool {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser

        let tccDirs = [
            home.appendingPathComponent("Library/Safari"),
            home.appendingPathComponent("Library/Mail"),
            home.appendingPathComponent("Library/Messages"),
        ]

        for dir in tccDirs {
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue {
                if let _ = try? fm.contentsOfDirectory(atPath: dir.path) {
                    return true
                }
            }
        }
        return false
    }

    public func openFullDiskAccessSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
    }
}
