import Combine
import Foundation
import SwiftUI

struct ContentView: View {
    @AppStorage("esp32Host", store: SharedDefaults.store) private var esp32Host = "192.168.4.1"
    @AppStorage("esp32Port", store: SharedDefaults.store) private var esp32Port = 3333
    @AppStorage(AppConstants.processingPausedKey, store: SharedDefaults.store) private var processingPaused = false
    @State private var latestResult = OCRResult.empty
    @State private var telemetry = CaptureTelemetry.empty
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
                    LabeledContent("状态", value: telemetry.state.displayName)
                    LabeledContent("实际接收帧率", value: String(format: "%.1f FPS", telemetry.framesPerSecond))
                    LabeledContent("已接收帧数", value: telemetry.receivedFrameCount.formatted())
                    if let duration = telemetry.lastOCRDurationMilliseconds {
                        LabeledContent("最近 OCR 延迟", value: String(format: "%.0f ms", duration))
                    }
                    if let lastFrameAt = telemetry.lastFrameAt {
                        LabeledContent("最近画面", value: lastFrameAt.formatted(date: .omitted, time: .standard))
                    }
                    if let failureReason = telemetry.failureReason {
                        Text("失败原因：\(failureReason)")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    Button(processingPaused ? "继续本地识别" : "暂停本地识别") {
                        processingPaused.toggle()
                    }
                    .disabled(telemetry.state == .idle || telemetry.state == .finished)
                    Text("停止系统广播请再次点击上方广播按钮，并在系统面板中选择停止。iOS 不允许应用绕过系统界面静默开始或停止跨 App 采集。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
        telemetry = CaptureTelemetry.load()
    }
}
