import SwiftUI

struct SystemPanel: View {
    @ObservedObject var stats: SystemStatsService
    @ObservedObject var battery: BatteryMonitor

    var body: some View {
        let sample = stats.sample
        HStack(spacing: 10) {
            Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                GridRow {
                    StatTile(title: "CPU", value: "\(Int(sample.cpu * 100))%") {
                        Sparkline(values: stats.cpuHistory, tint: cpuTint(sample.cpu))
                    }
                    StatTile(title: "Memory", value: "\(Int(sample.memoryFraction * 100))%") {
                        VStack(alignment: .leading, spacing: 4) {
                            Spacer(minLength: 0)
                            Meter(value: sample.memoryFraction, tint: Island.info, height: 5)
                            Text("\(ByteFormat.memory(sample.memoryUsed)) of \(ByteFormat.memory(sample.memoryTotal))")
                                .font(Island.numerals(10.5, weight: .medium)).foregroundStyle(Island.tertiary)
                        }
                    }
                }
                GridRow {
                    StatTile(title: "Network", value: nil) {
                        VStack(alignment: .leading, spacing: 3) {
                            Label(ByteFormat.rate(sample.networkIn), systemImage: "arrow.down")
                            Label(ByteFormat.rate(sample.networkOut), systemImage: "arrow.up")
                        }
                        .font(Island.numerals(11.5, weight: .semibold))
                        .foregroundStyle(Island.primary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    }
                    StatTile(title: "Storage", value: nil) {
                        VStack(alignment: .leading, spacing: 4) {
                            Spacer(minLength: 0)
                            Meter(value: sample.diskUsedFraction, tint: Island.focus, height: 5)
                            Text("\(ByteFormat.storage(sample.diskFree)) free")
                                .font(Island.numerals(10.5, weight: .medium)).foregroundStyle(Island.tertiary)
                        }
                    }
                }
            }
            BatteryVitalsTile(vitals: battery.vitals).frame(width: 210)
        }
        .onAppear {
            stats.beginWatching()
            battery.refresh()
        }
        .onDisappear { stats.endWatching() }
    }

    private func cpuTint(_ value: Double) -> Color {
        value > 0.85 ? Island.warning : (value > 0.6 ? Island.focus : Island.positive)
    }
}

private struct StatTile<Content: View>: View {
    let title: String
    let value: String?
    @ViewBuilder var content: Content

    var body: some View {
        IslandCard(padding: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    SectionLabel(text: title)
                    Spacer()
                    if let value {
                        Text(value).font(Island.numerals(15, weight: .bold)).foregroundStyle(Island.primary)
                    }
                }
                content.frame(maxHeight: .infinity)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct BatteryVitalsTile: View {
    let vitals: BatteryVitals

    var body: some View {
        IslandCard(padding: 12) {
            if !vitals.hasBattery {
                EmptyState(symbol: "powerplug.fill", title: "No Battery", message: "This Mac runs on wall power.")
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Image(systemName: batterySymbol(vitals)).font(.system(size: 14)).foregroundStyle(batteryColor(vitals))
                        Text("\(vitals.percent)%").font(Island.numerals(22, weight: .bold)).foregroundStyle(Island.primary)
                        Spacer()
                        if vitals.lowPowerMode {
                            Text("Low Power").font(.system(size: 10, weight: .semibold)).foregroundStyle(Island.focus)
                        }
                    }
                    Text(vitals.timeDescription).font(.system(size: 11)).foregroundStyle(Island.secondary)
                    Spacer(minLength: 0)
                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 3) {
                        row("Health", vitals.healthPercent.map { "\($0)%" })
                        row("Cycles", vitals.cycleCount.map(String.init))
                        row("Temperature", vitals.temperatureC.map { String(format: "%.1f °C", $0) })
                        row(vitals.isCharging ? "Charging At" : "Power Draw", vitals.watts.map { String(format: "%.1f W", abs($0)) })
                        row("Adapter", vitals.adapterWatts.map { "\($0) W" })
                    }
                }
            }
        }
    }

    @ViewBuilder private func row(_ label: String, _ value: String?) -> some View {
        if let value {
            GridRow {
                Text(label).foregroundStyle(Island.tertiary)
                Text(value).foregroundStyle(Island.primary).gridColumnAlignment(.trailing)
            }
            .font(Island.numerals(10.5, weight: .medium))
        }
    }
}
