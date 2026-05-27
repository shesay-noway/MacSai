import SwiftUI
import MacCleanKit

struct SystemJunkView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = SystemJunkViewModel()

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle:
                idleView
            case .scanning(let progress):
                scanningView(progress: progress)
            case .results:
                resultsView
            case .empty:
                emptyView
            case .cleaning:
                cleaningView
            case .done(let freed):
                doneView(freed: freed)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var idleView: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 10) {
                Text("System Junk")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)

                Text("Find and remove system caches, logs,\nlanguage files, and other junk")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
            }

            ScanButton(
                title: "Scan",
                subtitle: "System Junk",
                theme: .cleanup
            ) {
                viewModel.startScan()
            }

            Spacer()
        }
    }

    private func scanningView(progress: Double) -> some View {
        VStack(spacing: 0) {
            Spacer()

            ScanProgressRing(
                progress: progress,
                phase: viewModel.scanPhase,
                detail: "\(viewModel.filesFound) files found",
                theme: .cleanup
            )

            Spacer()
        }
    }

    private var resultsView: some View {
        VStack(spacing: 0) {
            HStack {
                SizeDisplay(size: viewModel.totalSelectedSize, label: "selected to clean")
                    .foregroundStyle(.white)

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text("\(viewModel.selectedCount) of \(viewModel.totalFileCount) files")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))

                    Button("Clean") {
                        viewModel.startCleaning(engine: appState.cleaningEngine)
                    }
                    .buttonStyle(SuperEllipseButtonStyle(
                        gradient: ModuleTheme.cleanup.buttonGradient,
                        size: CGSize(width: 110, height: 40)
                    ))
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)

            FileListView(
                results: viewModel.results,
                selectedItems: $viewModel.selectedItems
            )
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 52))
                .foregroundStyle(.white.opacity(0.9))
            Text("No junk found")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
            Text("Your Mac is clean!")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.55))
            Button("Done") { viewModel.reset() }
                .buttonStyle(.bordered)
                .tint(.white)
                .controlSize(.large)
            Spacer()
        }
    }

    private var cleaningView: some View {
        VStack(spacing: 0) {
            Spacer()
            ScanProgressRing(progress: 0.5, phase: "Cleaning...", theme: .cleanup)
            Spacer()
        }
    }

    private func doneView(freed: UInt64) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(.white)
            SizeDisplay(size: freed, label: "cleaned up")
                .foregroundStyle(.white)
            Button("Done") { viewModel.reset() }
                .buttonStyle(.bordered)
                .tint(.white)
                .controlSize(.large)
            Spacer()
        }
    }
}
