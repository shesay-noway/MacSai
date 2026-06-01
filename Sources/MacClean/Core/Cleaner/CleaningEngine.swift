import Foundation
import MacCleanKit
import OSLog

public actor CleaningEngine {
    public enum CleanMode: Sendable {
        case trash
        case permanent
        case dryRun
    }

    public struct CleanResult: Sendable {
        public let removedCount: Int
        public let freedBytes: UInt64
        public let errors: [CleanError]
        public let skippedCount: Int
    }

    public struct CleanError: Sendable {
        public let path: String
        public let error: String
    }

    private let safetyGuard = SafetyGuard()
    private let logger = Logger(subsystem: MCConstants.bundleIdentifier, category: "CleaningEngine")

    public init() {}

    /// Trash / permanently delete / dry-run the given items.
    ///
    /// Large selections (chrome cache alone often has 20k+ entries) are
    /// processed in chunks of `MCConstants.cleanChunkSize` so the per-chunk
    /// SafetyGuard batch validation never trips on legitimate cleanups.
    /// Selections beyond `MCConstants.maxTotalItemsPerCleanOperation`
    /// (500k) are refused entirely as a runaway-protection — that's
    /// orders of magnitude above any realistic user scenario and signals
    /// a scanner bug rather than user intent.
    public func clean(items: [FileItem], mode: CleanMode = .trash) async -> CleanResult {
        // Upper bound: refuse genuinely runaway selections cleanly.
        if items.count > MCConstants.maxTotalItemsPerCleanOperation {
            let msg = "Operation exceeds limit of \(MCConstants.maxTotalItemsPerCleanOperation) items (attempted: \(items.count)). This usually indicates a scanner bug."
            logger.error("\(msg, privacy: .public)")
            return CleanResult(
                removedCount: 0,
                freedBytes: 0,
                errors: [CleanError(path: "validation", error: msg)],
                skippedCount: items.count
            )
        }

        var removedCount = 0
        var freedBytes: UInt64 = 0
        var errors: [CleanError] = []
        var skippedCount = 0

        // Internal chunking: SafetyGuard.validateDeletion runs per chunk
        // (capped at MCConstants.maxFilesPerOperation), so even arbitrary-
        // size total selections never blow past the per-batch cap. Yield
        // between chunks so the UI runloop can repaint during long runs
        // (a real fix for the UI freezing on 50k+ cleanups will come
        // when we add a progress channel in a follow-up release).
        let chunkSize = MCConstants.cleanChunkSize
        var startIndex = 0
        while startIndex < items.count {
            if Task.isCancelled { break }
            let endIndex = min(startIndex + chunkSize, items.count)
            let chunk = Array(items[startIndex..<endIndex])
            startIndex = endIndex

            processChunk(
                chunk, mode: mode,
                removedCount: &removedCount,
                freedBytes: &freedBytes,
                errors: &errors,
                skippedCount: &skippedCount
            )

            // Give the runloop room to breathe between chunks.
            await Task.yield()
        }

        logger.info("Cleaning complete: \(removedCount) removed, \(freedBytes) bytes freed, \(errors.count) errors")

        return CleanResult(
            removedCount: removedCount,
            freedBytes: freedBytes,
            errors: errors,
            skippedCount: skippedCount
        )
    }

    /// One chunk's worth of cleanup. Batch-validates the chunk's paths,
    /// then per-item processes if validation passed. On batch failure
    /// (typically a protected path slipping through scanner-side filtering),
    /// the whole chunk is skipped with a single error — partial
    /// processing of a malformed chunk isn't worth the surprise.
    private func processChunk(
        _ chunk: [FileItem],
        mode: CleanMode,
        removedCount: inout Int,
        freedBytes: inout UInt64,
        errors: inout [CleanError],
        skippedCount: inout Int
    ) {
        let urls = chunk.map(\.url)
        do {
            try safetyGuard.validateDeletion(paths: urls)
        } catch {
            logger.error("Chunk validation failed: \(error.localizedDescription)")
            errors.append(CleanError(path: "validation", error: error.localizedDescription))
            skippedCount += chunk.count
            return
        }

        for item in chunk {
            if Task.isCancelled { break }

            do {
                try safetyGuard.validatePath(item.url)
            } catch {
                skippedCount += 1
                errors.append(CleanError(
                    path: item.url.path(percentEncoded: false),
                    error: error.localizedDescription
                ))
                continue
            }

            switch mode {
            case .dryRun:
                removedCount += 1
                freedBytes += item.size
                logOperation(path: item.url, size: item.size, dryRun: true)

            case .trash:
                do {
                    try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
                    removedCount += 1
                    freedBytes += item.size
                    logOperation(path: item.url, size: item.size, dryRun: false)
                } catch {
                    errors.append(CleanError(
                        path: item.url.path(percentEncoded: false),
                        error: error.localizedDescription
                    ))
                }

            case .permanent:
                do {
                    try FileManager.default.removeItem(at: item.url)
                    removedCount += 1
                    freedBytes += item.size
                    logOperation(path: item.url, size: item.size, dryRun: false)
                } catch {
                    errors.append(CleanError(
                        path: item.url.path(percentEncoded: false),
                        error: error.localizedDescription
                    ))
                }
            }
        }
    }

    private nonisolated func logOperation(path: URL, size: UInt64, dryRun: Bool) {
        let fm = FileManager.default
        let logDir = MCConstants.operationLogDir
        let logFile = MCConstants.operationLogFile

        if !fm.fileExists(atPath: logDir.path(percentEncoded: false)) {
            try? fm.createDirectory(at: logDir, withIntermediateDirectories: true)
        }

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let prefix = dryRun ? "[DRY-RUN]" : "[REMOVED]"
        let sizeStr = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
        let line = "\(timestamp) \(prefix) \(path.path(percentEncoded: false)) (\(sizeStr))\n"

        if let data = line.data(using: .utf8) {
            if fm.fileExists(atPath: logFile.path(percentEncoded: false)) {
                if let handle = try? FileHandle(forWritingTo: logFile) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? data.write(to: logFile)
            }
        }
    }
}
