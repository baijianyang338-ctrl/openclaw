import Foundation

struct NormalizedRect: Codable, Equatable {
    let x: Float
    let y: Float
    let width: Float
    let height: Float

    var centerX: Float { x + width / 2 }
    var centerY: Float { y + height / 2 }
}

struct RecognizedText: Codable, Equatable {
    let text: String
    let confidence: Float
    let box: NormalizedRect?

    init(text: String, confidence: Float, box: NormalizedRect? = nil) {
        self.text = text
        self.confidence = confidence
        self.box = box
    }
}

struct OCRResult: Codable, Equatable {
    let lines: [String]
    let capturedAt: Date?
    var observations: [RecognizedText]?
    var averageConfidence: Float?

    static let empty = OCRResult(lines: [], capturedAt: nil, observations: nil, averageConfidence: nil)

    init(
        lines: [String],
        capturedAt: Date?,
        observations: [RecognizedText]? = nil,
        averageConfidence: Float? = nil
    ) {
        self.lines = lines
        self.capturedAt = capturedAt
        self.observations = observations
        self.averageConfidence = averageConfidence
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        SharedDefaults.store.set(data, forKey: AppConstants.ocrResultKey)
    }

    static func load() -> OCRResult {
        guard let data = SharedDefaults.store.data(forKey: AppConstants.ocrResultKey),
              let result = try? JSONDecoder().decode(OCRResult.self, from: data) else {
            return .empty
        }
        return result
    }
}

