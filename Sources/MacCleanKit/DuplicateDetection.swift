import Foundation

/// Pure logic for the progressive duplicate-detection pipeline.
///
/// The MacClean target wraps this with actual SHA-256 hashing via CryptoKit
/// and parallel `TaskGroup` execution. The decisions ABOUT which candidates
/// to keep, which to drop, and how to deduplicate by inode all live here
/// so they can be unit-tested without disk I/O.
public enum DuplicateDetection {

    /// Files larger than this are skipped to avoid hour-long hashes.
    public static let maxHashableFileSize: UInt64 = 500 * 1024 * 1024

    /// Stage 1: group by size. Files with a unique size CANNOT be duplicates.
    /// Files larger than `maxHashableFileSize` are dropped entirely.
    ///
    /// - Returns: groups of size > 1, ready for partial hashing.
    public static func sizeGroups(_ files: [FileItem]) -> [[FileItem]] {
        let hashable = files.filter { $0.size <= maxHashableFileSize }
        let grouped = Dictionary(grouping: hashable) { $0.size }
        return grouped.values.filter { $0.count > 1 }
    }

    /// Stage 2 → stage 3 transition: given a collection of (key, FileItem)
    /// pairs from the partial-hash stage, group by key and keep only buckets
    /// with > 1 candidate. The key is typically `"<size>-<partialHash>"`.
    public static func partialGroups(
        _ pairs: [(key: String, item: FileItem)]
    ) -> [[FileItem]] {
        let grouped = Dictionary(grouping: pairs, by: \.key)
            .mapValues { $0.map(\.item) }
        return grouped.values.filter { $0.count > 1 }
    }

    /// Stage 3 → stage 4 transition: same as above, but the key is the full
    /// hash. Hard-link deduplication (Stage 4) is then applied to each group.
    public static func fullGroupsAndDedupHardLinks(
        _ pairs: [(key: String, item: FileItem)]
    ) -> [[FileItem]] {
        let grouped = Dictionary(grouping: pairs, by: \.key)
            .mapValues { $0.map(\.item) }
        return grouped.values
            .filter { $0.count > 1 }
            .map(dedupHardLinks)
            .filter { $0.count > 1 }
    }

    /// Stage 4 (in isolation): drop files that share an inode with one already
    /// kept. Files with `inode == 0` are treated as unknown and always kept.
    public static func dedupHardLinks(_ group: [FileItem]) -> [FileItem] {
        var seen: Set<UInt64> = []
        return group.filter { item in
            if item.inode == 0 { return true }
            return seen.insert(item.inode).inserted
        }
    }

    /// From the final groups of true duplicates, pick the "items to delete":
    /// keep one (the first) in each group as the original, mark the rest
    /// as duplicates the user could remove.
    public static func extractDeletableDuplicates(_ groups: [[FileItem]]) -> [FileItem] {
        groups.flatMap { Array($0.dropFirst()) }
    }
}
