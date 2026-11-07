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
    private var nextCommandID: UInt64 = 1

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
            state = .connected(health.device)
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
        nextCommandID &+= 1
        let body = try encoder.encode(command)
        let acknowledgement: ControlAcknowledgement = try await request(
            host: host,
            port: port,
            path: "/v1/command",
            method: "POST",
            body: body
        )
        guard acknowledgement.id == command.id else { throw ClientError.mismatchedAcknowledgement }
        lastAcknowledgement = acknowledgement
        return acknowledgement
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
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.timeoutInterval = 3
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ClientError.invalidResponse
        }
        return try decoder.decode(Response.self, from: data)
    }

    enum ClientError: LocalizedError {
        case invalidEndpoint
        case invalidResponse
        case invalidProtocolVersion(Int)
        case mismatchedAcknowledgement

        var errorDescription: String? {
            switch self {
            case .invalidEndpoint: return "IP 地址或端口无效"
            case .invalidResponse: return "设备响应无效"
            case .invalidProtocolVersion(let value): return "协议版本不兼容：\(value)"
            case .mismatchedAcknowledgement: return "确认序号与指令不一致"
            }
        }
    }
}
