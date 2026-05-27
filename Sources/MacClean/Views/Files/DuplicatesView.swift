import SwiftUI
import MacCleanKit

struct DuplicatesView: View {
    @Environment(AppState.self) private var appState
    @State private var results: [ScanResult] = []
    @State private var selectedItems: Set<URL> = []
    @State private var isScanning = false
    @State private var scanProgress: Double = 0
    @State private var scanPhase = ""
    @State private var scanComplete = false
    @State private var isDone = false
    @State private var freedSize: UInt64 = 0

    var body: some View {
        ModuleContainerView(
            title: "Duplicates",
            subtitle: "Find duplicate files using progressive hash detection",
            theme: .files,
            emptyMessage: "No duplicates found",
            results: results,
            selectedItems: $selectedItems,
            isScanning: isScanning,
            scanProgress: scanProgress,
            scanPhase: scanPhase,
            scanComplete: scanComplete,
            isDone: isDone,
            freedSize: freedSize,
            onScan: scan,
            onClean: clean,
            onReset: reset
        )
    }

    private func scan() {
        isScanning = true
        scanComplete = false
        scanProgress = 0
        Task {
            let scanStart = Date()

            scanPhase = "Grouping files by size..."
            scanProgress = 0.15
            try? await Task.sleep(for: .milliseconds(500))

            scanPhase = "Computing partial hashes..."
            scanProgress = 0.35

            let module = DuplicatesModule()
            async let scanTask = module.scan()

            try? await Task.sleep(for: .milliseconds(500))
            scanPhase = "Computing full hashes..."
            scanProgress = 0.6

            try? await Task.sleep(for: .milliseconds(400))
            scanPhase = "Verifying duplicates..."
            scanProgress = 0.8

            results = await scanTask

            scanPhase = "Finalizing..."
            scanProgress = 0.95

            let elapsed = Date().timeIntervalSince(scanStart)
            if elapsed < 2.5 {
                try? await Task.sleep(for: .milliseconds(Int((2.5 - elapsed) * 1000)))
            }
            scanProgress = 1.0

            isScanning = false
            scanComplete = true
        }
    }

    private func clean() {
        let items = results.flatMap(\.items).filter { selectedItems.contains($0.url) }
        Task {
            let result = await appState.cleaningEngine.clean(items: items, mode: .dryRun)
            freedSize = result.freedBytes
            isDone = true
        }
    }

    private func reset() {
        results = []; selectedItems = []; isDone = false; freedSize = 0; scanComplete = false
    }
}
