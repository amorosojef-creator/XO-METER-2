import SwiftUI
import Charts

struct SaverView: View {
    @EnvironmentObject private var store: XOStore
    @State private var editing: Appliance?
    @State private var newAppliance = false
    private var sorted: [Appliance] { store.appliances.sorted { $0.monthlyKWh > $1.monthlyKWh } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Energy Saver").font(.largeTitle.bold())
                    Spacer()
                    Button { newAppliance = true } label: {
                        Image(systemName: "plus.circle.fill").font(.title).foregroundStyle(XOTheme.accent)
                    }.accessibilityLabel("Add appliance")
                }
                GlassPanel {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MONTHLY APPLIANCE ESTIMATE").font(.caption2).foregroundStyle(XOTheme.muted)
                        Text("\(store.applianceKWh.formatted(.number.precision(.fractionLength(1)))) kWh")
                            .font(.system(size: 33, weight: .bold))
                        Text(Billing.pesos(store.applianceKWh * store.effectiveRate) + " / month")
                            .foregroundStyle(XOTheme.accent).font(.title3.bold())
                        Text("Estimates are based on the schedules you enter, not direct electrical measurements.")
                            .font(.caption).foregroundStyle(XOTheme.muted)
                    }
                }
                GlassPanel {
                    VStack(alignment: .leading, spacing: 11) {
                        Text("Biggest estimated energy users").font(.headline)
                        if sorted.contains(where: { $0.monthlyKWh > 0 }) {
                            Chart(sorted.filter { $0.monthlyKWh > 0 }.prefix(6)) { a in
                                BarMark(x: .value("kWh", a.monthlyKWh), y: .value("Device", String(a.name.prefix(16))))
                                    .foregroundStyle(XOTheme.accentGlow.gradient)
                            }.frame(height: min(260, CGFloat(sorted.filter { $0.monthlyKWh > 0 }.count) * 43 + 30))
                        } else { Text("Add appliance power and usage hours to see a breakdown.").font(.caption).foregroundStyle(XOTheme.muted) }
                    }
                }
                HStack {
                    Text("Your appliances").font(.title3.bold())
                    Spacer()
                    Text("Tap to edit").font(.caption).foregroundStyle(XOTheme.muted)
                }
                ForEach(sorted) { appliance in
                    Button { editing = appliance } label: {
                        GlassPanel {
                            HStack(spacing: 12) {
                                Image(systemName: symbol(for: appliance.name)).foregroundStyle(XOTheme.accent).frame(width: 25)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(appliance.name).font(.subheadline.bold()).foregroundStyle(.white)
                                    Text(appliance.labelKWhPerDay != nil ? "Energy-label estimate · \(appliance.count) unit(s)" : "\(appliance.count) × \(Int(appliance.watts)) W · \(appliance.hoursPerDay.formatted()) h/day · \(appliance.daysPerMonth.formatted()) days")
                                        .font(.caption2).foregroundStyle(XOTheme.muted)
                                }
                                Spacer(minLength: 4)
                                VStack(alignment: .trailing, spacing: 3) {
                                    Text("\(appliance.monthlyKWh.formatted(.number.precision(.fractionLength(1)))) kWh").font(.caption.bold())
                                    Text(Billing.pesos(appliance.monthlyKWh * store.effectiveRate))
                                        .font(.caption2).foregroundStyle(XOTheme.accent)
                                }
                            }
                        }
                    }.buttonStyle(.plain)
                }
                GlassPanel {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Practical saving ideas", systemImage: "lightbulb").font(.headline)
                        Text("• Switch off unattended lights and displays.\n• Set PC sleep mode for idle time.\n• Keep refrigeration on, and check food-safe temperatures with a thermometer.\n• Recheck your appliance estimates when usage changes.")
                            .font(.subheadline).foregroundStyle(XOTheme.muted)
                    }
                }
            }.padding(17)
        }
        .sheet(isPresented: $newAppliance) { ApplianceEditor(appliance: nil) { item in
            store.appliances.append(item); store.save()
        } }
        .sheet(item: $editing) { current in
            ApplianceEditor(appliance: current, onSave: { updated in
                if let index = store.appliances.firstIndex(where: { $0.id == current.id }) { store.appliances[index] = updated }
                store.save()
            }, onDelete: {
                store.appliances.removeAll { $0.id == current.id }; store.save()
            })
        }
    }
    private func symbol(for name: String) -> String {
        let s = name.lowercased()
        if s.contains("refrig") { return "refrigerator" }
        if s.contains("fan") { return "fanblades" }
        if s.contains("light") { return "lightbulb" }
        if s.contains("tv") || s.contains("television") { return "tv" }
        if s.contains("computer") || s.contains("pc") { return "desktopcomputer" }
        return "powerplug"
    }
}

struct ApplianceEditor: View {
    @Environment(\.dismiss) private var dismiss
    let appliance: Appliance?
    let onSave: (Appliance) -> Void
    var onDelete: (() -> Void)? = nil
    @State private var name: String = ""
    @State private var count: String = "1"
    @State private var watts: String = "9"
    @State private var hours: String = "6"
    @State private var days: String = "30"
    @State private var labelKWh: String = ""
    @State private var useLabel = false
    @State private var error = ""
    var body: some View {
        NavigationStack {
            Form {
                Section("Appliance details") {
                    TextField("Appliance name", text: $name)
                    TextField("Number of units", text: $count).keyboardType(.numberPad)
                    Toggle("Use a tested kWh/day energy label", isOn: $useLabel)
                    if useLabel {
                        TextField("Energy label kWh per 24 hours", text: $labelKWh).keyboardType(.decimalPad)
                        Text("Use measured or energy-label consumption for appliances such as inverter refrigerators.").font(.caption)
                    } else {
                        TextField("Watts per unit", text: $watts).keyboardType(.decimalPad)
                        TextField("Hours used per day", text: $hours).keyboardType(.decimalPad)
                    }
                    TextField("Days used per month", text: $days).keyboardType(.numberPad)
                }
                if !error.isEmpty { Text(error).foregroundStyle(.red) }
                Section {
                    Button("Save appliance") { save() }.fontWeight(.bold)
                    if appliance != nil, let onDelete {
                        Button("Remove appliance", role: .destructive) { onDelete(); dismiss() }
                    }
                }
            }
            .navigationTitle(appliance == nil ? "Add Appliance" : "Edit Appliance")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } } }
            .onAppear {
                guard let a = appliance else { return }
                name = a.name; count = String(a.count); watts = String(a.watts)
                hours = String(a.hoursPerDay); days = String(a.daysPerMonth)
                useLabel = a.labelKWhPerDay != nil
                labelKWh = a.labelKWhPerDay.map { String($0) } ?? ""
            }
        }
    }
    private func save() {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty,
              let q = Int(count), (1...1000).contains(q),
              let d = Double(days), (0...31).contains(d),
              let w = Double(watts), w >= 0,
              let h = Double(hours), (0...24).contains(h) else {
            error = "Check the name, quantity, watts, hours (0–24), and days (0–31)."; return
        }
        var label: Double? = nil
        if useLabel {
            guard let kwh = Double(labelKWh), kwh >= 0, kwh.isFinite else {
                error = "Enter a valid energy-label kWh/day value."; return
            }
            label = kwh
        }
        var result = Appliance(name: name, count: q, watts: w, hoursPerDay: h, daysPerMonth: d, labelKWhPerDay: label)
        if let appliance { result.id = appliance.id }
        onSave(result); dismiss()
    }
}
