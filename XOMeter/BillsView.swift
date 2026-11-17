import SwiftUI
import PhotosUI
import UIKit

struct BillsView: View {
    @EnvironmentObject private var store: XOStore
    @State private var photo: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var scannedText = ""
    @State private var scanning = false
    @State private var cameraOpen = false
    @State private var sharePDF: PDFItem?
    @State private var status = "Scan a previous bill to suggest its readings and amounts."
    @State private var prev = ""
    @State private var pres = ""
    @State private var charge = ""
    @State private var usage = ""
    @State private var arrears = ""
    @State private var useAsReference = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Bills & Statements").font(.largeTitle.bold())
                GlassPanel {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Scan a previous bill").font(.headline)
                        HStack(spacing: 10) {
                            Button { cameraOpen = true } label: { Label("Camera", systemImage: "camera") }
                                .buttonStyle(XOButtonStyle())
                                .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
                            PhotosPicker(selection: $photo, matching: .images) {
                                Label("Gallery", systemImage: "photo").font(.subheadline.bold())
                                    .frame(maxWidth: .infinity).padding(14)
                                    .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 15))
                            }.buttonStyle(.plain)
                        }
                        if let image { Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 230).clipShape(RoundedRectangle(cornerRadius: 12)) }
                        if scanning { ProgressView("Reading the statement…").tint(XOTheme.accent) }
                        Text(status).font(.caption).foregroundStyle(XOTheme.muted)
                        if !scannedText.isEmpty {
                            DisclosureGroup("Show raw recognized text") {
                                Text(scannedText).font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
                            }.font(.caption)
                        }
                    }
                }
                GlassPanel {
                    VStack(alignment: .leading, spacing: 11) {
                        Text("Review bill data").font(.headline)
                        Text("OCR suggestions are unverified. Check the bill before updating your calculation reference.")
                            .font(.caption).foregroundStyle(XOTheme.muted)
                        field("PREV — previous reading", $prev)
                        field("PRES — present reading", $pres)
                        field("USAGE — billed kWh", $usage)
                        field("CURRENT BILL — ₱", $charge)
                        field("ARREARS — ₱ (optional)", $arrears)
                        Toggle("Use as next billing reference", isOn: $useAsReference)
                            .tint(XOTheme.accentGlow).font(.subheadline)
                        Button("Save verified bill reference") {
                            guard let p = Double(prev), let c = Double(pres), c >= p,
                                  let bill = Double(charge), bill >= 0,
                                  let kwh = Double(usage), kwh > 0 else {
                                status = "Enter valid previous/present readings, kWh usage, and current bill."
                                return
                            }
                            let difference = c-p
                            guard abs(difference-kwh) < 1.01 else {
                                status = "Reading difference (\(difference.formatted())) does not match stated usage (\(kwh.formatted())). Check multiplier and OCR."
                                return
                            }
                            store.saveVerifiedReference(previous: p, present: c, kWh: kwh, charges: bill, arrears: max(0, Double(arrears) ?? 0), useAsReference: useAsReference)
                            status = "Verified bill recorded. \(useAsReference ? "Next-period reference updated." : "Existing billing reference unchanged.")"
                        }.buttonStyle(XOButtonStyle())
                    }
                }
                GlassPanel {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Estimated billing slip").font(.headline)
                        Text("UNOFFICIAL ESTIMATE • NOT A UTILITY BILL OR PROOF OF PAYMENT")
                            .font(.caption2.bold()).foregroundStyle(XOTheme.accent)
                        row("Provider reference", "ZANECO")
                        row("Previous", "\(store.previousReading.formatted()) kWh")
                        row("Present", "\(store.currentReading.formatted()) kWh")
                        row("Consumption", "\(store.usage.formatted()) kWh")
                        row("Estimated current charges", Billing.pesos(store.estimate))
                        row("Confirmed unpaid balance", Billing.pesos(store.arrears))
                        Divider()
                        row("Estimated total", Billing.pesos(store.estimate + store.arrears), strong: true)
                        Button("Save estimate to history") { store.recordEstimatedBill() }
                            .buttonStyle(XOButtonStyle())
                        Button {
                            if let url = PDFStatement.generate(store: store) { sharePDF = PDFItem(url: url) }
                        } label: {
                            Label("Export PDF / Print / Share", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity).padding(11)
                        }.buttonStyle(.bordered)
                    }
                }
                if !store.bills.isEmpty {
                    Text("Billing history").font(.title3.bold())
                    ForEach(store.bills) { bill in
                        GlassPanel {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(bill.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption).foregroundStyle(XOTheme.muted)
                                Text(Billing.pesos(bill.total)).font(.title3.bold())
                                Text("\(bill.kWh.formatted()) kWh • \(bill.source)")
                                    .font(.caption).foregroundStyle(XOTheme.muted)
                            }
                        }
                    }
                }
            }.padding(17)
        }
        .sheet(isPresented: $cameraOpen) {
            CameraCapture { selected in image = selected; Task { await recognize(selected) } }.ignoresSafeArea()
        }
        .onChange(of: photo) { _, selected in
            Task {
                guard let data = try? await selected?.loadTransferable(type: Data.self), let img = UIImage(data: data) else { return }
                image = img
                await recognize(img)
            }
        }
        .sheet(item: $sharePDF) { item in ShareSheet(items: [item.url]) }
    }
    @MainActor private func recognize(_ selected: UIImage) async {
        scanning = true
        do {
            let result = try await OCRService.recognize(selected)
            scannedText = result.text
            let suggestions = BillParser.parse(result.text)
            if let v = suggestions.previous { prev = String(v) }
            if let v = suggestions.present { pres = String(v) }
            if let v = suggestions.usage { usage = String(v) }
            if let v = suggestions.currentBill { charge = String(v) }
            if let v = suggestions.arrears { arrears = String(v) }
            status = "Recognition finished. Review detected values against the photo; manually enter anything missed."
        } catch { status = "Could not recognize bill: \(error.localizedDescription). Enter details manually." }
        scanning = false
    }
    private func field(_ label: String, _ value: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.caption).foregroundStyle(XOTheme.muted)
            TextField(label, text: value).keyboardType(.decimalPad).padding(11)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 11))
        }
    }
    private func row(_ label: String, _ value: String, strong: Bool = false) -> some View {
        HStack {
            Text(label).foregroundStyle(strong ? .white : XOTheme.muted)
            Spacer(minLength: 8)
            Text(value).fontWeight(strong ? .bold : .regular)
        }.font(strong ? .headline : .subheadline)
    }
}

struct PDFItem: Identifiable { let id = UUID(); let url: URL }
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
