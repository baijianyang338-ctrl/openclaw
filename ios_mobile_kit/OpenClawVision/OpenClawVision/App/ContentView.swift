import Combine
import SwiftUI

struct ContentView: View {
    @AppStorage("esp32Host", store: SharedDefaults.store) private var esp32Host = "192.168.4.1"
    @AppStorage("esp32Port", store: SharedDefaults.store) private var esp32Port = 3333
    @State private var latestResult = OCRResult.empty
    private let refreshTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            Form {
                Section("屏幕采集") {
                    HStack {
                        BroadcastPickerView()
                            .frame(width: 52, height: 52)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("启动屏幕广播")
                                .font(.headline)
                            Text("由系统确认后，广播扩展会在本机识别画面文字。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("ESP32-S3 UDP") {
                    TextField("IP 地址", text: $esp32Host)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.numbersAndPunctuation)
                    TextField("端口", value: $esp32Port, format: .number)
                        .keyboardType(.numberPad)
                    Text("扩展会把最新 OCR 结果以 UTF-8 JSON 数据报发送到这个地址。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("最新识别结果") {
                    if latestResult.lines.isEmpty {
                        Text("尚无结果")
                            .foregroundStyle(.secondary)
                    } else {
                        Text(latestResult.lines.joined(separator: "\n"))
                            .textSelection(.enabled)
                    }
                    if let date = latestResult.capturedAt {
                        Text(date, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("隐私") {
                    Text("图像帧仅在广播扩展进程中处理，不写入照片或仓库。用户必须通过系统广播面板明确开始采集。")
                        .font(.caption)
                }
            }
            .navigationTitle("OpenClaw Vision")
        }
        .onAppear(perform: reloadResult)
        .onReceive(refreshTimer) { _ in reloadResult() }
    }

    private func reloadResult() {
        latestResult = OCRResult.load()
    }
}
