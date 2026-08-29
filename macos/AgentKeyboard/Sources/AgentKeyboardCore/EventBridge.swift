import Foundation
import Network

public struct BridgeEvent: Equatable, Sendable {
    public var agent: String
    public var status: String?
    public var context: Double?
    public var progress: Double?
    public var message: String?

    public func asAgentEvent() throws -> AgentEvent {
        let parsed: AgentStatus?
        if let status {
            guard let value = AgentStatus.parse(status) else {
                throw BridgeError.unknownStatus(status)
            }
            parsed = value
        } else {
            parsed = nil
        }
        return AgentEvent(
            agent: agent,
            status: parsed,
            context: context,
            progress: progress,
            message: message
        )
    }
}

public enum BridgeError: Error, Equatable {
    case unknownStatus(String)
    case invalidJSON
}

public final class EventBridge: @unchecked Sendable {
    public var onEvent: (@Sendable (AgentEvent) -> Void)?
    public var snapshot: (@Sendable () -> [String: Any])?
    public var health: (@Sendable () -> [String: Any])?
    public var applyOverlay: (@Sendable (MCPOverlay) -> [String: Any])?
    public var releaseOverlay: (@Sendable () -> [String: Any])?
    public var now: (@Sendable () -> TimeInterval)?

    private var listener: NWListener?
    private let queue = DispatchQueue(label: "agent-keyboard.http")

    public init() {}

    public func start(port: UInt16 = AK.defaultBridgePort) throws {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        params.requiredLocalEndpoint = NWEndpoint.hostPort(
            host: "127.0.0.1",
            port: NWEndpoint.Port(rawValue: port)!
        )
        let listener = try NWListener(using: params)
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }
        listener.start(queue: queue)
        self.listener = listener
    }

    public func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(on: connection, buffer: Data())
    }

    private func receive(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let error {
                connection.cancel()
                _ = error
                return
            }
            var next = buffer
            if let data { next.append(data) }
            if let headerRange = next.range(of: Data("\r\n\r\n".utf8)) {
                let header = next.subdata(in: next.startIndex..<headerRange.lowerBound)
                let rest = next.subdata(in: headerRange.upperBound..<next.endIndex)
                let headerText = String(data: header, encoding: .utf8) ?? ""
                let length = Self.contentLength(in: headerText)
                if rest.count >= length {
                    let body = rest.prefix(length)
                    self.respond(connection: connection, header: headerText, body: Data(body))
                    return
                }
            }
            if isComplete {
                connection.cancel()
                return
            }
            self.receive(on: connection, buffer: next)
        }
    }

    private func respond(connection: NWConnection, header: String, body: Data) {
        let requestLine = header.split(separator: "\r\n").first.map(String.init) ?? ""
        let parts = requestLine.split(separator: " ")
        let method = parts.first.map(String.init) ?? ""
        let path = parts.dropFirst().first.map(String.init) ?? "/"
        let payload: Data
        let code: Int
        do {
            let (status, json) = try route(method: method, path: path, body: body)
            payload = json
            code = status
        } catch let error as BridgeError {
            let message: String
            switch error {
            case .unknownStatus(let status): message = "unknown status: \(status)"
            case .invalidJSON: message = "invalid json"
            }
            payload = Data("{\"error\":\"\(message)\"}".utf8)
            code = 400
        } catch let error as OverlayError {
            var body: [String: Any] = ["error": error.localizedDescription]
            if case .unknownKeys(let names) = error {
                body["unknown"] = names
                body["keys"] = KeyName.uniqueNames
            }
            payload = (try? JSONSerialization.data(withJSONObject: body)) ?? Data(#"{"error":"overlay"}"#.utf8)
            code = 400
        } catch {
            payload = Data(#"{"error":"bad request"}"#.utf8)
            code = 400
        }
        let phrase: String
        switch code {
        case 200: phrase = "OK"
        case 202: phrase = "Accepted"
        case 204: phrase = "No Content"
        default: phrase = "Error"
        }
        let response = Data(
            "HTTP/1.1 \(code) \(phrase)\r\nContent-Type: application/json\r\nContent-Length: \(payload.count)\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n"
                .utf8
        ) + payload
        connection.send(content: response, isComplete: true, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func route(method: String, path: String, body: Data) throws -> (Int, Data) {
        if method == "OPTIONS" {
            return (204, Data())
        }
        if method == "GET", path == "/health" || path == "/health/" {
            let payload = health?() ?? ["ok": true]
            return (200, try JSONSerialization.data(withJSONObject: payload))
        }
        if method == "GET", path == "/state" || path == "/state/" {
            let snap = snapshot?() ?? [:]
            let data = try JSONSerialization.data(withJSONObject: snap)
            return (200, data)
        }
        if method == "GET", path == "/lighting/layout" || path == "/lighting/layout/" {
            return (200, try JSONSerialization.data(withJSONObject: OverlayParser.layoutPayload()))
        }
        if method == "POST", path == "/mcp" || path == "/mcp/" {
            let clock = now?() ?? ProcessInfo.processInfo.systemUptime
            let backend = MCPBackend(
                applyOverlay: { [applyOverlay] overlay in applyOverlay?(overlay) ?? overlay.snapshot(now: overlay.startedAt) },
                releaseOverlay: { [releaseOverlay] in releaseOverlay?() ?? MCPOverlay.inactiveSnapshot() },
                snapshot: { [snapshot] in snapshot?() ?? [:] },
                health: { [health] in health?() ?? ["ok": true] }
            )
            let (code, data) = try MCPProtocol.handle(body: body, now: clock, backend: backend)
            return (code, data ?? Data())
        }
        if method == "POST", path == "/lighting/keys" || path == "/lighting/keys/" {
            return try lightingKeys(body)
        }
        if method == "POST", path == "/lighting/frames" || path == "/lighting/frames/" {
            return try lightingFrames(body)
        }
        if method == "POST", path == "/lighting/release" || path == "/lighting/release/" {
            let payload = releaseOverlay?() ?? MCPOverlay.inactiveSnapshot()
            return (200, try JSONSerialization.data(withJSONObject: payload))
        }
        if method == "POST", path == "/event" || path == "/event/" {
            let event = try decodeEvent(body)
            onEvent?(event)
            return (200, Data(#"{"ok":true}"#.utf8))
        }
        if method == "POST", path.hasPrefix("/demo/") {
            let name = String(path.split(separator: "/").last ?? "")
            guard let status = AgentStatus.parse(name) else {
                return (404, try jsonError("unknown demo \(name)"))
            }
            onEvent?(AgentEvent(agent: "codex", status: status))
            return (200, try JSONSerialization.data(withJSONObject: snapshot?() ?? [:]))
        }
        if method == "POST", path.hasPrefix("/agents/") {
            var event = try decodeEvent(body)
            let agent = String(path.split(separator: "/").last ?? "")
            event = AgentEvent(
                agent: agent,
                status: event.status,
                context: event.context,
                progress: event.progress,
                message: event.message
            )
            onEvent?(event)
            let snap = snapshot?() ?? [:]
            return (200, try JSONSerialization.data(withJSONObject: snap))
        }
        return (404, try jsonError("not found"))
    }

    private func lightingKeys(_ body: Data) throws -> (Int, Data) {
        let object = try OverlayParser.parseJSON(body)
        let clock = now?() ?? ProcessInfo.processInfo.systemUptime
        let overlay = try OverlayParser.parseKeys(object, now: clock)
        let payload = applyOverlay?(overlay) ?? overlay.snapshot(now: overlay.startedAt)
        return (200, try JSONSerialization.data(withJSONObject: payload))
    }

    private func lightingFrames(_ body: Data) throws -> (Int, Data) {
        let object = try OverlayParser.parseJSON(body)
        let clock = now?() ?? ProcessInfo.processInfo.systemUptime
        let overlay = try OverlayParser.parseFrames(object, now: clock)
        let payload = applyOverlay?(overlay) ?? overlay.snapshot(now: overlay.startedAt)
        return (200, try JSONSerialization.data(withJSONObject: payload))
    }

    private func jsonError(_ message: String) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["error": message])
    }

    public static func parseEvent(_ body: Data) throws -> AgentEvent {
        try EventBridge().decodeEvent(body)
    }

    private func decodeEvent(_ body: Data) throws -> AgentEvent {
        let obj = try JSONSerialization.jsonObject(with: body.isEmpty ? Data("{}".utf8) : body)
        guard let dict = obj as? [String: Any] else { throw BridgeError.invalidJSON }
        let agent = (dict["agent"] as? String) ?? (dict["id"] as? String) ?? ""
        guard !agent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BridgeError.invalidJSON
        }
        let bridge = BridgeEvent(
            agent: agent,
            status: dict["status"] as? String,
            context: (dict["context"] as? NSNumber)?.doubleValue,
            progress: (dict["progress"] as? NSNumber)?.doubleValue,
            message: dict["message"] as? String
        )
        return try bridge.asAgentEvent()
    }

    private static func contentLength(in header: String) -> Int {
        for line in header.split(separator: "\r\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2, parts[0].lowercased() == "content-length" {
                return Int(parts[1].trimmingCharacters(in: .whitespaces)) ?? 0
            }
        }
        return 0
    }
}
