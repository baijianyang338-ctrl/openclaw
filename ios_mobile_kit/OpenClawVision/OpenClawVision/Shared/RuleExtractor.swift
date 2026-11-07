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
        let patterns = [
            #"(?:评论|发送|输入|口令)[：:]\s*[「『“\"]?(.+?)[」』”\"]?$"#,
            #"(?:评论|发送|输入|口令)\s+(.+)$"#
        ]

        for line in result.lines {
            for pattern in patterns {
                guard let expression = try? NSRegularExpression(pattern: pattern),
                      let match = expression.firstMatch(
                        in: line,
                        range: NSRange(line.startIndex..<line.endIndex, in: line)
                      ),
                      match.numberOfRanges > 1,
                      let range = Range(match.range(at: 1), in: line) else { continue }
                let comment = String(line[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !comment.isEmpty else { continue }
                return ExtractedRule(
                    requiredComment: comment,
                    confidence: result.averageConfidence ?? 0,
                    countdownSeconds: extractCountdown(from: result.lines)
                )
            }
        }
        return nil
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

    init(requiredMatches: Int = 2, minimumConfidence: Float = 0.65) {
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
