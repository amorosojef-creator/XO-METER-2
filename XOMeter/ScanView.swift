import SwiftUI
import PhotosUI
import UIKit

struct ScanView: View {
    @EnvironmentObject private var store: XOStore
    @State private var photo: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var scannedText = ""
    @State private var candidates: [MeterCandidate] = []
    @State private var ignoredNote = ""
    @State private var enteredReading = ""
    @State private var scanning = false
    @State private var showCamera = false
    @State private var status = "Photograph the kWh display, then verify the digits."
    @State private var saved = false
    private var number: Double? { Double(enteredReading.replacingOccurrences(of: ",", with: "")) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Scan & Verify").font(.largeTitle.bold())
                Text("Only the kWh reading determines energy used. Meter IDs and instantaneous kW values are different.")
                    .font(.subheadline).foregroundStyle(XOTheme.muted)
                GlassPanel {
                    VStack(spacing: 15) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 18).fill(.black.opacity(0.24))
                            if let image {
                                Image(uiImage: image).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 18))
                            } else {
                                VStack(spacing: 11) {
                                    Image(systemName: "viewfinder").font(.system(size: 60))
                                    Text("Align your meter display here").font(.caption)
                                }.foregroundStyle(XOTheme.muted)
                            }
                            RoundedRectangle(cornerRadius: 18).stroke(XOTheme.accentGlow.opacity(0.65), lineWidth: 1.5)
                            if scanning { ScanBeam().padding(8) }
                        }.frame(height: 260).clipped()
                        HStack(spacing: 10) {
                            Button { showCamera = true } label: { Label("Camera", systemImage: "camera") }
                                .buttonStyle(XOButtonStyle())
                                .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
                            PhotosPicker(selection: $photo, matching: .images) {
                                Label("Gallery", systemImage: "photo.on.rectangle")
                                    .font(.subheadline.bold()).frame(maxWidth: .infinity).padding(14)
                                    .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 15))
                            }.buttonStyle(.plain)
                        }
                        if scanning { ProgressView("Recognizing text…").tint(XOTheme.accent) }
                        Text(status).font(.caption).foregroundStyle(XOTheme.muted)
                    }
                }
                GlassPanel {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Verify present reading", systemImage: "checkmark.shield").font(.headline)
                        TextField("e.g. 009991", text: $enteredReading)
                            .keyboardType(.decimalPad).font(.title2.monospacedDigit())
                            .padding(12).background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                        if !candidates.isEmpty {
                            Text("Possible numbers — verify on the actual meter:")
                                .font(.caption).foregroundStyle(XOTheme.muted)
                            ScrollView(.horizontal) {
                                HStack {
                                    ForEach(candidates, id: \.self) { candidate in
                                        Button(candidate.display) { enteredReading = candidate.display }
                                            .buttonStyle(.bordered)
                                    }
                                }
                            }
                        }
                        if !ignoredNote.isEmpty {
                            Text(ignoredNote).font(.caption).foregroundStyle(XOTheme.muted)
                        }
                        HStack {
                            Text("Last official reading").foregroundStyle(XOTheme.muted)
                            Spacer()
                            Text("\(store.previousReading.formatted()) kWh")
                        }.font(.subheadline)
                        if let n = number, n >= store.previousReading {
                            HStack {
                                Text("Consumed since last bill")
                                Spacer()
                                Text("\(Billing.consumption(previous: store.previousReading, present: n).formatted()) kWh")
                                    .foregroundStyle(XOTheme.accent)
                            }.font(.subheadline.bold())
                        } else if !enteredReading.isEmpty {
                            Text("Enter a reading equal to or greater than the previous official reading.")
                                .foregroundStyle(.orange).font(.caption)
                        }
                        Button {
                            guard let n = number, n >= store.previousReading, n.isFinite else { return }
                            store.recordReading(n)
                            saved = true
                            status = "Verified reading saved to this device."
                        } label: { Label("Save verified reading", systemImage: "checkmark") }
                            .buttonStyle(XOButtonStyle())
                            .disabled(number == nil || (number ?? 0) < store.previousReading)
                    }
                }
                if !scannedText.isEmpty {
                    GlassPanel {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Detected text (not automatically trusted)").font(.headline)
                            Text(scannedText).font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
                        }
                    }
                }
            }.padding(17)
        }
        .sheet(isPresented: $showCamera) {
            CameraCapture { selected in image = selected; Task { await recognize(selected) } }
                .ignoresSafeArea()
        }
        .onChange(of: photo) { _, value in
            Task {
                guard let data = try? await value?.loadTransferable(type: Data.self), let selected = UIImage(data: data) else { return }
                image = selected
                await recognize(selected)
            }
        }
        .onAppear { if enteredReading.isEmpty { enteredReading = Billing.readingString(store.currentReading) } }
    }
    @MainActor private func recognize(_ selected: UIImage) async {
        scanning = true
        status = "Reading image…"
        do {
            let result = try await OCRService.recognize(selected)
            scannedText = result.text
            candidates = result.meterCandidates
            let a = result.analysis
            ignoredNote = (a.serialLike.isEmpty && a.instantaneousKW.isEmpty) ? "" :
                "Ignored as not kWh: \(a.serialLike.count) serial/account-style number(s), \(a.instantaneousKW.count) kW value(s)."
            status = "Review each digit against your photo. OCR may confuse the meter serial number with kWh."
        } catch { status = "OCR failed: \(error.localizedDescription). Enter the reading manually." }
        scanning = false
    }
}

struct ScanBeam: View {
    @State private var atBottom = false
    var body: some View {
        GeometryReader { geo in
            Rectangle().fill(XOTheme.accent).frame(height: 2.5)
                .shadow(color: XOTheme.accentGlow, radius: 8)
                .offset(y: atBottom ? geo.size.height - 3 : 0)
                .onAppear { withAnimation(.easeInOut(duration: 1.35).repeatForever(autoreverses: true)) { atBottom = true } }
        }.allowsHitTesting(false)
    }
}
