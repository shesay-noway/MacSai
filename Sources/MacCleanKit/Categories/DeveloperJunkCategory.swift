import Foundation

/// Regenerable caches from package managers and AI coding tools. Cache-only:
/// the matching history/memory/sessions/extensions live elsewhere and are never
/// targeted (see DeveloperJunkCategoryTests.testNeverTargetsUserData).
public struct DeveloperJunkCategory: JunkCategory {
    public init() {}
    public let scanCategory = ScanCategory.developerJunk
    public var targets: [ScanTarget] {
        var paths: [URL] = [
            MCConstants.npmCacache,
            MCConstants.cargoRegistryCache,
            MCConstants.cargoRegistrySrc,
            MCConstants.gradleCaches,
            MCConstants.gradleDaemon,
            MCConstants.gradleWrapperDists,
            MCConstants.homebrewCache,
            MCConstants.pipCache,
            MCConstants.claudeCache,
            MCConstants.claudePasteCache,
            MCConstants.claudeShellSnapshots,
            MCConstants.codexTmp,
            MCConstants.codexCache,
        ]
        paths += MCConstants.antigravityCaches
        paths += MCConstants.cursorCaches
        return paths.map { ScanTarget(path: $0, recursive: false) }
    }
}
