import Foundation

var passed = 0
func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fatalError("FAILED: \(message)") }
    passed += 1
    print("PASS: \(message)")
}
func near(_ a: Double, _ b: Double, _ eps: Double = 0.005) -> Bool { abs(a - b) < eps }

// Anonymized fixtures. No customer identifiers.

// Arithmetic / continuity / multiplier
check(Billing.consumption(previous: 9668, present: 9851) == 183, "PREV 9668 -> PRES 9851 = 183 kWh")
check(Billing.consumption(previous: 9851, present: 9991) == 140, "9851 -> 9991 = 140 kWh")
check(Billing.consumption(previous: 9991, present: 9851) == 0, "Decreasing reading is invalid (0)")
check(Billing.consumption(previous: 100, present: 120, multiplier: 2) == 40, "Multiplier 2 doubles usage")
check(Billing.consumption(previous: 100, present: 120, multiplier: 0) == 0, "Zero multiplier invalid")
check(Billing.consumption(previous: .nan, present: 120) == 0, "NaN guarded")
check(Billing.isContinuous(previous: 9851, present: 9991), "Continuity: later reading continues")
check(!Billing.isContinuous(previous: 9991, present: 9851), "Continuity: rollback rejected")

// Rounding / estimates
check(Billing.round2(2107.7213) == 2107.72, "round2 down")
check(Billing.round2(0.126) == 0.13, "round2 up")
check(Billing.round2(.infinity) == 0, "round2 non-finite")
check(near(Billing.predictedCharges(kWh: 140, historicalBill: 2755.09, historicalKWh: 183), 2107.72), "Estimate for 140 kWh at October effective rate")
check(Billing.predictedCharges(kWh: 0, historicalBill: 2755.09, historicalKWh: 183) == 0, "Zero consumption")
check(Billing.predictedCharges(kWh: 100, historicalBill: 0, historicalKWh: 0) == 0, "Zero denominator guard")
check(near(Billing.effectiveRate(historicalBill: 2755.09, historicalKWh: 183), 15.0556, 0.001), "Effective rate per kWh")

// Itemized reconciliation
let items = [BillLine(name: "Generation", amount: 1000.50), BillLine(name: "Distribution", amount: 1500.25), BillLine(name: "Universal", amount: 254.34)]
check(Billing.sum(items) == 2755.09, "Itemized lines sum")
check(Billing.reconciles(lines: items, statedTotal: 2755.09), "Itemized lines reconcile with current bill")
check(!Billing.reconciles(lines: items, statedTotal: 2760.00), "Mismatch detected")
check(near(Billing.reconciliationGap(lines: items, statedTotal: 2760.00), 4.91), "Gap amount")

// Arrears: paid arrears must not roll into totals
check(Billing.totalDue(currentCharges: 2755.09, unpaidArrears: 0) == 2755.09, "Paid arrears excluded from total due")
check(Billing.totalDue(currentCharges: 2755.09, unpaidArrears: 3268.76) == 6023.85, "Unpaid arrears added to total due")

// Appliances
check(near(Billing.applianceMonthlyKWh(count: 1, watts: 100, hoursPerDay: 24, daysPerMonth: 30, labelKWhPerDay: 0.74), 22.2), "Inverter fridge label 0.74 kWh/day = 22.2 kWh per 30 days")
check(near(Billing.applianceMonthlyKWh(count: 1, watts: 100, hoursPerDay: 8, daysPerMonth: 30), 24), "Nameplate watts x hours")
check(near(Billing.applianceMonthlyKWh(count: 2, watts: 20, hoursPerDay: 8, daysPerMonth: 30), 9.6), "Quantity multiplies")
check(Billing.applianceMonthlyKWh(count: 0, watts: 100, hoursPerDay: 8, daysPerMonth: 30) == 0, "Zero quantity")

// Formatting
check(Billing.readingString(9991) == "9991", "Whole reading has no .0")
check(Billing.readingString(9991.5) == "9991.5", "Decimal reading preserved")

// Meter OCR extraction: serials and kW are not readings; leading zeros preserved
let analysis = MeterTextExtractor.analyze(lines: ["kWh", "009991", "SN 12345678", "3.2 kW", "50 Hz", "1200 rev/kWh", "00999.1"])
check(analysis.readings.map { $0.display } == ["009991", "00999.1"], "Reading candidates keep leading zeros")
check(analysis.readings.first?.value == 9991, "Leading-zero reading parses to 9991")
check(analysis.readings.last?.value == 999.1, "Decimal reading parses")
check(analysis.serialLike == ["12345678"], "Serial number separated")
check(analysis.instantaneousKW == [3.2], "Instantaneous kW separated")
check(MeterTextExtractor.analyze(lines: ["Meter No 55512345", "98765432"]).readings.isEmpty, "Long identifiers are never readings")

// ZANECO-style bill parsing
let sample = """
Billing Period: Sep 10 - Oct 10, 2026
PRES PREV KWH
Meter 1 9851 9668 183
Multiplier 1
Generation Charge 1,000.50
Distribution Charge 1,500.25
Universal Charges 254.34
Current Bill 2,755.09
Total Arrears 0.00
Total Amount Due 2,755.09
"""
let parsed = BillParser.parse(sample)
check(parsed.present == 9851 && parsed.previous == 9668, "Parser reads PRES/PREV")
check(parsed.usage == 183, "Parser reads kWh")
check(parsed.multiplier == 1, "Parser reads multiplier")
check(parsed.currentBill == 2755.09, "Parser reads current bill")
check(parsed.arrears == 0, "Parser reads arrears")
check(parsed.totalDue == 2755.09, "Parser reads total due")
check(parsed.periodText == "Sep 10 - Oct 10, 2026", "Parser reads billing period")
check(parsed.lines.count == 3, "Parser reads itemized lines")
check(parsed.warnings.isEmpty, "Consistent bill has no warnings")
var bad = parsed
bad.usage = 190
check(!bad.warnings.isEmpty, "Usage mismatch warns")
check(BillParser.parse("nothing useful here").present == nil, "Garbage text yields no readings")

print("All \(passed) tests passed")
