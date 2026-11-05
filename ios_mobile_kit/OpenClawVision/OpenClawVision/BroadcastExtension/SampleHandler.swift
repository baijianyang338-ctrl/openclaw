import CoreMedia
import Network
import ReplayKit
import Vision

final class SampleHandler: RPBroadcastSampleHandler {
    private let processingQueue = DispatchQueue(label: "com.baijianyang.openclawvision.ocr", qos: .userInitiated)
    private var lastProcessedTimestamp = CMTime.invalid
    private let minimumFrameInterval = CMTime(seconds: 0.75, preferredTimescale: 600)
    private var telemetry = CaptureTelemetry.empty
    private var fpsWindowStartedAt = Date()
    private var fpsWindowFrameCount = 0

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        lastProcessedTimestamp = .invalid
        fpsWindowStartedAt = Date()
        fpsWindowFrameCount = 0
        telemetry = .empty
        telemetry.state = .running
        telemetry.save()
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
            let lines = (request.results ?? []).compactMap { observation in
                observation.topCandidates(1).first?.string
            }
            guard !lines.isEmpty else { return }
            let result = OCRResult(lines: Array(lines.prefix(40)), capturedAt: Date())
            result.save()
            telemetry.lastOCRDurationMilliseconds = Date().timeIntervalSince(startedAt) * 1_000
            telemetry.failureReason = nil
            telemetry.save()
            sendToESP32(result)
        } catch {
            telemetry.state = .failed
            telemetry.failureReason = error.localizedDescription
            telemetry.save()
            NSLog("Vision OCR failed: %@", error.localizedDescription)
        }
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

    private func sendToESP32(_ result: OCRResult) {
        let defaults = SharedDefaults.store
        let host = defaults.string(forKey: "esp32Host") ?? "192.168.4.1"
        let storedPort = defaults.integer(forKey: "esp32Port")
        let portValue = storedPort == 0 ? 3333 : storedPort
        guard (1...65535).contains(portValue),
              let port = NWEndpoint.Port(rawValue: UInt16(portValue)),
              let payload = try? JSONEncoder().encode(result) else { return }

        let connection = NWConnection(host: NWEndpoint.Host(host), port: port, using: .udp)
        connection.start(queue: processingQueue)
        connection.send(content: payload, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
