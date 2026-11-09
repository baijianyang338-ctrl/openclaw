import Foundation

enum AutomationState: String, Codable, CaseIterable, Hashable {
    case idle = "IDLE"
    case searching = "SEARCHING"
    case detected = "DETECTED"
    case readingRules = "READING_RULES"
    case ready = "READY"
    case executing = "EXECUTING"
    case verifying = "VERIFYING"
    case waitingResult = "WAITING_RESULT"
    case finished = "FINISHED"
    case error = "ERROR"
}

struct AutomationSnapshot: Codable, Equatable {
    var state: AutomationState
    var activityIdentifier: String?
    var requiredComment: String?
    var confidence: Float?
    var countdownSeconds: Int?
    var lastMessage: String
    var updatedAt: Date

    static let idle = AutomationSnapshot(
        state: .idle,
        activityIdentifier: nil,
        requiredComment: nil,
        confidence: nil,
        countdownSeconds: nil,
        lastMessage: "等待开始",
        updatedAt: Date()
    )

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        CrossProcessStore.set(data, forKey: AppConstants.automationSnapshotKey)
    }

    static func load() -> AutomationSnapshot {
        guard let data = CrossProcessStore.data(forKey: AppConstants.automationSnapshotKey),
              let snapshot = try? JSONDecoder().decode(AutomationSnapshot.self, from: data) else {
            return .idle
        }
        return snapshot
    }
}

final class AutomationStateMachine {
    private(set) var snapshot = AutomationSnapshot.load()

    private let allowedTransitions: [AutomationState: Set<AutomationState>] = [
        .idle: [.searching, .error],
        .searching: [.detected, .idle, .error],
        .detected: [.readingRules, .searching, .error],
        .readingRules: [.ready, .searching, .error],
        .ready: [.executing, .searching, .error],
        .executing: [.verifying, .error],
        .verifying: [.executing, .waitingResult, .error],
        .waitingResult: [.finished, .error],
        .finished: [.idle],
        .error: [.idle, .searching]
    ]

    @discardableResult
    func transition(to state: AutomationState, message: String) -> Bool {
        guard state == snapshot.state || allowedTransitions[snapshot.state, default: []].contains(state) else {
            fail("拒绝非法状态跳转：\(snapshot.state.rawValue) → \(state.rawValue)")
            return false
        }
        snapshot.state = state
        snapshot.lastMessage = message
        snapshot.updatedAt = Date()
        snapshot.save()
        return true
    }

    func updateRule(comment: String, confidence: Float, countdownSeconds: Int?) {
        snapshot.requiredComment = comment
        snapshot.confidence = confidence
        snapshot.countdownSeconds = countdownSeconds
        snapshot.updatedAt = Date()
        snapshot.save()
    }

    func reset() {
        snapshot = .idle
        snapshot.save()
    }

    func fail(_ reason: String) {
        snapshot.state = .error
        snapshot.lastMessage = reason
        snapshot.updatedAt = Date()
        snapshot.save()
    }
}
