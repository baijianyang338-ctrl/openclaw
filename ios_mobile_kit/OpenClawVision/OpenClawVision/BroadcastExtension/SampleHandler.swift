import CoreMedia
import Foundation
import ReplayKit
import Vision

final class SampleHandler: RPBroadcastSampleHandler {
    private let processingQueue = DispatchQueue(label: "com.baijianyang.openclawvision.ocr", qos: .userInitiated)
    private let processingGate = DispatchSemaphore(value: 1)
    private var lastProcessedTimestamp = CMTime.invalid
    private let minimumFrameInterval = CMTime(seconds: 0.75, preferredTimescale: 600)
    private var telemetry = CaptureTelemetry.empty
    private var fpsWindowStartedAt = Date()
    private var fpsWindowFrameCount = 0
    private var lastDiagnosticLogAt = Date.distantPast
    private let stateMachine = AutomationStateMachine()
    private let ruleConsensus = RuleConsensusEvaluator()
    private var didProbeESP32 = false

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        lastProcessedTimestamp = .invalid
        fpsWindowStartedAt = Date()
        fpsWindowFrameCount = 0
        lastDiagnosticLogAt = .distantPast
        telemetry = .empty
        NSLog("OpenClawBroadcast started")
        telemetry.state = .running
        telemetry.save()
        stateMachine.reset()
        _ = stateMachine.transition(to: .searching, message: "正在画面中寻找福袋")
        ruleConsensus.reset()
        didProbeESP32 = false
    }

    override func broadcastPaused() {
        telemetry.state = .paused
        telemetry.save()
    }

    override func broadcastResumed() {
        telemetry.state = .running
        telemetry.save()
    }

    override func broadcastFinished() {
        telemetry.state = .finished
        telemetry.save()
        NSLog("OpenClawBroadcast finished after %lld video frames", telemetry.receivedFrameCount)
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        recordReceivedFrame()
        if SharedDefaults.store.bool(forKey: AppConstants.processingPausedKey) {
            telemetry.state = .paused
            telemetry.save()
            return
        }
        if telemetry.state == .paused {
            telemetry.state = .running
            telemetry.save()
        }

        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if lastProcessedTimestamp.isValid,
           CMTimeCompare(CMTimeSubtract(timestamp, lastProcessedTimestamp), minimumFrameInterval) < 0 {
            return
        }
        guard processingGate.wait(timeout: .now()) == .success else { return }
        lastProcessedTimestamp = timestamp

        processingQueue.async { [weak self] in
            defer { self?.processingGate.signal() }
            self?.recognizeText(in: pixelBuffer)
        }
    }

    private func recognizeText(in pixelBuffer: CVPixelBuffer) {
        let startedAt = Date()
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["zh-Hans", "en-US"]

        do {
            try VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up).perform([request])
            let recognized = (request.results ?? []).compactMap { observation -> RecognizedText? in
                guard let candidate = observation.topCandidates(1).first else { return nil }
                let bounds = observation.boundingBox
                let box = NormalizedRect(
                    x: Float(bounds.minX),
                    y: Float(bounds.minY),
                    width: Float(bounds.width),
                    height: Float(bounds.height)
                )
                return RecognizedText(text: candidate.string, confidence: candidate.confidence, box: box)
            }
            guard !recognized.isEmpty else {
                ruleConsensus.reset()
                return
            }
            let limited = Array(recognized.prefix(40))
            let confidence = limited.map(\.confidence).reduce(0, +) / Float(limited.count)
            let result = OCRResult(
                lines: limited.map(\.text),
                capturedAt: Date(),
                observations: limited,
                averageConfidence: confidence
            )
            result.save()
            telemetry.lastOCRDurationMilliseconds = Date().timeIntervalSince(startedAt) * 1_000
            telemetry.failureReason = nil
            telemetry.save()
            analyze(result)
        } catch {
            telemetry.state = .failed
            telemetry.failureReason = error.localizedDescription
            telemetry.save()
            NSLog("Vision OCR failed: %@", error.localizedDescription)
        }
    }

    private func analyze(_ result: OCRResult) {
        guard RuleExtractor.containsGiveaway(in: result) else {
            ruleConsensus.reset()
            if stateMachine.snapshot.state == .idle {
                _ = stateMachine.transition(to: .searching, message: "正在画面中寻找福袋")
            }
            return
        }

        if stateMachine.snapshot.state == .searching {
            _ = stateMachine.transition(to: .detected, message: "已发现福袋相关画面")
        }
        if stateMachine.snapshot.state == .detected {
            _ = stateMachine.transition(to: .readingRules, message: "正在读取参与规则")
        }
        guard stateMachine.snapshot.state == .readingRules else { return }
        guard let candidate = RuleExtractor.extract(from: result) else {
            ruleConsensus.reset()
            _ = stateMachine.transition(to: .readingRules, message: "未能唯一确认评论规则，继续识别")
            return
        }

        guard let confirmed = ruleConsensus.evaluate(candidate) else {
            _ = stateMachine.transition(to: .readingRules, message: "评论内容需连续三帧且置信度达标，正在复核")
            return
        }
        stateMachine.updateRule(
            comment: confirmed.requiredComment,
            confidence: confirmed.confidence,
            countdownSeconds: confirmed.countdownSeconds
        )
        _ = stateMachine.transition(to: .ready, message: "规则已确认，等待安全执行")
        probeESP32Health()
    }

    private func probeESP32Health() {
        guard !didProbeESP32 else { return }
        didProbeESP32 = true
        let host = SharedDefaults.store.string(forKey: "esp32Host") ?? "192.168.4.1"
        guard let token = SharedDefaults.store.string(forKey: "esp32Token"), !token.isEmpty else {
            telemetry.networkProbeStatus = "未配置设备配对令牌"
            telemetry.save()
            return
        }
        let savedPort = SharedDefaults.store.integer(forKey: "esp32Port")
        let port = savedPort == 0 ? 3333 : savedPort
        guard (1...65535).contains(port),
              var components = URLComponents(string: "http://\(host)") else {
            telemetry.networkProbeStatus = "ESP32 地址无效"
            telemetry.save()
            return
        }
        components.port = port
        components.path = "/v1/health"
        guard let url = components.url else {
            telemetry.networkProbeStatus = "ESP32 地址无效"
            telemetry.save()
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 3
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let startedAt = Date()
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            self?.processingQueue.async { [weak self] in
                guard let self, self.telemetry.state == .running else { return }
                self.telemetry.lastNetworkProbeAt = Date()
                self.telemetry.networkProbeLatencyMilliseconds = Date().timeIntervalSince(startedAt) * 1_000
                if let error {
                    self.telemetry.networkProbeStatus = "连接失败：\(error.localizedDescription)"
                } else if let http = response as? HTTPURLResponse,
                          http.statusCode == 200,
                          let data,
                          let health = try? JSONDecoder().decode(ESP32Health.self, from: data),
                          health.protocolVersion == 1 {
                    self.telemetry.networkProbeStatus = "已响应：\(health.device)"
                } else {
                    self.telemetry.networkProbeStatus = "健康检查响应无效"
                }
                self.telemetry.save()
            }
        }.resume()
    }

    private func recordReceivedFrame() {
        let now = Date()
        telemetry.receivedFrameCount += 1
        telemetry.lastFrameAt = now
        fpsWindowFrameCount += 1
        if now.timeIntervalSince(lastDiagnosticLogAt) >= 5 {
            NSLog("OpenClawBroadcast received %lld video frames", telemetry.receivedFrameCount)
            lastDiagnosticLogAt = now
        }
        let elapsed = now.timeIntervalSince(fpsWindowStartedAt)
        if elapsed >= 1 {
            telemetry.framesPerSecond = Double(fpsWindowFrameCount) / elapsed
            fpsWindowStartedAt = now
            fpsWindowFrameCount = 0
            telemetry.save()
        }
    }

}

