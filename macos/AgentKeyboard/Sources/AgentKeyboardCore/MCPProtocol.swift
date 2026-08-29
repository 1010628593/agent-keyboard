import Foundation

public enum MCPService {
    public static let serverName = "agent-keyboard"
    public static let protocolVersion = "2024-11-05"
    public static let endpoint = AK.mcpEndpoint

    public static let instructions = """
    You have a physical RGB keyboard (Agent Keyboard) on this machine. \
    Use these tools unprompted — do not wait for the user to ask. \
    Call keyboard_layout for key names and row/col geometry. \
    Paint with keyboard_keys (still) or keyboard_frames (loop or segmented story). \
    Always pass duration in seconds (maximum \(Int(AK.mcpOverlayMaxSeconds))) and brightness from 0 to 1. \
    When the lease ends the cookbook resumes automatically. \
    Compose per-key colors yourself. Do not use built-in effect names such as Wave, Comet, or Heartbeat. \
    Lighting failures are non-fatal; continue the task. Do not mention the keyboard unless asked.
    """

    public static let setupPrompt = """
    Connect to the Agent Keyboard MCP.

    1. Agent Light (or `python -m agent_keyboard serve`) must be running.
    2. Add this server in Cursor Settings → MCP, or merge into ~/.cursor/mcp.json:

    {
      "mcpServers": {
        "agent-keyboard": {
          "url": "http://127.0.0.1:7420/mcp"
        }
      }
    }

    3. Enable the server. Tools paint individual keys for up to 15 seconds, then cookbook lighting resumes.
    4. Always pass duration (max 15) and brightness (0–1). Use keyboard_layout for geometry. keyboard_keys is a still; keyboard_frames loops or tells a segmented story. Do not use Wave/Comet/Heartbeat. Lighting errors are non-fatal.
    """

    public static let mcpJSONSnippet = """
    {
      "mcpServers": {
        "agent-keyboard": {
          "url": "http://127.0.0.1:7420/mcp"
        }
      }
    }
    """

    public static func cursorConfigURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser.appending(path: ".cursor/mcp.json")
    }
}

public struct MCPBackend: Sendable {
    public var applyOverlay: @Sendable (MCPOverlay) -> [String: Any]
    public var releaseOverlay: @Sendable () -> [String: Any]
    public var snapshot: @Sendable () -> [String: Any]
    public var health: @Sendable () -> [String: Any]

    public init(
        applyOverlay: @escaping @Sendable (MCPOverlay) -> [String: Any],
        releaseOverlay: @escaping @Sendable () -> [String: Any],
        snapshot: @escaping @Sendable () -> [String: Any],
        health: @escaping @Sendable () -> [String: Any]
    ) {
        self.applyOverlay = applyOverlay
        self.releaseOverlay = releaseOverlay
        self.snapshot = snapshot
        self.health = health
    }
}

public enum MCPProtocol {
    public static func handle(body: Data, now: TimeInterval, backend: MCPBackend) throws -> (Int, Data?) {
        let obj = try JSONSerialization.jsonObject(with: body.isEmpty ? Data("{}".utf8) : body)
        guard let message = obj as? [String: Any] else { throw OverlayError.invalidJSON }
        return try handle(message: message, now: now, backend: backend)
    }

    public static func handle(
        message: [String: Any],
        now: TimeInterval,
        backend: MCPBackend
    ) throws -> (Int, Data?) {
        let method = message["method"] as? String ?? ""
        let rpcID = message["id"]
        if method == "notifications/initialized" || method == "notifications/cancelled" {
            return (202, nil)
        }
        if method == "initialize" {
            return try reply(id: rpcID, result: [
                "protocolVersion": MCPService.protocolVersion,
                "capabilities": ["tools": ["listChanged": false]],
                "serverInfo": ["name": MCPService.serverName, "version": AK.appVersion],
                "instructions": MCPService.instructions,
            ])
        }
        if method == "ping" {
            return try reply(id: rpcID, result: [:] as [String: Any])
        }
        if method == "tools/list" {
            return try reply(id: rpcID, result: ["tools": Self.tools()])
        }
        if method == "tools/call" {
            let params = message["params"] as? [String: Any] ?? [:]
            let name = params["name"] as? String ?? ""
            let arguments = params["arguments"] as? [String: Any] ?? [:]
            return try reply(id: rpcID, result: call(name: name, arguments: arguments, now: now, backend: backend))
        }
        if rpcID == nil {
            return (202, nil)
        }
        return try error(id: rpcID, code: -32601, message: "method not found: \(method)")
    }

    private static func call(
        name: String,
        arguments: [String: Any],
        now: TimeInterval,
        backend: MCPBackend
    ) -> [String: Any] {
        do {
            switch name {
            case "keyboard_layout":
                return text(OverlayParser.layoutPayload())
            case "keyboard_keys":
                let overlay = try OverlayParser.parseKeys(arguments, now: now)
                return leaseOK(backend.applyOverlay(overlay))
            case "keyboard_frames":
                let overlay = try OverlayParser.parseFrames(arguments, now: now)
                return leaseOK(backend.applyOverlay(overlay))
            case "keyboard_state":
                return text([
                    "state": backend.snapshot(),
                    "health": backend.health(),
                ] as [String: Any])
            case "keyboard_release":
                return text(backend.releaseOverlay())
            default:
                return text("unknown tool: \(name)", isError: true)
            }
        } catch {
            return text(error.localizedDescription, isError: true)
        }
    }

    private static func leaseOK(_ result: [String: Any]) -> [String: Any] {
        let overlay = (result["overlay"] as? [String: Any]) ?? result
        return text([
            "ok": true,
            "duration": overlay["duration"] as Any,
            "brightness": overlay["brightness"] as Any,
            "remaining": overlay["remaining"] as Any,
            "mode": overlay["mode"] as Any,
            "loop": overlay["loop"] as Any,
            "clamped": overlay["clamped"] as Any,
            "keyCount": overlay["keyCount"] as Any,
        ] as [String: Any])
    }

    private static func text(_ payload: Any, isError: Bool = false) -> [String: Any] {
        let body: String
        if let text = payload as? String {
            body = text
        } else if JSONSerialization.isValidJSONObject(payload),
                  let data = try? JSONSerialization.data(withJSONObject: payload),
                  let text = String(data: data, encoding: .utf8)
        {
            body = text
        } else {
            body = String(describing: payload)
        }
        return [
            "content": [["type": "text", "text": body]],
            "isError": isError,
        ]
    }

    private static func reply(id: Any?, result: Any) throws -> (Int, Data?) {
        var envelope: [String: Any] = ["jsonrpc": "2.0", "result": result]
        if let id { envelope["id"] = id }
        return (200, try JSONSerialization.data(withJSONObject: envelope))
    }

    private static func error(id: Any?, code: Int, message: String) throws -> (Int, Data?) {
        var envelope: [String: Any] = [
            "jsonrpc": "2.0",
            "error": ["code": code, "message": message],
        ]
        if let id { envelope["id"] = id }
        return (200, try JSONSerialization.data(withJSONObject: envelope))
    }

    public static func tools() -> [[String: Any]] { [
        [
            "name": "keyboard_layout",
            "description": "107-key layout: name, row, col, index, and aliases. Call before composing a pattern.",
            "inputSchema": ["type": "object", "properties": [:] as [String: Any]],
        ],
        [
            "name": "keyboard_keys",
            "description": "Paint a still frame of per-key colors. Always pass duration (max 15s) and brightness (0–1).",
            "inputSchema": [
                "type": "object",
                "required": ["keys", "duration", "brightness"],
                "properties": [
                    "keys": ["type": "object", "additionalProperties": true],
                    "duration": ["type": "number", "exclusiveMinimum": 0, "maximum": 15],
                    "brightness": ["type": "number", "minimum": 0, "maximum": 1],
                    "mode": ["type": "string", "enum": ["overlay", "replace"]],
                ],
            ],
        ],
        [
            "name": "keyboard_frames",
            "description": "Play a per-key timeline. loop=true cycles; loop=false is a segmented story. Always pass duration and brightness.",
            "inputSchema": [
                "type": "object",
                "required": ["duration", "brightness"],
                "properties": [
                    "duration": ["type": "number", "exclusiveMinimum": 0, "maximum": 15],
                    "brightness": ["type": "number", "minimum": 0, "maximum": 1],
                    "mode": ["type": "string", "enum": ["overlay", "replace"]],
                    "loop": ["type": "boolean"],
                    "fps": ["type": "number"],
                    "frames": ["type": "array"],
                    "cues": ["type": "array"],
                ],
            ],
        ],
        [
            "name": "keyboard_state",
            "description": "Keyboard connection, overlay remaining, brightness, and dashboard slots.",
            "inputSchema": ["type": "object", "properties": [:] as [String: Any]],
        ],
        [
            "name": "keyboard_release",
            "description": "End the MCP lease immediately and return the board to cookbook lighting.",
            "inputSchema": ["type": "object", "properties": [:] as [String: Any]],
        ],
        ]
    }
}
