import Foundation

enum CaptureState: String, Codable {
    case idle
    case running
    case paused
    case finished
    case failed

    var displayName: String {
        switch self {
        case .idle: return "未开始"
        case .running: return "采集中"
        case .paused: return "识别已暂停"
        case .finished: return "已停止"
        case .failed: return "失败"
        }
    }
}

struct CaptureTelemetry: Codable, Equatable {
    var state: CaptureState
    var framesPerSecond: Double
    var receivedFrameCount: Int
    var lastFrameAt: Date?
    var lastOCRDurationMilliseconds: Double?
    var failureReason: String?

    static let empty = CaptureTelemetry(
        state: .idle,
        framesPerSecond: 0,
        receivedFrameCount: 0,
        lastFrameAt: nil,
        lastOCRDurationMilliseconds: nil,
        failureReason: nil
    )

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        SharedDefaults.store.set(data, forKey: AppConstants.captureTelemetryKey)
    }

    static func load() -> CaptureTelemetry {
        guard let data = SharedDefaults.store.data(forKey: AppConstants.captureTelemetryKey),
              let telemetry = try? JSONDecoder().decode(CaptureTelemetry.self, from: data) else {
            return .empty
        }
        return telemetry
    }
}
