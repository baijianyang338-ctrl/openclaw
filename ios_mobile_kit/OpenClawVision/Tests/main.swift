import Foundation

func sample(_ rows: [(String, Float)]) -> OCRResult {
    OCRResult(
        lines: rows.map { $0.0 },
        capturedAt: Date(),
        observations: rows.map { RecognizedText(text: $0.0, confidence: $0.1) },
        averageConfidence: 0.99
    )
}

let valid = sample([
    ("福袋 参与条件", 0.95),
    ("指定评论：「祝你好运，ABC 123！」", 0.91),
    ("开奖倒计时 01:23", 0.93)
])
let extracted = RuleExtractor.extract(from: valid)
precondition(extracted?.requiredComment == "祝你好运，ABC 123！")
precondition(extracted?.countdownSeconds == 83)
precondition(extracted?.confidence == 0.91)

let conflicting = sample([
    ("福袋 参与条件", 0.95),
    ("指定评论：甲", 0.93),
    ("指定评论：乙", 0.92)
])
precondition(RuleExtractor.extract(from: conflicting) == nil)

let unrelated = sample([
    ("聊天中提到福袋", 0.96),
    ("评论：加油", 0.96)
])
precondition(RuleExtractor.extract(from: unrelated) == nil)

let lowConfidence = sample([
    ("福袋 参与条件", 0.99),
    ("指定评论：测试", 0.60)
])
let consensus = RuleConsensusEvaluator()
precondition(consensus.evaluate(RuleExtractor.extract(from: lowConfidence)!) == nil)
precondition(consensus.evaluate(extracted!) == nil)
precondition(consensus.evaluate(extracted!) == nil)
precondition(consensus.evaluate(extracted!) == extracted)
consensus.reset()
precondition(consensus.evaluate(extracted!) == nil)
print("RuleExtractor and consensus checks passed")

