import CoreMedia
import CoreImage
import Foundation
import ReplayKit
import Vision

final class SampleHandler: RPBroadcastSampleHandler {
    private let processingQueue = DispatchQueue(label: "com.baijianyang.openclawvision.ocr", qos: .userInitiated)
    private let processingGate = DispatchSemaphore(value: 1)
    private let iconContext = CIContext()
    private var lastProcessedTimestamp = CMTime.invalid
    private let minimumFrameInterval = CMTime(seconds: 0.75, preferredTimescale: 600)
    private var telemetry = CaptureTelemetry.empty
    private var fpsWindowStartedAt = Date()
    private var fpsWindowFrameCount = 0
    private var lastDiagnosticLogAt = Date.distantPast
    private let stateMachine = AutomationStateMachine()
    private let ruleConsensus = RuleConsensusEvaluator()
    private var didProbeESP32 = false
    private var consecutiveIconFrames = 0

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
        consecutiveIconFrames = 0
    }

    override func broadcastPaused() {
        telemetry.state = .paused
        telemetry.framesPerSecond = 0
        telemetry.save()
    }

    override func broadcastResumed() {
        fpsWindowStartedAt = Date()
        fpsWindowFrameCount = 0
        telemetry.state = .running
        telemetry.save()
    }

    override func broadcastFinished() {
        telemetry.state = .finished
        telemetry.framesPerSecond = 0
        telemetry.save()
        stateMachine.reset()
        NSLog("OpenClawBroadcast finished after %lld video frames", telemetry.receivedFrameCount)
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        recordReceivedFrame()
        if CrossProcessStore.data(forKey: AppConstants.processingPausedKey)?.first == 1 {
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
        let iconCandidate = detectGiveawayIcon(in: pixelBuffer)
        telemetry.iconCandidateConfidence = iconCandidate?.confidence
        telemetry.iconCandidateBox = iconCandidate?.box
        let request = VNRecognizeTextRequest()
        // Chinese activity rules need the neural recognition path. The fast path
        // produced Latin-looking garbage for real Douyin text on the test phone.
        request.recognitionLevel = .accurate
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
            if limited.filter({ $0.text.contains("OpenClaw Vision") }).count >= 2 {
                // Returning to the host app must not overwrite the last
                // third-party frame or start a new activity from our own UI.
                return
            }
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
            analyze(result, iconCandidate: iconCandidate)
        } catch {
            telemetry.state = .failed
            telemetry.failureReason = error.localizedDescription
            telemetry.save()
            NSLog("Vision OCR failed: %@", error.localizedDescription)
        }
    }

    private func analyze(_ result: OCRResult, iconCandidate: IconCandidate?) {
        let popupVisible = RuleExtractor.hasRulePopup(in: result)
        consecutiveIconFrames = iconCandidate == nil ? 0 : min(consecutiveIconFrames + 1, 3)
        if stateMachine.snapshot.state == .idle {
            _ = stateMachine.transition(to: .searching, message: "正在画面中寻找福袋图标")
        }
        if stateMachine.snapshot.state == .searching,
           consecutiveIconFrames >= 3 || popupVisible {
            _ = stateMachine.transition(to: .detected, message: "已发现福袋图标或活动弹窗")
        }
        if stateMachine.snapshot.state == .detected && popupVisible {
            _ = stateMachine.transition(to: .readingRules, message: "正在读取参与规则")
        }
        guard stateMachine.snapshot.state == .readingRules else { return }
        guard popupVisible else {
            ruleConsensus.reset()
            return
        }
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

    private struct IconCandidate {
        let box: NormalizedRect
        let confidence: Float
    }

    // Screen samples show a compact purple gift badge in the upper-left band.
    // This color/geometry detector is a candidate generator, not final proof
    // of a giveaway. Three frames or a rule popup are needed for state change.
    private func detectGiveawayIcon(in pixelBuffer: CVPixelBuffer) -> IconCandidate? {
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        let frame = image.extent
        guard frame.width > 0, frame.height > 0 else { return nil }
        let roi = CGRect(
            x: frame.width * 0.02,
            y: frame.height * 0.70,
            width: frame.width * 0.43,
            height: frame.height * 0.18
        )
        let columns = 120
        let rows = 64
        let local = image.cropped(to: roi)
            .transformed(by: CGAffineTransform(translationX: -roi.minX, y: -roi.minY))
            .transformed(by: CGAffineTransform(
                scaleX: CGFloat(columns) / roi.width,
                y: CGFloat(rows) / roi.height
            ))
        var pixels = [UInt8](repeating: 0, count: columns * rows * 4)
        pixels.withUnsafeMutableBytes { buffer in
            guard let address = buffer.baseAddress else { return }
            iconContext.render(
                local,
                toBitmap: address,
                rowBytes: columns * 4,
                bounds: CGRect(x: 0, y: 0, width: CGFloat(columns), height: CGFloat(rows)),
                format: .RGBA8,
                colorSpace: CGColorSpaceCreateDeviceRGB()
            )
        }
        let windowWidth = 24
        let windowHeight = 14
        var best = 0
        var bestX = 0
        var bestY = 0
        for y in stride(from: 0, through: rows - windowHeight, by: 2) {
            for x in stride(from: 0, through: columns - windowWidth, by: 2) {
                var count = 0
                for row in y..<(y + windowHeight) {
                    for column in x..<(x + windowWidth) {
                        let offset = (row * columns + column) * 4
                        let red = Int(pixels[offset])
                        let green = Int(pixels[offset + 1])
                        let blue = Int(pixels[offset + 2])
                        if red > 90 && blue > 90 && green * 5 < min(red, blue) * 4 {
                            count += 1
                        }
                    }
                }
                if count > best {
                    best = count
                    bestX = x
                    bestY = y
                }
            }
        }
        let ratio = Float(best) / Float(windowWidth * windowHeight)
        guard ratio >= 0.16 else { return nil }
        let box = NormalizedRect(
            x: Float((roi.minX + CGFloat(bestX) / CGFloat(columns) * roi.width) / frame.width),
            y: Float((roi.minY + CGFloat(bestY) / CGFloat(rows) * roi.height) / frame.height),
            width: Float(CGFloat(windowWidth) / CGFloat(columns) * roi.width / frame.width),
            height: Float(CGFloat(windowHeight) / CGFloat(rows) * roi.height / frame.height)
        )
        return IconCandidate(box: box, confidence: min(1, ratio / 0.27))
    }

    private func probeESP32Health() {
        guard !didProbeESP32 else { return }
        didProbeESP32 = true
        let host = CrossProcessStore.data(forKey: "esp32Host").flatMap { String(data: $0, encoding: .utf8) } ?? "192.168.4.1"
        guard let token = CrossProcessStore.data(forKey: "esp32Token").flatMap({ String(data: $0, encoding: .utf8) }), !token.isEmpty else {
            telemetry.networkProbeStatus = "未配置设备配对令牌"
            telemetry.save()
            return
        }
        let port = CrossProcessStore.data(forKey: "esp32Port")
            .flatMap { String(data: $0, encoding: .utf8) }
            .flatMap(Int.init) ?? 3333
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

