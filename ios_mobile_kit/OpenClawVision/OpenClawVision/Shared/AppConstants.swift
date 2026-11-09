import Foundation
import Security

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

enum CrossProcessStore {
    private static let service = "com.baijianyang.openclawvision.localbridge"
    static let usesAppGroup = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: AppConstants.appGroupIdentifier
    ) != nil

    @discardableResult
    static func set(_ data: Data, forKey key: String) -> Bool {
        if usesAppGroup {
            SharedDefaults.store.set(data, forKey: key)
            return true
        }
        let query = baseQuery(forKey: key)
        let update = [kSecValueData as String: data] as CFDictionary
        var status = SecItemUpdate(query as CFDictionary, update)
        if status == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            status = SecItemAdd(add as CFDictionary, nil)
        }
        if status != errSecSuccess {
            NSLog("OpenClawBridge write %@ failed: %d", key, status)
        }
        return status == errSecSuccess
    }

    static func data(forKey key: String) -> Data? {
        if usesAppGroup {
            return SharedDefaults.store.data(forKey: key)
        }
        var query = baseQuery(forKey: key)
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var value: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &value)
        if status != errSecSuccess && status != errSecItemNotFound {
            NSLog("OpenClawBridge read %@ failed: %d", key, status)
        }
        return status == errSecSuccess ? value as? Data : nil
    }

    private static func baseQuery(forKey key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
    }
}
