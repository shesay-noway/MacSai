import SwiftUI
import MacCleanKit

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        NavigationSplitView {
            SidebarView(selection: $state.selectedSidebarItem)
        } detail: {
            ZStack {
                if let item = appState.selectedSidebarItem {
                    GradientBackgroundView(theme: item.theme)
                        .ignoresSafeArea()
                    moduleView(for: item)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Text("Select a module from the sidebar")
                        .foregroundStyle(.secondary)
                }
            }
            .toolbarBackground(.hidden, for: .windowToolbar)
        }
        .navigationTitle("Mac Clean")
        // Native macOS pattern: small grey second line under the title.
        // MCVersion.app is generated at build time from the package-root
        // VERSION file by the VersionGen build plugin — single source of
        // truth, no manual sync.
        .navigationSubtitle("v\(MCVersion.app)")
    }

    @ViewBuilder
    private func moduleView(for item: SidebarItem) -> some View {
        switch item {
        case .smartScan:
            SmartScanView()
        case .systemJunk:
            SystemJunkView()
        case .mailAttachments:
            MailAttachmentsView()
        case .trashBins:
            TrashBinsView()
        case .malwareRemoval:
            MalwareView()
        case .privacy:
            PrivacyView()
        case .optimization:
            OptimizationView()
        case .maintenance:
            MaintenanceView()
        case .uninstaller:
            UninstallerView()
        case .updater:
            UpdaterView()
        case .spaceLens:
            SpaceLensView()
        case .largeOldFiles:
            LargeOldFilesView()
        case .duplicates:
            DuplicatesView()
        case .shredder:
            ShredderView()
        }
    }
}
