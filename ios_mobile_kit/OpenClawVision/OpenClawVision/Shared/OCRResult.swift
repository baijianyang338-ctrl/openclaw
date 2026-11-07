import Foundation

struct RecognizedText: Codable, Equatable {
    let text: String
    let confidence: Float
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
