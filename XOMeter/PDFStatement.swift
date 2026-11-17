import UIKit
import PDFKit

@MainActor enum PDFStatement {
    static func generate(store: XOStore) -> URL? {
        let page = CGRect(x: 0, y: 0, width: 360, height: 580)
        let formatter = UIGraphicsPDFRenderer(bounds: page)
        let data = formatter.pdfData { ctx in
            ctx.beginPage()
            let lines: [(String, CGFloat, UIFont)] = [
                ("XO METER", 28, .boldSystemFont(ofSize: 25)),
                ("ESTIMATED ELECTRICITY STATEMENT", 68, .boldSystemFont(ofSize: 12)),
                ("UNOFFICIAL • NOT A UTILITY BILL OR PAYMENT RECEIPT", 92, .systemFont(ofSize: 9)),
                ("Generated: \(Date().formatted())", 128, .systemFont(ofSize: 12)),
                ("Provider reference: ZANECO", 160, .systemFont(ofSize: 12)),
                ("Previous reading: \(store.previousReading.formatted()) kWh", 200, .systemFont(ofSize: 13)),
                ("Present reading: \(store.currentReading.formatted()) kWh", 231, .systemFont(ofSize: 13)),
                ("Consumption: \(store.usage.formatted()) kWh", 262, .boldSystemFont(ofSize: 14)),
                ("Historical effective rate: \(Billing.pesos(store.effectiveRate))/kWh", 294, .systemFont(ofSize: 12)),
                ("Estimated charges: \(Billing.pesos(store.estimate))", 335, .systemFont(ofSize: 14)),
                ("Entered arrears: \(Billing.pesos(store.arrears))", 366, .systemFont(ofSize: 14)),
                ("ESTIMATED TOTAL: \(Billing.pesos(store.estimate + store.arrears))", 412, .boldSystemFont(ofSize: 17)),
                ("Actual tariff and billed charges may differ.", 464, .systemFont(ofSize: 11)),
                ("This statement does not confirm payment.", 485, .systemFont(ofSize: 11))
            ]
            for (str, y, font) in lines {
                (str as NSString).draw(at: CGPoint(x: 22, y: y), withAttributes: [.font: font, .foregroundColor: UIColor.black])
            }
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("XO-Meter-Estimated-Statement.pdf")
        do { try data.write(to: url); return url } catch { return nil }
    }
}
