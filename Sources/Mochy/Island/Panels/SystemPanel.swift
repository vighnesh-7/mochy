import SwiftUI

struct SystemPanel: View {
    @ObservedObject var battery: BatteryMonitor

    var body: some View {
        HStack(spacing: 10) {
            BatteryVitalsTile(vitals: battery.vitals)
        }
        .onAppear { battery.refresh() }
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
