import Foundation

enum ControlAction: String, Codable, CaseIterable {
    case move = "MOVE"
    case click = "CLICK"
    case press = "PRESS"
    case release = "RELEASE"
    case scroll = "SCROLL"
    case type = "TYPE"
    case stop = "STOP"
    case ping = "PING"
}

struct ControlCommand: Codable, Equatable {
    let id: UInt64
    let action: ControlAction
    var x: Int?
    var y: Int?
    var deltaX: Int?
    var deltaY: Int?
    var durationMilliseconds: Int?
    var text: String?
    let createdAt: Date

    init(
        id: UInt64,
        action: ControlAction,
        x: Int? = nil,
        y: Int? = nil,
        deltaX: Int? = nil,
        deltaY: Int? = nil,
        durationMilliseconds: Int? = nil,
        text: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.action = action
        self.x = x
        self.y = y
        self.deltaX = deltaX
        self.deltaY = deltaY
        self.durationMilliseconds = durationMilliseconds
        self.text = text
        self.createdAt = createdAt
    }
}

enum AcknowledgementStatus: String, Codable {
    case accepted = "ACCEPTED"
    case executed = "EXECUTED"
    case duplicate = "DUPLICATE"
    case rejected = "REJECTED"
    case failed = "FAILED"
}

struct ControlAcknowledgement: Codable, Equatable {
    let id: UInt64
    let status: AcknowledgementStatus
    let executedAt: Date?
    let message: String?
}

struct ESP32Health: Codable, Equatable {
    let status: String
    let device: String
    let protocolVersion: Int
}
