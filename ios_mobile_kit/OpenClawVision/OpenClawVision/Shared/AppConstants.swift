import Foundation

enum AppConstants {
    static let appGroupIdentifier = "group.com.baijianyang.openclawvision"
    static let broadcastExtensionBundleIdentifier = "com.baijianyang.openclawvision.broadcast"
    static let ocrResultKey = "latestOCRResult"
    static let captureTelemetryKey = "captureTelemetry"
    static let processingPausedKey = "captureProcessingPaused"
    static let automationSnapshotKey = "automationSnapshot"
}

enum SharedDefaults {
    static let store = UserDefaults(suiteName: AppConstants.appGroupIdentifier) ?? .standard
}
