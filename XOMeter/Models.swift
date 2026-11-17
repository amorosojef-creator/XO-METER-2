import Foundation
import SwiftUI

struct MeterReading: Codable, Identifiable {
    var id = UUID()
    var date = Date()
    var value: Double
    var note: String = ""
}

struct Appliance: Codable, Identifiable {
    var id = UUID()
    var name: String
    var count: Int
    var watts: Double
    var hoursPerDay: Double
    var daysPerMonth: Double
    var labelKWhPerDay: Double? = nil
    var monthlyKWh: Double {
        Billing.applianceMonthlyKWh(count: count, watts: watts, hoursPerDay: hoursPerDay,
                                    daysPerMonth: daysPerMonth, labelKWhPerDay: labelKWhPerDay)
    }
}

struct BillRecord: Codable, Identifiable {
    var id = UUID()
    var date = Date()
    var provider: String = "ZANECO"
    var previousReading: Double
    var presentReading: Double
    var currentCharges: Double
    var arrears: Double
    var source: String = "Estimated — not official"
    var kWh: Double { max(0, presentReading - previousReading) }
    var total: Double { currentCharges + arrears }
}

@MainActor final class XOStore: ObservableObject {
    @Published var previousReading: Double = 9851
    @Published var currentReading: Double = 9991
    @Published var arrears: Double = 0
    @Published var multiplier: Double = 1
    @Published var monthlyBudget: Double = 2500
    @Published var historicalBill: Double = 2755.09
    @Published var historicalKWh: Double = 183
    @Published var meterReadings: [MeterReading] = []
    @Published var bills: [BillRecord] = []
    @Published var appliances: [Appliance] = [
        Appliance(name: "Samsung RT22FARBDSA Refrigerator", count: 1, watts: 100, hoursPerDay: 24, daysPerMonth: 30, labelKWhPerDay: 0.74),
        Appliance(name: "Clip-on Fan (estimate)", count: 1, watts: 20, hoursPerDay: 8, daysPerMonth: 30),
        Appliance(name: "Desktop PC (enter wattage)", count: 1, watts: 0, hoursPerDay: 0, daysPerMonth: 30),
        Appliance(name: "Devant TV (enter wattage)", count: 1, watts: 0, hoursPerDay: 0, daysPerMonth: 30)
    ]
    var usage: Double { Billing.consumption(previous: previousReading, present: currentReading, multiplier: multiplier) }
    var estimate: Double { Billing.predictedCharges(kWh: usage, historicalBill: historicalBill, historicalKWh: historicalKWh) }
    var effectiveRate: Double { historicalKWh > 0 ? historicalBill / historicalKWh : 0 }
    var applianceKWh: Double { appliances.reduce(0) { $0 + $1.monthlyKWh } }
    private struct Snapshot: Codable {
        let previousReading: Double
        let currentReading: Double
        let arrears: Double
        let multiplier: Double?
        let schemaVersion: Int?
        let monthlyBudget: Double?
        let historicalBill: Double
        let historicalKWh: Double
        let meterReadings: [MeterReading]
        let bills: [BillRecord]
        let appliances: [Appliance]
    }
    init() { restore() }
    func save() {
        let snapshot = Snapshot(previousReading: previousReading, currentReading: currentReading, arrears: arrears, multiplier: multiplier, schemaVersion: 2, monthlyBudget: monthlyBudget, historicalBill: historicalBill, historicalKWh: historicalKWh, meterReadings: meterReadings, bills: bills, appliances: appliances)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: "xo_store_v1")
    }
    private func restore() {
        guard let data = UserDefaults.standard.data(forKey: "xo_store_v1"), let s = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        previousReading = s.previousReading; currentReading = s.currentReading; arrears = s.arrears; multiplier = (s.multiplier ?? 1) > 0 ? (s.multiplier ?? 1) : 1; monthlyBudget = s.monthlyBudget ?? 2500
        historicalBill = s.historicalBill; historicalKWh = s.historicalKWh
        meterReadings = s.meterReadings; bills = s.bills; appliances = s.appliances
    }
    /// Full local backup as JSON (readings, bills, appliances, settings).
    func exportJSON() -> Data? {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        let snap = Snapshot(previousReading: previousReading, currentReading: currentReading, arrears: arrears, multiplier: multiplier, schemaVersion: 2, monthlyBudget: monthlyBudget, historicalBill: historicalBill, historicalKWh: historicalKWh, meterReadings: meterReadings, bills: bills, appliances: appliances)
        return try? enc.encode(snap)
    }
    func recordReading(_ value: Double) {
        currentReading = value
        meterReadings.insert(MeterReading(value: value), at: 0)
        save()
    }
    func saveVerifiedReference(previous: Double, present: Double, kWh: Double, charges: Double, arrears: Double, useAsReference: Bool) {
        bills.insert(BillRecord(previousReading: previous, presentReading: present, currentCharges: charges, arrears: arrears, source: "Verified imported bill"), at: 0)
        if useAsReference {
            previousReading = present
            historicalBill = charges
            historicalKWh = kWh
            currentReading = max(present, currentReading)
            self.arrears = arrears
        }
        save()
    }
    func recordEstimatedBill() {
        bills.insert(BillRecord(previousReading: previousReading, presentReading: currentReading, currentCharges: estimate, arrears: arrears), at: 0)
        save()
    }
}
