import Foundation

struct OCRResult: Codable, Equatable {
    let lines: [String]
    let capturedAt: Date?

    static let empty = OCRResult(lines: [], capturedAt: nil)

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
