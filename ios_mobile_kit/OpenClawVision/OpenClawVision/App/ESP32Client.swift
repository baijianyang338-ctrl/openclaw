import Combine
import Foundation

@MainActor
final class ESP32Client: ObservableObject {
    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected(String)
        case failed(String)

        var displayName: String {
            switch self {
            case .disconnected: return "未连接"
            case .connecting: return "连接中"
            case .connected(let device): return "已连接：\(device)"
            case .failed(let reason): return "失败：\(reason)"
            }
        }
    }

    @Published private(set) var state: ConnectionState = .disconnected
    @Published private(set) var lastAcknowledgement: ControlAcknowledgement?
    @Published private(set) var lastCommandError: String?
    private static let commandIDKey = "openclaw.nextCommandID"
    private static let maximumCommandID: UInt64 = 9_007_199_254_740_991
    private var nextCommandID: UInt64

    init() {
        let stored = (UserDefaults.standard.object(forKey: Self.commandIDKey) as? NSNumber)?.uint64Value
        nextCommandID = stored.flatMap { (1...Self.maximumCommandID).contains($0) ? $0 : nil }
            ?? UInt64.random(in: 1...4_000_000_000_000_000)
        UserDefaults.standard.set(NSNumber(value: nextCommandID), forKey: Self.commandIDKey)
    }

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    func testConnection(host: String, port: Int) async {
        state = .connecting
        do {
            let health: ESP32Health = try await request(
                host: host,
                port: port,
                path: "/v1/health",
                method: "GET",
                body: nil
            )
            guard health.protocolVersion == 1 else {
                throw ClientError.invalidProtocolVersion(health.protocolVersion)
            }
            let details: String
            switch health.bleConnected {
            case true: details = "蓝牙已连接"
            case false: details = "蓝牙未连接"
            case nil: details = "蓝牙状态未知"
            }
            state = .connected("\(health.device)，\(details)" + (health.stopped == true ? "，急停已锁定" : ""))
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    @discardableResult
    func send(
        action: ControlAction,
        host: String,
        port: Int,
        x: Int? = nil,
        y: Int? = nil,
        deltaX: Int? = nil,
        deltaY: Int? = nil,
        text: String? = nil
    ) async throws -> ControlAcknowledgement {
        let command = ControlCommand(
            id: nextCommandID,
            action: action,
            x: x,
            y: y,
            deltaX: deltaX,
            deltaY: deltaY,
            text: text
        )
        nextCommandID = nextCommandID < Self.maximumCommandID ? nextCommandID + 1 : 1
        UserDefaults.standard.set(NSNumber(value: nextCommandID), forKey: Self.commandIDKey)
        let body = try encoder.encode(command)
        do {
            let acknowledgement: ControlAcknowledgement = try await request(
                host: host,
                port: port,
                path: "/v1/command",
                method: "POST",
                body: body
            )
            guard acknowledgement.id == command.id else { throw ClientError.mismatchedAcknowledgement }
            lastAcknowledgement = acknowledgement
            guard acknowledgement.status == .executed else {
                throw ClientError.commandNotExecuted(acknowledgement.status, acknowledgement.message)
            }
            lastCommandError = nil
            return acknowledgement
        } catch {
            lastCommandError = error.localizedDescription
            throw error
        }
    }

    func emergencyStop(host: String, port: Int) async {
        do {
            _ = try await send(action: .stop, host: host, port: port)
        } catch {
            state = .failed("急停发送失败：\(error.localizedDescription)")
        }
    }

    private func request<Response: Decodable>(
        host: String,
        port: Int,
        path: String,
        method: String,
        body: Data?
    ) async throws -> Response {
        guard (1...65535).contains(port),
              var components = URLComponents(string: "http://\(host)") else {
            throw ClientError.invalidEndpoint
        }
        components.port = port
        components.path = path
        guard let url = components.url else { throw ClientError.invalidEndpoint }
        guard let token = SharedDefaults.store.string(forKey: "esp32Token"),
              !token.isEmpty else { throw ClientError.missingControlToken }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.timeoutInterval = 3
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClientError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            if let acknowledgement = try? decoder.decode(ControlAcknowledgement.self, from: data) {
                throw ClientError.deviceRejection(httpResponse.statusCode, acknowledgement.message ?? acknowledgement.status.rawValue)
            }
            if let failure = try? decoder.decode(DeviceError.self, from: data) {
                throw ClientError.deviceRejection(httpResponse.statusCode, failure.error)
            }
            throw ClientError.httpFailure(httpResponse.statusCode)
        }
        return try decoder.decode(Response.self, from: data)
    }

    private struct DeviceError: Decodable {
        let error: String
    }

    enum ClientError: LocalizedError {
        case invalidEndpoint
        case missingControlToken
        case invalidResponse
        case invalidProtocolVersion(Int)
        case mismatchedAcknowledgement
        case deviceRejection(Int, String)
        case httpFailure(Int)
        case commandNotExecuted(AcknowledgementStatus, String?)

        var errorDescription: String? {
            switch self {
            case .invalidEndpoint: return "IP 地址或端口无效"
            case .missingControlToken: return "请填写设备串口显示的配对令牌"
            case .invalidResponse: return "设备响应无效"
            case .invalidProtocolVersion(let value): return "协议版本不兼容：\(value)"
            case .mismatchedAcknowledgement: return "确认序号与指令不一致"
            case .deviceRejection(let code, let message): return "设备拒绝（HTTP \(code)）：\(message)"
            case .httpFailure(let code): return "设备返回 HTTP \(code)"
            case .commandNotExecuted(let status, let message): return "指令未执行（\(status.rawValue)）：\(message ?? "无说明")"
            }
        }
    }
}

