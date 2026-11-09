import ReplayKit
import SwiftUI

struct BroadcastPickerView: UIViewRepresentable {
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 64, height: 64))
        picker.preferredExtension = AppConstants.broadcastExtensionBundleIdentifier
        picker.showsMicrophoneButton = false
        picker.backgroundColor = .systemGray5
        picker.layer.cornerRadius = 12
        picker.clipsToBounds = true
        picker.accessibilityLabel = "启动屏幕广播"
        return picker
    }

    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}
