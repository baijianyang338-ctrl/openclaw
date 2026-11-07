import CoreMedia
import Foundation
import ReplayKit
import Vision

final class SampleHandler: RPBroadcastSampleHandler {
    private let processingQueue = DispatchQueue(label: "com.baijianyang.openclawvision.ocr", qos: .userInitiated)
    private var lastProcessedTimestamp = CMTime.invalid
    private let minimumFrameInterval = CMTime(seconds: 0.75, preferredTimescale: 600)
    private var telemetry = CaptureTelemetry.empty
    private var fpsWindowStartedAt = Date()
    private var fpsWindowFrameCount = 0
    private let stateMachine = AutomationStateMachine()
    private let ruleConsensus = RuleConsensusEvaluator()

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        lastProcessedTimestamp = .invalid
        fpsWindowStartedAt = Date()
        fpsWindowFrameCount = 0
        telemetry = .empty
        telemetry.state = .running
        telemetry.save()
        stateMachine.reset()
        _ = stateMachine.transition(to: .searching, message: "正在画面中寻找福袋")
        ruleConsensus.reset()
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
        lastProcessedTimestamp = timestamp

        processingQueue.async { [weak self] in
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
                return RecognizedText(text: candidate.string, confidence: candidate.confidence)
            }
            guard !recognized.isEmpty else { return }
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
        guard stateMachine.snapshot.state == .readingRules,
              let candidate = RuleExtractor.extract(from: result) else { return }

        guard let confirmed = ruleConsensus.evaluate(candidate) else {
            _ = stateMachine.transition(to: .readingRules, message: "评论内容需连续两帧一致，正在复核")
            return
        }
        stateMachine.updateRule(
            comment: confirmed.requiredComment,
            confidence: confirmed.confidence,
            countdownSeconds: confirmed.countdownSeconds
        )
        _ = stateMachine.transition(to: .ready, message: "规则已确认，等待安全执行")
    }

    private func recordReceivedFrame() {
        let now = Date()
        telemetry.receivedFrameCount += 1
        telemetry.lastFrameAt = now
        fpsWindowFrameCount += 1
        let elapsed = now.timeIntervalSince(fpsWindowStartedAt)
        if elapsed >= 1 {
            telemetry.framesPerSecond = Double(fpsWindowFrameCount) / elapsed
            fpsWindowStartedAt = now
            fpsWindowFrameCount = 0
            telemetry.save()
        }
    }

}
