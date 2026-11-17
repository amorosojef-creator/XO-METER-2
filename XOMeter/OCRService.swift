import Foundation
import UIKit
import Vision

struct OCRResult {
    let lines: [String]
    var text: String { lines.joined(separator: "\n") }
    var analysis: MeterTextAnalysis { MeterTextExtractor.analyze(lines: lines) }
    var meterCandidates: [MeterCandidate] { analysis.readings }
}

enum OCRService {
    static func recognize(_ image: UIImage) async throws -> OCRResult {
        try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            request.recognitionLanguages = ["en-US"]
            if let cgImage = image.cgImage {
                try VNImageRequestHandler(cgImage: cgImage).perform([request])
            } else if let ciImage = CIImage(image: image) {
                try VNImageRequestHandler(ciImage: ciImage).perform([request])
            } else {
                throw NSError(domain: "XOMeter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Image could not be decoded"])
            }
            let observations = (request.results ?? []).sorted { a, b in
                if abs(a.boundingBox.midY - b.boundingBox.midY) > 0.02 { return a.boundingBox.midY > b.boundingBox.midY }
                return a.boundingBox.minX < b.boundingBox.minX
            }
            return OCRResult(lines: observations.compactMap { $0.topCandidates(1).first?.string })
        }.value
    }
}
