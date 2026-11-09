import Combine
import Foundation
import SwiftUI

struct ContentView: View {
    @AppStorage("esp32Host", store: SharedDefaults.store) private var esp32Host = "192.168.4.1"
    @AppStorage("esp32Port", store: SharedDefaults.store) private var esp32Port = 3333
    @AppStorage("esp32Token", store: SharedDefaults.store) private var esp32Token = ""
    @AppStorage(AppConstants.processingPausedKey, store: SharedDefaults.store) private var processingPaused = false
    @StateObject private var esp32Client = ESP32Client()
    @State private var latestResult = OCRResult.empty
    @State private var telemetry = CaptureTelemetry.empty
    @State private var automation = AutomationSnapshot.idle
    @State private var manualText = ""
    @State private var commandInFlight = false
    private let refreshTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            Form {
                Section("屏幕采集") {
                    HStack {
                        BroadcastPickerView()
                            .frame(width: 64, height: 64)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("启动屏幕广播")
                                .font(.headline)
                            Text("点左侧灰色广播按钮；也可在控制中心长按屏幕录制并选 OpenClaw Screen OCR。")
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
                    if let probeStatus = telemetry.networkProbeStatus {
                        LabeledContent("广播扩展网络探测", value: probeStatus)
                    }
                    if let latency = telemetry.networkProbeLatencyMilliseconds {
                        LabeledContent("探测延迟", value: String(format: "%.0f ms", latency))
                    }
                    Button(processingPaused ? "继续本地识别" : "暂停本地识别") {
                        processingPaused.toggle()
                    }
                    .disabled(telemetry.state == .idle || telemetry.state == .finished)
                    Text("停止系统广播请再次点击上方广播按钮，并在系统面板中选择停止。iOS 不允许应用绕过系统界面静默开始或停止跨 App 采集。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("任务状态") {
                    LabeledContent("状态", value: automation.state.rawValue)
                    LabeledContent("说明", value: automation.lastMessage)
                    if let comment = automation.requiredComment {
                        LabeledContent("目标评论", value: comment)
                    }
                    if let confidence = automation.confidence {
                        LabeledContent("识别置信度", value: String(format: "%.1f%%", confidence * 100))
                    }
                    if let countdown = automation.countdownSeconds {
                        LabeledContent("倒计时", value: "\(countdown) 秒")
                    }
                }

                Section("ESP32-S3 HTTP") {
                    TextField("IP 地址", text: $esp32Host)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.numbersAndPunctuation)
                    TextField("端口", value: $esp32Port, format: .number)
                        .keyboardType(.numberPad)
                    SecureField("设备配对令牌", text: $esp32Token)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    LabeledContent("连接状态", value: esp32Client.state.displayName)
                    LabeledContent("蓝牙 HID", value: esp32Client.bleConnected ? "已连接" : "未连接或未知")
                    if let temperature = esp32Client.temperatureC {
                        LabeledContent("芯片温度", value: String(format: "%.1f °C", temperature))
                    }
                    if esp32Client.overheated {
                        Text("温度保护已触发，设备拒绝普通操作")
                            .foregroundStyle(.red)
                    }
                    Button("测试连接") {
                        Task { await esp32Client.testConnection(host: esp32Host, port: esp32Port) }
                    }
                    Button("发送 PING") {
                        Task {
                            do {
                                _ = try await esp32Client.send(action: .ping, host: esp32Host, port: esp32Port)
                            } catch {
                                // The client publishes the device's actual rejection for display below.
                            }
                        }
                    }
                    Button("紧急停止", role: .destructive) {
                        Task { await esp32Client.emergencyStop(host: esp32Host, port: esp32Port) }
                    }
                    if let acknowledgement = esp32Client.lastAcknowledgement {
                        LabeledContent("最近确认", value: "#\(acknowledgement.id) \(acknowledgement.status.rawValue)")
                    }
                    if let error = esp32Client.lastCommandError {
                        Text("指令失败：\(error)")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    Text("正式协议使用 HTTP JSON、指令序号与执行确认；重复序号必须由设备拒绝重复执行。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("鼠标与键盘联调") {
                    Text("先在 iPhone 蓝牙设置中连接 OpenClaw Controller。下列操作由你逐次点击，用于确认指针方向、滚动和键盘映射。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Spacer()
                        Button("↑") { sendManual(.move, deltaY: -15) }
                        Spacer()
                    }
                    HStack {
                        Button("←") { sendManual(.move, deltaX: -15) }
                        Spacer()
                        Button("点击") { sendManual(.click) }
                        Spacer()
                        Button("→") { sendManual(.move, deltaX: 15) }
                    }
                    HStack {
                        Spacer()
                        Button("↓") { sendManual(.move, deltaY: 15) }
                        Spacer()
                    }
                    HStack {
                        Button("向上滚动") { sendManual(.scroll, deltaY: 1) }
                        Spacer()
                        Button("向下滚动") { sendManual(.scroll, deltaY: -1) }
                    }
                    TextField("测试英文和数字", text: $manualText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("发送测试文字") { sendManual(.type, text: manualText) }
                        .disabled(manualText.isEmpty || !manualText.unicodeScalars.allSatisfy { $0.value < 128 })
                    Text("当前固件仅支持 ASCII 键盘输入；中文评论需要另行验证输入法方案。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .disabled(commandInFlight)

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
                    if let confidence = latestResult.averageConfidence {
                        Text("平均置信度：\(String(format: "%.1f%%", confidence * 100))")
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
        automation = AutomationSnapshot.load()
    }

    private func sendManual(
        _ action: ControlAction,
        deltaX: Int? = nil,
        deltaY: Int? = nil,
        text: String? = nil
    ) {
        guard !commandInFlight else { return }
        commandInFlight = true
        Task {
            defer { commandInFlight = false }
            do {
                _ = try await esp32Client.send(
                    action: action,
                    host: esp32Host,
                    port: esp32Port,
                    deltaX: deltaX,
                    deltaY: deltaY,
                    text: text
                )
            } catch {
                // ESP32Client publishes the exact failure in the connection section.
            }
        }
    }
}
