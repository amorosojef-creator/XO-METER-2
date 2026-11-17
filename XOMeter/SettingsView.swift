import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: XOStore
    @State private var previous = ""
    @State private var historical = ""
    @State private var historicalUnits = ""
    @State private var arrears = ""
    @State private var budget = ""
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                Text("Settings").font(.largeTitle.bold())
                GlassPanel {
                    VStack(alignment: .leading, spacing: 13) {
                        Text("Billing reference").font(.headline)
                        Text("Edit using your latest verified bill. These are historical values, not live utility tariffs.")
                            .font(.caption).foregroundStyle(XOTheme.muted)
                        field("Last bill's present reading", $previous)
                        field("Last current bill charges (₱)", $historical)
                        field("Last bill consumption (kWh)", $historicalUnits)
                        field("Confirmed unpaid balance (₱)", $arrears)
                        field("Monthly electricity budget (₱)", $budget)
                        Button("Save reference data") {
                            if let p = Double(previous), p >= 0 { store.previousReading = p }
                            if let h = Double(historical), h >= 0 { store.historicalBill = h }
                            if let k = Double(historicalUnits), k > 0 { store.historicalKWh = k }
                            if let a = Double(arrears), a >= 0 { store.arrears = a }
                            if let b = Double(budget), b > 0 { store.monthlyBudget = b }
                            store.save()
                        }.buttonStyle(XOButtonStyle())
                    }
                }
                GlassPanel {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Privacy & limitations").font(.headline)
                        Text("Prototype data is stored locally in UserDefaults. Avoid storing sensitive account numbers until encrypted storage is implemented.")
                        Text("Scanning uses Apple Vision locally. OCR text still requires user verification. Estimated statements are not official bills.")
                    }.font(.caption).foregroundStyle(XOTheme.muted)
                }
            }.padding(17)
        }.onAppear {
            previous = String(store.previousReading)
            historical = String(store.historicalBill)
            historicalUnits = String(store.historicalKWh)
            arrears = String(store.arrears)
            budget = String(store.monthlyBudget)
        }
    }
    private func field(_ title: String, _ value: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption).foregroundStyle(XOTheme.muted)
            TextField(title, text: value).keyboardType(.decimalPad).padding(12)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 11))
        }
    }
}
