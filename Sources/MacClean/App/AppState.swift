import SwiftUI
import MacCleanKit

@Observable
public final class AppState {
    var selectedSidebarItem: SidebarItem? = .smartScan
    var scanCoordinator = ScanCoordinator()
    let cleaningEngine = CleaningEngine()

    init() {
        registerModules()
    }

    private func registerModules() {
        scanCoordinator.registerModules([
            SystemJunkModule(),
            MailAttachmentsModule(),
            TrashBinsModule(),
            MalwareModule(),
            PrivacyModule(),
            OptimizationModule(),
            MaintenanceModule(),
            UninstallerModule(),
            UpdaterModule(),
            SpaceLensModule(),
            LargeOldFilesModule(),
            DuplicatesModule(),
            ShredderModule(),
        ])
    }

}
