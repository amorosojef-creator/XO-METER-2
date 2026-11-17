import Foundation

// Conservative parser: returns suggestions to verify, not trusted financial data.
struct BillSuggestions {
    var previous: Double?
    var present: Double?
    var multiplier: Double?
    var usage: Double?
    var rate: Double?
    var currentBill: Double?
    var arrears: Double?
    var totalDue: Double?
    var periodText: String?
    var lines: [BillLine] = []

    /// Human-readable problems the review screen should show before the user confirms.
    var warnings: [String] {
        var out: [String] = []
        if let p = previous, let c = present, c < p { out.append("Present reading is lower than previous.") }
        if let p = previous, let c = present, let u = usage {
            let expected = Billing.consumption(previous: p, present: c, multiplier: multiplier ?? 1)
            if abs(expected - u) > 0.5 { out.append("kWh used does not match (PRES − PREV) × multiplier.") }
        }
        if let cb = currentBill, !lines.isEmpty, !Billing.reconciles(lines: lines, statedTotal: cb, tolerance: 0.05) {
            out.append("Itemized charges do not add up to the current bill; check each line.")
        }
        return out
    }
}

enum BillParser {
    static func numbers(_ s: String) -> [Double] {
        guard let re = try? NSRegularExpression(pattern: #"-?\d[\d,]*(?:\.\d+)?"#) else { return [] }
        let ns = s as NSString
        return re.matches(in: s, range: NSRange(location: 0, length: ns.length)).compactMap {
            Double(ns.substring(with: $0.range).replacingOccurrences(of: ",", with: ""))
        }
    }

    private static let chargeWords = ["generation", "transmission", "distribution", "system loss", "subsidy", "vat",
                                      "tax", "fit-all", "fit all", "universal", "lifeline", "metering", "supply",
                                      "retail", "missionary", "environmental", "npc", "stranded", "adjustment", "surcharge"]

    static func parse(_ text: String) -> BillSuggestions {
        var result = BillSuggestions()
        let lines = text.components(separatedBy: .newlines)
        for (index, line) in lines.enumerated() {
            let t = line.lowercased()
            let values = numbers(line)
            if t.contains("billing rate"), let n = values.last { result.rate = n }
            if t.contains("current bill"), let n = values.last { result.currentBill = n }
            if t.contains("total amount due"), let n = values.last { result.totalDue = n }
            if t.contains("total arrears"), let n = values.last { result.arrears = n }
            if t.contains("multiplier") || t.contains("mult."), let n = values.last, n > 0, n <= 1000 { result.multiplier = n }
            if t.contains("billing period") || t.contains("period covered") {
                let tail = line.split(separator: ":", maxSplits: 1).dropFirst().first.map(String.init) ?? line
                result.periodText = tail.trimmingCharacters(in: .whitespaces)
            }
            // Itemized charge: a named charge line ending in an amount with centavos.
            if !t.contains("total"), !t.contains("current bill"), !t.contains("arrears"),
               chargeWords.contains(where: { t.contains($0) }),
               let re = try? NSRegularExpression(pattern: #"^(.*?[A-Za-z\)])\s*[:.\-]*\s*(-?\d[\d,]*\.\d{2})\s*$"#),
               let m = re.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length)),
               m.numberOfRanges == 3 {
                let ns = line as NSString
                let name = ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespaces)
                if let amount = Double(ns.substring(with: m.range(at: 2)).replacingOccurrences(of: ",", with: "")) {
                    result.lines.append(BillLine(name: name, amount: amount))
                }
            }
            // Only infer paired readings when headings and values appear in nearby rows.
            if t.contains("pres") && t.contains("prev") {
                for nearby in lines.dropFirst(index + 1).prefix(4) {
                    let nums = numbers(nearby)
                    if nums.count >= 4 && nums[1] > 1000 && nums[2] > 1000 {
                        result.present = nums[1]; result.previous = nums[2]
                        result.usage = nums[3]
                        break
                    }
                }
            }
        }
        return result
    }
}
