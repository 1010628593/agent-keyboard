import Foundation

public struct AgentKeyboardConfig: Equatable, Sendable {
    public var host: String = "127.0.0.1"
    public var port: UInt16 = AK.defaultBridgePort
    public var fps: Int = AK.defaultFPS
    public var style: RenderStyle = .dashboard
    public var idleWhite: Double = AK.defaultIdleWhite
    public var idleTimeout: TimeInterval = AK.defaultIdleTimeout
    public var agents: [AgentSpec] = AgentSpec.defaults

    public init() {}

    public static let applicationSupportDirectory: URL = {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "AgentKeyboard", directoryHint: .isDirectory)
    }()

    public static func load() -> AgentKeyboardConfig {
        let urls = [
            applicationSupportDirectory.appending(path: "agents.toml"),
            URL(fileURLWithPath: NSHomeDirectory()).appending(path: ".config/agent-keyboard/agents.toml"),
        ]
        for url in urls where FileManager.default.isReadableFile(atPath: url.path) {
            if let parsed = try? parse(String(contentsOf: url, encoding: .utf8)) {
                return parsed
            }
        }
        return AgentKeyboardConfig()
    }

    public static func parse(_ text: String) throws -> AgentKeyboardConfig {
        var config = AgentKeyboardConfig()
        var currentTable = ""
        var currentAgent: [String: String] = [:]
        var agents: [AgentSpec] = []

        func flushAgent() {
            guard !currentAgent.isEmpty else { return }
            let slot = (currentAgent["slot"] ?? "").lowercased()
            let id = currentAgent["id"] ?? slot
            let name = currentAgent["name"] ?? id
            let key = currentAgent["key"] ?? slot.uppercased()
            if !slot.isEmpty, !id.isEmpty {
                agents.append(AgentSpec(slot: slot, agentID: id, name: name, keyName: key))
            }
            currentAgent = [:]
        }

        for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            if line == "[[agents]]" {
                flushAgent()
                currentTable = "agent"
                continue
            }
            if line.hasPrefix("[") && line.hasSuffix("]") {
                flushAgent()
                currentTable = String(line.dropFirst().dropLast())
                continue
            }
            let parts = line.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            var value = parts[1].trimmingCharacters(in: .whitespaces)
            if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 {
                value = String(value.dropFirst().dropLast())
            }
            if currentTable == "agent" {
                currentAgent[key] = value
            } else if currentTable == "bridge" {
                if key == "host" { config.host = value }
                if key == "port", let port = UInt16(value) { config.port = port }
            } else if currentTable == "render" {
                if key == "fps", let fps = Int(value) { config.fps = fps }
                if key == "style", let style = RenderStyle(rawValue: value) { config.style = style }
                if key == "idle_white", let white = Double(value) { config.idleWhite = white }
                if key == "idle_timeout", let timeout = Double(value) { config.idleTimeout = timeout }
            }
        }
        flushAgent()
        if !agents.isEmpty {
            config.agents = agents
        }
        return config
    }
}

public struct LogEntry: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let at: Date
    public let source: String
    public let message: String
    public let agent: String?

    public init(source: String, message: String, agent: String? = nil, at: Date = Date()) {
        self.id = UUID()
        self.at = at
        self.source = source
        self.message = message
        self.agent = agent
    }
}

public enum HookEventMapper {
    public static func status(fromLifecycle event: String) -> AgentStatus? {
        switch normalizedEvent(event) {
        case "sessionstart", "session_start", "on_session_start",
             "userpromptsubmit", "user_prompt_submit", "beforesubmitprompt",
             "pre_llm_call", "running", "thinking", "afteragentthought":
            return .running
        case "pretooluse", "pre_tool_use", "pre_tool_call", "post_tool_call",
             "beforeshellexecution", "beforemcpexecution", "tool", "tool_calling":
            return .tool
        case "permissionrequest", "pre_approval_request", "notification", "approval":
            return .approval
        case "stop", "stop_completed", "post_llm_call", "on_session_end",
             "afteragentresponse", "session_idle", "done", "completed":
            return .done
        case "posttoolusefailure", "stopfailure", "stop_error", "error", "failed":
            return .error
        case "idle":
            return .idle
        default:
            return AgentStatus.parse(event)
        }
    }

    /// Cursor dual-loads ~/.claude/settings.json. Those hooks must not post as Claude
    /// (or be remapped onto Cursor — Cursor's own hooks.json is the source of truth).
    public static func shouldReport(declaredAgent: String, payload: String) -> Bool {
        if isCursorPayload(payload), declaredAgent != "cursor" {
            return false
        }
        return true
    }

    public static func isCursorPayload(_ payload: String) -> Bool {
        payload.contains("\"cursor_version\"") || payload.contains("cursor_version")
    }

    public static func status(
        fromLifecycle event: String,
        agent: String,
        payload: String = ""
    ) -> AgentStatus? {
        let key = normalizedEvent(event)
        if agent == "cursor" {
            switch key {
            case "sessionstart", "session_start":
                return nil
            case "afteragentresponse":
                return .running
            case "pretooluse", "pre_tool_use":
                return cursorToolStatus(payload: payload)
            case "stop":
                return cursorStopStatus(payload: payload)
            default:
                break
            }
        }
        return status(fromLifecycle: event)
    }

    public static func cursorToolStatus(payload: String) -> AgentStatus {
        let tool = jsonString(payload, key: "tool_name")
            ?? jsonString(payload, key: "toolName")
            ?? ""
        switch tool {
        case "Read", "Grep", "Glob", "Ripgrep", "ReadFile", "SemanticSearch":
            return .running
        default:
            return .tool
        }
    }

    public static func cursorStopStatus(payload: String) -> AgentStatus {
        let value = jsonString(payload, key: "status")?.lowercased() ?? ""
        switch value {
        case "error", "aborted", "failed":
            return .error
        default:
            return .done
        }
    }

    private static func normalizedEvent(_ event: String) -> String {
        event.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
    }

    private static func jsonString(_ payload: String, key: String) -> String? {
        let needle = "\"\(key)\""
        guard let keyRange = payload.range(of: needle) else { return nil }
        let rest = payload[keyRange.upperBound...]
        guard let colon = rest.firstIndex(of: ":") else { return nil }
        let afterColon = rest[rest.index(after: colon)...]
        guard let startQuote = afterColon.firstIndex(of: "\"") else { return nil }
        let valueStart = afterColon.index(after: startQuote)
        guard let endQuote = afterColon[valueStart...].firstIndex(of: "\"") else { return nil }
        let value = String(afterColon[valueStart..<endQuote])
        return value.isEmpty ? nil : value
    }
}

public struct IntegrationSpec: Identifiable, Equatable, Sendable {
    public var id: String { agentID }
    public var agentID: String
    public var name: String
    public var configPath: String
    public var kind: Kind
    public var available: Bool
    public var installed: Bool
    public var detail: String

    public enum Kind: String, Sendable {
        case jsonHooks
        case hermesYAML
        case piTemplate
        case workbuddy
        case cursorMCP
    }
}

public enum HookInstaller {
    public static func supportDirectory() throws -> URL {
        let url = AgentKeyboardConfig.applicationSupportDirectory
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    public static func notifyScriptURL() -> URL {
        AgentKeyboardConfig.applicationSupportDirectory.appending(path: "notify.sh")
    }

    /// Codex execs hook commands without a reliable shell. Path must have no spaces
    /// and no extra argv — event names come from stdin JSON.
    public static func codexHookURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".codex/hooks/agent-keyboard.sh")
    }

    /// Quoted so paths with spaces (Application Support) survive hook shells.
    public static func notifyInvocation(agent: String, event: String) -> String {
        "'\(notifyScriptURL().path)' \(agent) \(event)"
    }

    public static func specs() -> [IntegrationSpec] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let notify = notifyScriptURL().path
        return [
            inspectJSON(
                agentID: "codex",
                name: "Codex",
                url: home.appending(path: ".codex/hooks.json"),
                notify: notify
            ),
            inspectJSON(
                agentID: "claude",
                name: "Claude Code",
                url: home.appending(path: ".claude/settings.json"),
                notify: notify,
                hooksKey: "hooks"
            ),
            inspectJSON(
                agentID: "cursor",
                name: "Cursor",
                url: home.appending(path: ".cursor/hooks.json"),
                notify: notify
            ),
            inspectHermes(home: home, notify: notify),
            inspectPi(home: home),
            inspectWorkbuddy(home: home, notify: notify),
            inspectCursorMCP(),
        ]
    }

    public static func installAll() throws -> [IntegrationSpec] {
        try installSupportScripts()
        _ = try installCodex()
        _ = try installClaude()
        _ = try installCursor()
        _ = try installHermes()
        try installPiTemplate()
        _ = try installWorkbuddyIfPresent()
        _ = try installCursorMCP()
        return specs()
    }

    public static func install(agentID: String) throws {
        try installSupportScripts()
        switch agentID {
        case "codex": _ = try installCodex()
        case "claude": _ = try installClaude()
        case "cursor": _ = try installCursor()
        case "hermes": _ = try installHermes()
        case "pi": try installPiTemplate()
        case "workbuddy": _ = try installWorkbuddyIfPresent()
        case "mcp": _ = try installCursorMCP()
        default: break
        }
    }

    public static func installSupportScripts() throws {
        let dir = try supportDirectory()
        let notify = dir.appending(path: "notify.sh")
        let status = dir.appending(path: "agent-status.sh")
        let peek = dir.appending(path: "stdin-peek.py")
        try agentStatusScript.write(to: status, atomically: true, encoding: .utf8)
        try stdinPeekScript.write(to: peek, atomically: true, encoding: .utf8)
        try notifyScript.write(to: notify, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: notify.path)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: status.path)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: peek.path)
    }

    private static func inspectJSON(
        agentID: String,
        name: String,
        url: URL,
        notify: String,
        hooksKey: String? = nil
    ) -> IntegrationSpec {
        let exists = FileManager.default.isReadableFile(atPath: url.path)
        var installed = false
        if exists, let text = try? String(contentsOf: url, encoding: .utf8) {
            installed = isAgentKeyboardCommand(text) || text.contains(notify)
        }
        let detail: String
        if !exists {
            detail = "Config not found"
        } else if !installed {
            detail = "Config found, hook not installed"
        } else if agentID == "codex" {
            detail = "Hook installed. Trust ~/.codex/hooks/agent-keyboard.sh in Codex /hooks if F1 stays idle."
        } else {
            detail = "Hook installed"
        }
        return IntegrationSpec(
            agentID: agentID,
            name: name,
            configPath: url.path,
            kind: .jsonHooks,
            available: exists,
            installed: installed,
            detail: detail
        )
    }

    private static func inspectHermes(home: URL, notify: String) -> IntegrationSpec {
        let url = home.appending(path: ".hermes/config.yaml")
        let exists = FileManager.default.isReadableFile(atPath: url.path)
        var installed = false
        if exists, let text = try? String(contentsOf: url, encoding: .utf8) {
            installed = text.contains("AgentKeyboard") || text.contains(notify)
        }
        return IntegrationSpec(
            agentID: "hermes",
            name: "Hermes",
            configPath: url.path,
            kind: .hermesYAML,
            available: exists,
            installed: installed,
            detail: exists ? (installed ? "Hook installed" : "Will wrap existing mnemon hooks") : "config.yaml not found"
        )
    }

    private static func inspectPi(home: URL) -> IntegrationSpec {
        let url = home.appending(path: ".pi/agent/settings.json")
        let template = AgentKeyboardConfig.applicationSupportDirectory.appending(path: "pi-hooks.yaml")
        let installed = FileManager.default.isReadableFile(atPath: template.path)
        return IntegrationSpec(
            agentID: "pi",
            name: "Pi",
            configPath: url.path,
            kind: .piTemplate,
            available: FileManager.default.isReadableFile(atPath: url.path),
            installed: installed,
            detail: installed ? "Template written to Application Support" : "Install writes pi-hooks.yaml template"
        )
    }

    /// WorkBuddy reads `~/.workbuddy/settings.json`; older CodeBuddy builds used `~/.codebuddy/settings.json`.
    public static func workbuddySettingsURL() -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let preferred = home.appending(path: ".workbuddy/settings.json")
        let legacy = home.appending(path: ".codebuddy/settings.json")
        let fm = FileManager.default
        if fm.isReadableFile(atPath: preferred.path) {
            return preferred
        }
        if fm.isReadableFile(atPath: legacy.path) {
            return legacy
        }
        // Prefer creating in ~/.workbuddy when that directory exists; otherwise legacy path.
        var isDir: ObjCBool = false
        if fm.fileExists(atPath: home.appending(path: ".workbuddy").path, isDirectory: &isDir), isDir.boolValue {
            return preferred
        }
        return legacy
    }

    private static func inspectWorkbuddy(home: URL, notify: String) -> IntegrationSpec {
        let url = workbuddySettingsURL()
        let exists = FileManager.default.isReadableFile(atPath: url.path)
        var installed = false
        if exists, let text = try? String(contentsOf: url, encoding: .utf8) {
            installed = text.contains("AgentKeyboard") || text.contains(notify)
        }
        return IntegrationSpec(
            agentID: "workbuddy",
            name: "Workbuddy",
            configPath: url.path,
            kind: .workbuddy,
            available: exists,
            installed: installed,
            detail: exists ? (installed ? "Hook installed" : "Config found") : "Workbuddy settings.json not found"
        )
    }

    private static func installCodex() throws -> Bool {
        try writeCodexHookScript()
        return try mergeNestedJSONHooks(
            url: FileManager.default.homeDirectoryForCurrentUser.appending(path: ".codex/hooks.json"),
            events: [
                "SessionStart": "running",
                "UserPromptSubmit": "running",
                "PreToolUse": "tool",
                "PermissionRequest": "approval",
                "Stop": "done",
                "PostToolUseFailure": "error",
            ],
            agent: "codex",
            createIfMissing: true,
            command: codexHookURL().path
        )
    }

    private static func installClaude() throws -> Bool {
        try mergeNestedJSONHooks(
            url: FileManager.default.homeDirectoryForCurrentUser.appending(path: ".claude/settings.json"),
            events: [
                "SessionStart": "running",
                "UserPromptSubmit": "running",
                "PreToolUse": "tool",
                "PermissionRequest": "approval",
                "Stop": "done",
            ],
            agent: "claude",
            createIfMissing: false
        )
    }

    private static func installCursor() throws -> Bool {
        try mergeJSONHooks(
            url: FileManager.default.homeDirectoryForCurrentUser.appending(path: ".cursor/hooks.json"),
            events: [
                "beforeSubmitPrompt": "running",
                "afterAgentThought": "running",
                "preToolUse": "tool",
                "afterAgentResponse": "running",
                "stop": "done",
                "postToolUseFailure": "error",
            ],
            agent: "cursor",
            createIfMissing: true
        )
    }

    private static func installHermes() throws -> Bool {
        let url = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".hermes/config.yaml")
        guard FileManager.default.isReadableFile(atPath: url.path) else { return false }
        var text = try String(contentsOf: url, encoding: .utf8)
        let mapping: [(String, String)] = [
            ("on_session_start", "SessionStart"),
            ("pre_llm_call", "pre_llm_call"),
            ("pre_tool_call", "PreToolUse"),
            ("pre_approval_request", "PermissionRequest"),
            ("post_llm_call", "Stop"),
        ]
        for (key, event) in mapping {
            let wrapper = try writeHermesWrapper(yamlKey: key, event: event)
            text = mergeHermesHook(in: text, key: key, wrapper: wrapper.path)
        }
        try text.write(to: url, atomically: true, encoding: .utf8)
        return true
    }

    static func mergeHermesHook(in text: String, key: String, wrapper: String) -> String {
        if text.contains(wrapper) || hermesKeyAlreadyNotifies(text, key: key) {
            return text
        }
        let lines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).map(String.init)
        guard let index = lines.firstIndex(where: { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed == "\(key):" || trimmed.hasPrefix("\(key):")
        }) else {
            return text
        }
        let line = lines[index]
        let indent = String(line.prefix { $0 == " " || $0 == "\t" })
        let item = indent + "  "
        let notifyLines = [
            "\(item)- command: \"\(wrapper)\"",
            "\(item)  timeout: 1",
        ]
        var out = lines
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed == "\(key):" {
            out.insert(contentsOf: notifyLines, at: index + 1)
            return out.joined(separator: "\n")
        }
        let original = String(trimmed.dropFirst(key.count + 1)).trimmingCharacters(in: .whitespaces)
        if original.contains("AgentKeyboard") || original.contains("notify.sh") {
            return text
        }
        out[index] = "\(indent)\(key):"
        out.insert(contentsOf: notifyLines + [
            "\(item)- command: \(original)",
            "\(item)  timeout: 10",
        ], at: index + 1)
        return out.joined(separator: "\n")
    }

    private static func hermesKeyAlreadyNotifies(_ text: String, key: String) -> Bool {
        let lines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).map(String.init)
        guard let start = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("\(key):") }) else {
            return false
        }
        let startIndent = lines[start].prefix { $0 == " " || $0 == "\t" }.count
        for line in lines.dropFirst(start + 1) {
            let indent = line.prefix { $0 == " " || $0 == "\t" }.count
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if indent <= startIndent, !trimmed.isEmpty {
                break
            }
            if trimmed.contains("notify.sh") || trimmed.contains("AgentKeyboard") {
                return true
            }
        }
        return false
    }

    private static func writeHermesWrapper(yamlKey: String, event: String) throws -> URL {
        let dir = try supportDirectory()
        let url = dir.appending(path: "hermes-\(yamlKey).sh")
        let notify = notifyScriptURL().path
        try """
        #!/bin/sh
        "\(notify)" hermes \(event) || true
        exit 0
        """.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url
    }

    private static func installPiTemplate() throws {
        let dir = try supportDirectory()
        let url = dir.appending(path: "pi-hooks.yaml")
        try piTemplate.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func installWorkbuddyIfPresent() throws -> Bool {
        let url = workbuddySettingsURL()
        let fm = FileManager.default
        let exists = fm.isReadableFile(atPath: url.path)
        // Only create the file when its parent directory already exists (the app is installed).
        let parentExists = fm.fileExists(atPath: url.deletingLastPathComponent().path)
        guard exists || parentExists else { return false }
        return try mergeNestedJSONHooks(
            url: url,
            events: [
                "SessionStart": "running",
                "UserPromptSubmit": "running",
                "PreToolUse": "tool",
                "Stop": "done",
            ],
            agent: "workbuddy",
            createIfMissing: !exists
        )
    }

    public static func inspectCursorMCP() -> IntegrationSpec {
        let url = MCPService.cursorConfigURL()
        let exists = FileManager.default.isReadableFile(atPath: url.path)
        var installed = false
        if exists, let text = try? String(contentsOf: url, encoding: .utf8) {
            installed = cursorMCPInstalled(in: text)
        }
        let detail: String
        if installed {
            detail = "MCP server agent-keyboard → \(AK.mcpEndpoint)"
        } else if exists {
            detail = "mcp.json found, agent-keyboard not configured"
        } else {
            detail = "Will create ~/.cursor/mcp.json"
        }
        return IntegrationSpec(
            agentID: "mcp",
            name: "Cursor MCP",
            configPath: url.path,
            kind: .cursorMCP,
            available: true,
            installed: installed,
            detail: detail
        )
    }

    public static func installCursorMCP() throws -> Bool {
        try mergeCursorMCP(url: MCPService.cursorConfigURL())
    }

    static func mergeCursorMCP(url: URL) throws -> Bool {
        let fm = FileManager.default
        if !fm.isReadableFile(atPath: url.path) {
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try "{}".write(to: url, atomically: true, encoding: .utf8)
        }
        let data = try Data(contentsOf: url)
        var root = (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        var servers = root["mcpServers"] as? [String: Any] ?? [:]
        servers[MCPService.serverName] = [
            "url": AK.mcpEndpoint,
        ]
        root["mcpServers"] = servers
        let out = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        try out.write(to: url, options: .atomic)
        return true
    }

    static func cursorMCPInstalled(in text: String) -> Bool {
        text.contains(AK.mcpEndpoint) || (
            text.contains("agent-keyboard") && text.contains("/mcp")
        )
    }

    static func mergeJSONHooks(
        url: URL,
        events: [String: String],
        agent: String,
        createIfMissing: Bool
    ) throws -> Bool {
        let fm = FileManager.default
        if !fm.isReadableFile(atPath: url.path) {
            guard createIfMissing else { return false }
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try "{}".write(to: url, atomically: true, encoding: .utf8)
        }
        let data = try Data(contentsOf: url)
        var root = (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        var hooks = root["hooks"] as? [String: Any] ?? [:]
        if hooks.isEmpty, root["hooks"] == nil {
            for (key, value) in root where key != "version" {
                hooks[key] = value
                root.removeValue(forKey: key)
            }
        }
        stripNotifyFromObsoleteEvents(in: &hooks, keeping: Set(events.keys))
        for (event, _) in events {
            var list = hooks[event] as? [[String: Any]] ?? []
            ensureNotifyHook(in: &list, agent: agent, event: event, nested: false)
            hooks[event] = list
        }
        root["hooks"] = hooks
        if root["version"] == nil {
            root["version"] = 1
        }
        let out = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        try out.write(to: url, options: .atomic)
        return true
    }

    static func mergeNestedJSONHooks(
        url: URL,
        events: [String: String],
        agent: String,
        createIfMissing: Bool,
        command: String? = nil
    ) throws -> Bool {
        let fm = FileManager.default
        if !fm.isReadableFile(atPath: url.path) {
            guard createIfMissing else { return false }
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try #"{"hooks":{}}"#.write(to: url, atomically: true, encoding: .utf8)
        }
        let data = try Data(contentsOf: url)
        var root = (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        var hooks = root["hooks"] as? [String: Any] ?? [:]
        stripNotifyFromObsoleteEvents(in: &hooks, keeping: Set(events.keys))
        for (event, _) in events {
            var list = hooks[event] as? [[String: Any]] ?? []
            ensureNotifyHook(in: &list, agent: agent, event: event, nested: true, command: command)
            hooks[event] = list
        }
        root["hooks"] = hooks
        let out = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        try out.write(to: url, options: .atomic)
        return true
    }

    private static func stripNotifyFromObsoleteEvents(in hooks: inout [String: Any], keeping wanted: Set<String>) {
        for key in Array(hooks.keys) where !wanted.contains(key) {
            var list = hooks[key] as? [[String: Any]] ?? []
            list.removeAll { hookEntryNotifies($0) }
            if list.isEmpty {
                hooks.removeValue(forKey: key)
            } else {
                hooks[key] = list
            }
        }
    }

    private static let hookTimeoutSeconds = 2

    private static func ensureNotifyHook(
        in list: inout [[String: Any]],
        agent: String,
        event: String,
        nested: Bool,
        command: String? = nil
    ) {
        list.removeAll { hookEntryNotifies($0) }
        let command = command ?? notifyInvocation(agent: agent, event: event)
        if nested {
            list.insert(
                [
                    "hooks": [[
                        "type": "command",
                        "command": command,
                        "timeout": hookTimeoutSeconds,
                    ]]
                ],
                at: 0
            )
        } else {
            list.insert(
                [
                    "command": command,
                    "timeout": hookTimeoutSeconds,
                ],
                at: 0
            )
        }
    }

    private static func hookEntryNotifies(_ entry: [String: Any]) -> Bool {
        let commands: [String] = {
            if let command = entry["command"] as? String {
                return [command]
            }
            let nested = entry["hooks"] as? [[String: Any]] ?? []
            return nested.compactMap { $0["command"] as? String }
        }()
        return commands.contains { isAgentKeyboardCommand($0) }
    }

    static func isAgentKeyboardCommand(_ command: String) -> Bool {
        command.contains("notify.sh")
            || command.contains("AgentKeyboard")
            || command.contains("agent-keyboard")
    }

    private static func writeCodexHookScript() throws {
        let url = codexHookURL()
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try codexHookScript.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }

    private static let stdinPeekScript = """
    import os
    import select
    import sys
    import time

    if sys.stdin.isatty():
        raise SystemExit
    ready, _, _ = select.select([sys.stdin], [], [], 0.2)
    if not ready:
        raise SystemExit
    fd = sys.stdin.fileno()
    os.set_blocking(fd, False)
    buf = b""
    deadline = time.time() + 0.2
    while time.time() < deadline:
        try:
            chunk = os.read(fd, 65536)
        except BlockingIOError:
            time.sleep(0.02)
            continue
        if not chunk:
            break
        buf += chunk
    sys.stdout.buffer.write(buf)
    """

    private static let agentStatusScript = """
    #!/bin/sh
    AGENT=${1:?agent id or slot}
    STATUS=${2:?status}
    CONTEXT=${3:-0}
    HOST=${AGENT_KEYBOARD_URL:-http://127.0.0.1:7420/event}
    /usr/bin/curl -sS --noproxy '*' -m 0.4 -X POST "$HOST" \\
      -H 'content-type: application/json' \\
      -d "{\\"agent\\":\\"${AGENT}\\",\\"status\\":\\"${STATUS}\\",\\"context\\":${CONTEXT}}" \\
      >/dev/null 2>/dev/null || true
    """

    private static let notifyScript = """
    #!/bin/sh
    # Map agent lifecycle events to Agent Keyboard status.
    # Usage: notify.sh <agent> [event-name]
    AGENT=${1:?agent}
    EVENT=${2:-}
    INPUT=""
    ROOT="$(cd "$(dirname "$0")" && pwd)"
    extract_json_field() {
      local key="$1"
      printf '%s' "$INPUT" | tr '\\n' ' ' | sed -n "s/.*\\\"${key}\\\"[[:space:]]*:[[:space:]]*\\\"\\([^\\\"]*\\)\\\".*/\\1/p"
    }
    if [ ! -t 0 ]; then
      INPUT=$(/usr/bin/python3 "$ROOT/stdin-peek.py" 2>/dev/null || true)
    fi
    # Cursor dual-loads ~/.claude/settings.json. Never post those as Claude,
    # and never remap them onto Cursor — ~/.cursor/hooks.json owns F4.
    if [ "$AGENT" != "cursor" ]; then
      if printf '%s' "$INPUT" | grep -q '"cursor_version"'; then
        printf '%s\\n' '{}'
        exit 0
      fi
    fi
    if [ "$AGENT" = "claude" ] && [ -z "$INPUT" ] && [ -z "${CLAUDECODE:-}${CLAUDE_CODE:-}" ]; then
      printf '%s\\n' '{}'
      exit 0
    fi
    if [ -z "$EVENT" ] && [ -n "$INPUT" ]; then
      EVENT=$(extract_json_field "hook_event_name")
      if [ -z "$EVENT" ]; then
        EVENT=$(extract_json_field "event_name")
      fi
      if [ -z "$EVENT" ]; then
        EVENT=$(extract_json_field "event")
      fi
      if [ -z "$EVENT" ]; then
        EVENT=$(extract_json_field "name")
      fi
    fi
    EVENT_KEY=$(printf '%s' "$EVENT" | tr 'A-Z' 'a-z' | tr '-' '_' | tr '.' '_')
    STATUS=running
    case "$EVENT_KEY" in
      sessionstart|session_start|on_session_start|userpromptsubmit|user_prompt_submit|beforesubmitprompt|pre_llm_call|running|thinking|afteragentthought)
        STATUS=running ;;
      pretooluse|pre_tool_use|pre_tool_call|post_tool_call|beforeshellexecution|beforemcpexecution|tool)
        STATUS=tool ;;
      permissionrequest|pre_approval_request|notification|approval)
        STATUS=approval ;;
      stop|stop_completed|post_llm_call|on_session_end|afteragentresponse|session_idle|done|completed)
        STATUS=done ;;
      posttoolusefailure|stopfailure|stop_error|error|failed)
        STATUS=error ;;
      idle)
        STATUS=idle ;;
    esac
    if [ "$AGENT" = "cursor" ]; then
      case "$EVENT_KEY" in
        sessionstart|session_start)
          printf '%s\\n' '{}'
          exit 0 ;;
        afteragentresponse)
          STATUS=running ;;
        pretooluse|pre_tool_use)
          TOOL=$(printf '%s' "$INPUT" | tr '\\n' ' ' | sed -n 's/.*"tool_name"[[:space:]]*:[[:space:]]*"\\([^"]*\\)".*/\\1/p')
          case "$TOOL" in
            Read|Grep|Glob|Ripgrep|ReadFile|SemanticSearch) STATUS=running ;;
            *) STATUS=tool ;;
          esac
          ;;
        stop)
          STOP_STATUS=$(printf '%s' "$INPUT" | tr '\\n' ' ' | sed -n 's/.*"status"[[:space:]]*:[[:space:]]*"\\([^"]*\\)".*/\\1/p' | tr 'A-Z' 'a-z')
          case "$STOP_STATUS" in
            error|aborted|failed) STATUS=error ;;
            *) STATUS=done ;;
          esac
          ;;
      esac
    fi
    "$ROOT/agent-status.sh" "$AGENT" "$STATUS" || true
    printf '%s\\n' '{}'
    exit 0
    """

    private static let codexHookScript = """
    #!/bin/sh
    # Agent Light Codex hook. Path has no spaces and no extra argv so Codex
    # can exec it the same way it runs ~/.codex/hooks/mnemon/*.sh.
    NOTIFY="$HOME/Library/Application Support/AgentKeyboard/notify.sh"
    EVENT=${1:-}
    INPUT=""
    INPUT=$(cat)
    extract_json_field() {
      local key="$1"
      printf '%s' "$INPUT" | tr '\\n' ' ' | sed -n "s/.*\\\"${key}\\\"[[:space:]]*:[[:space:]]*\\\"\\([^\\\"]*\\)\\\".*/\\1/p"
    }
    if [ -z "$EVENT" ] && [ -n "$INPUT" ]; then
      EVENT=$(extract_json_field "hook_event_name")
      if [ -z "$EVENT" ]; then
        EVENT=$(extract_json_field "event_name")
      fi
      if [ -z "$EVENT" ]; then
        EVENT=$(extract_json_field "event")
      fi
      if [ -z "$EVENT" ]; then
        EVENT=$(extract_json_field "name")
      fi
    fi
    if [ -z "$EVENT" ]; then
      exit 0
    fi
    printf '%s' "$INPUT" | "$NOTIFY" codex "$EVENT" >/dev/null 2>/dev/null || true
    exit 0
    """

    private static let piTemplate = """
    # Copy into a pi-yaml-hooks config, or ~/.pi/autohooks.
    # Does not replace existing Pi packages.
    hooks:
      user.prompt.submit:
        - bash: "~/Library/Application Support/AgentKeyboard/notify.sh pi UserPromptSubmit"
      tool.before.*:
        - bash: "~/Library/Application Support/AgentKeyboard/notify.sh pi PreToolUse"
      session.idle:
        - bash: "~/Library/Application Support/AgentKeyboard/notify.sh pi Stop"
    """
}
