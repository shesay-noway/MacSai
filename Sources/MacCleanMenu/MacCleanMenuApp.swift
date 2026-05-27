import SwiftUI
import MacCleanKit

@main
struct MacCleanMenuApp: App {
    @State private var statsCollector = SystemStatsCollector()
    @State private var networkMonitor = NetworkSpeedMonitor()
    @State private var stats: SystemStatsCollector.SystemStats?
    @State private var networkSpeed: NetworkSpeedMonitor.NetworkSpeed?
    @State private var timer: Timer?

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(stats: stats, networkSpeed: networkSpeed)
                .onAppear { startPolling() }
                .onDisappear { stopPolling() }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "leaf.fill")
                if let stats {
                    Text(FileSizeFormatter.format(stats.diskFree))
                        .font(.system(size: 11, design: .monospaced))
                }
            }
        }
        .menuBarExtraStyle(.window)
    }

    private func startPolling() {
        Task { @MainActor in
            stats = await statsCollector.collect()
            networkSpeed = await networkMonitor.measure()
        }
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            Task { @MainActor [statsCollector, networkMonitor] in
                self.stats = await statsCollector.collect()
                self.networkSpeed = await networkMonitor.measure()
            }
        }
    }

    private func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
}

struct MenuContentView: View {
    let stats: SystemStatsCollector.SystemStats?
    let networkSpeed: NetworkSpeedMonitor.NetworkSpeed?

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(.green)
                Text("Mac Clean")
                    .font(.headline)
                Spacer()
            }

            Divider()

            if let stats {
                MonitorRow(
                    icon: "cpu", title: "CPU",
                    value: String(format: "%.1f%%", stats.cpuUsage * 100),
                    bar: stats.cpuUsage, color: barColor(stats.cpuUsage)
                )

                MonitorRow(
                    icon: "memorychip", title: "Memory",
                    value: "\(FileSizeFormatter.format(stats.memoryUsed)) / \(FileSizeFormatter.format(stats.memoryTotal))",
                    bar: stats.memoryPressure, color: barColor(stats.memoryPressure)
                )

                let diskUsage = stats.diskTotal > 0 ? Double(stats.diskTotal - stats.diskFree) / Double(stats.diskTotal) : 0
                MonitorRow(
                    icon: "internaldrive", title: "Disk",
                    value: "\(FileSizeFormatter.format(stats.diskFree)) free",
                    bar: diskUsage, color: barColor(diskUsage)
                )

                if let level = stats.batteryLevel {
                    MonitorRow(
                        icon: stats.batteryIsCharging ? "battery.100.bolt" : "battery.75",
                        title: "Battery",
                        value: String(format: "%.0f%%", level * 100) + (stats.batteryIsCharging ? " Charging" : ""),
                        bar: level, color: level > 0.2 ? .green : .red
                    )
                }

                // Network speed
                if let net = networkSpeed {
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 9))
                                .foregroundStyle(.green)
                            Text(net.formattedIn)
                                .font(.system(size: 11, design: .monospaced))
                        }
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 9))
                                .foregroundStyle(.blue)
                            Text(net.formattedOut)
                                .font(.system(size: 11, design: .monospaced))
                        }
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }

                HStack {
                    Image(systemName: "clock")
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    Text("Uptime")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formatUptime(stats.uptime))
                        .font(.system(.caption, design: .monospaced))
                }

                if stats.swapUsed > 0 {
                    HStack {
                        Image(systemName: "arrow.triangle.swap")
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        Text("Swap")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(FileSizeFormatter.format(stats.swapUsed))
                            .font(.system(.caption, design: .monospaced))
                    }
                }
            } else {
                ProgressView("Loading...")
            }

            Divider()

            Button("Open Mac Clean") {
                if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: MCConstants.bundleIdentifier) {
                    NSWorkspace.shared.openApplication(at: url, configuration: .init())
                }
            }

            Button("Quit Monitor") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
        .frame(width: 300)
    }

    private func barColor(_ value: Double) -> Color {
        if value > 0.85 { return .red }
        if value > 0.65 { return .orange }
        return .green
    }

    private func formatUptime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 24 {
            return "\(hours / 24)d \(hours % 24)h"
        }
        return "\(hours)h \(minutes)m"
    }
}

struct MonitorRow: View {
    let icon: String
    let title: String
    let value: String
    let bar: Double
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Text(value)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.15))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geo.size.width * min(max(bar, 0), 1))
                }
            }
            .frame(height: 4)
        }
    }
}
