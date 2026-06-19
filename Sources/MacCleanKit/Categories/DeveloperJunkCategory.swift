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
        // Recursive: these caches keep their bulk in subdirectories (npm's
        // content-v2, Cargo's registry trees, Electron Cache shards). A
        // non-recursive listing would size those subdirs at ~0 and badly
        // under-report reclaimable space, the way UserCacheFiles scans deep.
        return paths.map { ScanTarget(path: $0, recursive: true) }
    }
}
