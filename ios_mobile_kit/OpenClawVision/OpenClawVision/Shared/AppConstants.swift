import Foundation

enum AppConstants {
    static let appGroupIdentifier = "group.com.baijianyang.openclawvision"
    static let broadcastExtensionBundleIdentifier = "com.baijianyang.openclawvision.broadcast"
    static let ocrResultKey = "latestOCRResult"
}

enum SharedDefaults {
    static let store = UserDefaults(suiteName: AppConstants.appGroupIdentifier) ?? .standard
}
