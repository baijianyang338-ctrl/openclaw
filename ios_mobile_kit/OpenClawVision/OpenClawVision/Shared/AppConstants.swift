import Foundation

enum AppConstants {
    static let appGroupIdentifier = "group.com.baijianyang.openclawvision"
    static var broadcastExtensionBundleIdentifier: String {
        // Free signing tools can rewrite the app and extension bundle identifiers.
        let appIdentifier = Bundle.main.bundleIdentifier ?? "com.baijianyang.openclawvision"
        return "\(appIdentifier).broadcast"
    }
    static let ocrResultKey = "latestOCRResult"
    static let captureTelemetryKey = "captureTelemetry"
    static let processingPausedKey = "captureProcessingPaused"
    static let automationSnapshotKey = "automationSnapshot"
}

enum SharedDefaults {
    static let store = UserDefaults(suiteName: AppConstants.appGroupIdentifier) ?? .standard
}
