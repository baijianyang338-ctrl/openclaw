import Foundation

struct ExtractedRule: Equatable {
    let requiredComment: String
    let confidence: Float
    let countdownSeconds: Int?
}

enum RuleExtractor {
    static func containsGiveaway(in result: OCRResult) -> Bool {
        let text = result.lines.joined(separator: " ")
        return text.contains("福袋") || text.contains("参与条件") || text.contains("开奖")
    }

    static func extract(from result: OCRResult) -> ExtractedRule? {
        let allText = result.lines.joined(separator: " ")
        guard allText.contains("福袋"),
              allText.contains("参与条件") || allText.contains("指定评论") || allText.contains("评论要求") else {
            return nil
        }
        let observations = result.observations ?? result.lines.map {
            RecognizedText(text: $0, confidence: result.averageConfidence ?? 0)
        }
        let pattern = #"(?:指定|要求)?(?:评论|发送|输入|口令)(?:内容|文字)?[：:]\s*(.+)$"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return nil }
        var candidates: [String: Float] = [:]
        for observation in observations {
            let line = observation.text
            guard let match = expression.firstMatch(
                in: line,
                range: NSRange(line.startIndex..<line.endIndex, in: line)
            ), let range = Range(match.range(at: 1), in: line) else { continue }
            let raw = String(line[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            let comment = unquote(raw)
            guard !comment.isEmpty, comment.count <= 80 else { continue }
            candidates[comment] = min(candidates[comment] ?? 1, observation.confidence)
        }
        guard candidates.count == 1, let candidate = candidates.first else { return nil }
        return ExtractedRule(
            requiredComment: candidate.key,
            confidence: candidate.value,
            countdownSeconds: extractCountdown(from: result.lines)
        )
    }

    private static func unquote(_ text: String) -> String {
        let pairs: [(Character, Character)] = [("「", "」"), ("『", "』"), ("“", "”"), ("\"", "\"")]
        for (left, right) in pairs where text.first == left && text.last == right && text.count >= 2 {
            return String(text.dropFirst().dropLast())
        }
        return text
    }

    private static func extractCountdown(from lines: [String]) -> Int? {
        let text = lines.joined(separator: " ")
        if let expression = try? NSRegularExpression(pattern: #"(\d{1,2}):(\d{2})"#),
           let match = expression.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)),
           let minuteRange = Range(match.range(at: 1), in: text),
           let secondRange = Range(match.range(at: 2), in: text),
           let minutes = Int(text[minuteRange]),
           let seconds = Int(text[secondRange]) {
            return minutes * 60 + seconds
        }
        if let expression = try? NSRegularExpression(pattern: #"(\d{1,4})\s*秒"#),
           let match = expression.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)),
           let range = Range(match.range(at: 1), in: text) {
            return Int(text[range])
        }
        return nil
    }
}

final class RuleConsensusEvaluator {
    private var previousComment: String?
    private var consecutiveMatches = 0
    private let requiredMatches: Int
    private let minimumConfidence: Float

    init(requiredMatches: Int = 3, minimumConfidence: Float = 0.80) {
        self.requiredMatches = requiredMatches
        self.minimumConfidence = minimumConfidence
    }

    func evaluate(_ rule: ExtractedRule) -> ExtractedRule? {
        guard rule.confidence >= minimumConfidence else {
            previousComment = nil
            consecutiveMatches = 0
            return nil
        }
        if previousComment == rule.requiredComment {
            consecutiveMatches += 1
        } else {
            previousComment = rule.requiredComment
            consecutiveMatches = 1
        }
        return consecutiveMatches >= requiredMatches ? rule : nil
    }

    func reset() {
        previousComment = nil
        consecutiveMatches = 0
    }
}

