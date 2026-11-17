import Foundation

/// A possible cumulative-kWh reading. `display` keeps leading zeros ("009991"); `value` is numeric.
struct MeterCandidate: Equatable, Hashable {
    let display: String
    let value: Double
}

struct MeterTextAnalysis: Equatable {
    var readings: [MeterCandidate] = []
    var instantaneousKW: [Double] = []
    var serialLike: [String] = []
}

/// Pure-Foundation text analysis so it can be unit tested without UIKit/Vision.
/// Suggestions only: the user must always verify against the physical meter.
enum MeterTextExtractor {
    private static let serialWords = ["serial", "s/n", "sn:", "sn ", "acct", "account", "meter no", "meter #", "cust", "barcode", "model"]

    /// Meter-constant / nameplate lines ("1200 rev/kWh", "60 Hz", "imp/kWh") are not readings.
    private static let nameplateWords = ["rev/", "imp/", "/kwh", "pulse", " hz", "volt", "amp"]

    private static func matches(_ pattern: String, in line: String) -> [String] {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = line as NSString
        return re.matches(in: line, range: NSRange(location: 0, length: ns.length)).map { ns.substring(with: $0.range) }
    }

    static func analyze(lines: [String]) -> MeterTextAnalysis {
        var result = MeterTextAnalysis()
        var seen = Set<String>()
        for line in lines {
            let t = line.lowercased()
            if nameplateWords.contains(where: { t.contains($0) }) { continue }
            let hasKWh = t.contains("kwh")
            // Instantaneous power: "kw" that is not part of "kwh".
            let isKW = !hasKWh && matches(#"(?<![a-z])kw(?![a-z])"#, in: t).count > 0
            if isKW {
                for n in matches(#"\d+(?:[.,]\d+)?"#, in: line) {
                    if let v = Double(n.replacingOccurrences(of: ",", with: ".")) { result.instantaneousKW.append(v) }
                }
                continue
            }
            if serialWords.contains(where: { t.contains($0) }) {
                result.serialLike.append(contentsOf: matches(#"\d{4,}"#, in: line))
                continue
            }
            // 8+ digit runs are identifiers, never kWh registers on a residential meter.
            result.serialLike.append(contentsOf: matches(#"(?<![\d])\d{8,}(?![\d])"#, in: line))
            for raw in matches(#"(?<![\d.,])\d{4,7}(?:[.,]\d{1,2})?(?![\d])"#, in: line) {
                let display = raw.replacingOccurrences(of: ",", with: ".")
                guard let value = Double(display), !seen.contains(display) else { continue }
                seen.insert(display)
                result.readings.append(MeterCandidate(display: display, value: value))
            }
        }
        return result
    }
}
