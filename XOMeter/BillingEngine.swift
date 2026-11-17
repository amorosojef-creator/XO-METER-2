import Foundation

/// One itemized line on a bill (e.g. "Generation charge"). `amount` is in pesos.
struct BillLine: Equatable {
    var name: String
    var amount: Double
}

enum Billing {
    // MARK: Rounding

    /// Round to centavos (half-up, away from zero on ties) using Decimal to avoid binary drift.
    static func round2(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        var input = Decimal(value)
        var output = Decimal()
        NSDecimalRound(&output, &input, 2, .plain)
        return NSDecimalNumber(decimal: output).doubleValue
    }

    // MARK: Consumption

    /// consumption = (present - previous) x multiplier. Invalid input returns 0.
    static func consumption(previous: Double, present: Double, multiplier: Double = 1) -> Double {
        guard previous.isFinite, present.isFinite, multiplier.isFinite,
              previous >= 0, present >= previous, multiplier > 0 else { return 0 }
        return (present - previous) * multiplier
    }

    /// True when a new reading continues from the last confirmed one (no rollback).
    static func isContinuous(previous: Double, present: Double) -> Bool {
        previous.isFinite && present.isFinite && previous >= 0 && present >= previous
    }

    // MARK: Estimates (always an estimate, derived from a reference bill the user supplied)

    static func effectiveRate(historicalBill: Double, historicalKWh: Double) -> Double {
        guard historicalBill.isFinite, historicalBill >= 0, historicalKWh.isFinite, historicalKWh > 0 else { return 0 }
        return historicalBill / historicalKWh
    }

    static func predictedCharges(kWh: Double, historicalBill: Double, historicalKWh: Double) -> Double {
        guard kWh.isFinite, kWh >= 0 else { return 0 }
        return round2(kWh * effectiveRate(historicalBill: historicalBill, historicalKWh: historicalKWh))
    }

    // MARK: Itemized charges

    static func sum(_ lines: [BillLine]) -> Double {
        round2(lines.reduce(0) { $0 + ($1.amount.isFinite ? $1.amount : 0) })
    }

    /// Difference between the stated total and the sum of itemized lines (centavos-rounded).
    /// 0 means the lines reconcile with the printed total.
    static func reconciliationGap(lines: [BillLine], statedTotal: Double) -> Double {
        round2(statedTotal - sum(lines))
    }

    static func reconciles(lines: [BillLine], statedTotal: Double, tolerance: Double = 0.01) -> Bool {
        abs(reconciliationGap(lines: lines, statedTotal: statedTotal)) <= tolerance + 1e-9
    }

    // MARK: Arrears

    /// Total due = current charges + unpaid arrears. Paid arrears must be passed as 0.
    static func totalDue(currentCharges: Double, unpaidArrears: Double) -> Double {
        round2(max(0, currentCharges) + max(0, unpaidArrears))
    }

    // MARK: Appliances

    /// Monthly kWh. Prefers the energy-label kWh/day when given (variable-load devices).
    static func applianceMonthlyKWh(count: Int, watts: Double, hoursPerDay: Double,
                                    daysPerMonth: Double, labelKWhPerDay: Double? = nil) -> Double {
        guard count > 0, daysPerMonth.isFinite, daysPerMonth > 0 else { return 0 }
        if let label = labelKWhPerDay, label.isFinite, label >= 0 {
            return label * daysPerMonth * Double(count)
        }
        guard watts.isFinite, watts >= 0, hoursPerDay.isFinite, hoursPerDay >= 0 else { return 0 }
        return Double(count) * watts * hoursPerDay * daysPerMonth / 1000
    }

    // MARK: Formatting

    /// "9991" for whole readings, "9991.5" otherwise (never "9991.0").
    static func readingString(_ value: Double) -> String {
        guard value.isFinite else { return "" }
        return value == value.rounded() ? String(format: "%.0f", value) : String(value)
    }

    static func pesos(_ amount: Double) -> String {
        amount.formatted(.currency(code: "PHP"))
    }
}
