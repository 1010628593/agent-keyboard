import Foundation
import Testing
@testable import AgentKeyboardCore

@Test func keyAliasesResolve() {
    #expect(KeyName.resolve("esc") == "ESCAPE")
    #expect(KeyName.resolve("ENTER") == "ANSI_ENTER")
    #expect(KeyName.resolve("spacebar") == "SPACE")
    #expect(KeyName.resolve("NOPE") == nil)
}

@Test func durationRequiredAndClamped() throws {
    #expect(throws: OverlayError.durationRequired) {
        _ = try OverlayParser.parseKeys(["keys": ["W": "#ffffff"]], now: 0)
    }
    let overlay = try OverlayParser.parseKeys(
        ["keys": ["W": "#ffffff"], "duration": 30, "brightness": 1],
        now: 10
    )
    #expect(overlay.duration == 15)
    #expect(overlay.clamped)
    #expect(overlay.brightness == 1)
    #expect(overlay.expired(now: 25))
    #expect(!overlay.expired(now: 24.9))
}

@Test func brightnessScalesPixels() throws {
    let full = try OverlayParser.parseKeys(
        ["keys": ["W": "#ffffff"], "duration": 5, "brightness": 1],
        now: 0
    )
    let half = try OverlayParser.parseKeys(
        ["keys": ["W": "#ffffff"], "duration": 5, "brightness": 0.5],
        now: 0
    )
    let w = KeyboardProfile.scopeII.index(named: "W")
    #expect(full.pixels(at: 0)[w] == RGB(255, 255, 255))
    #expect(half.pixels(at: 0)[w] == RGB(128, 128, 128))
    let snap = half.snapshot(now: 0)
    #expect(snap["brightness"] as? Double == 0.5)
    #expect((snap["keys"] as? [String])?.contains("W") == true)
}

@Test func spaceLightsEveryLEDUnknownKeyListsValidNames() throws {
    let space = KeyboardProfile.scopeII.indices(named: "SPACE")
    #expect(space.count == 3)
    let overlay = try OverlayParser.parseKeys(
        ["keys": ["spc": "#00ff00"], "duration": 4, "brightness": 1],
        now: 0
    )
    let pixels = overlay.pixels(at: 0)
    for index in space {
        #expect(pixels[index] == RGB(0, 255, 0))
    }
    #expect(throws: OverlayError.unknownKeys(["NOPE"])) {
        _ = try OverlayParser.parseKeys(
            ["keys": ["NOPE": "#ffffff"], "duration": 1, "brightness": 1],
            now: 0
        )
    }
}

@Test func overlayCoversCookbookReplaceBlacksRest() throws {
    let w = KeyboardProfile.scopeII.index(named: "W")
    let f4 = KeyboardProfile.scopeII.index(named: "F4")
    let base = Array(repeating: RGB(10, 20, 30), count: AK.ledCount)
    let overlay = try OverlayParser.parseKeys(
        ["keys": ["W": "#ff00aa"], "duration": 8, "brightness": 1, "mode": "overlay"],
        now: 0
    )
    let painted = overlay.composite(base: base, now: 1)
    #expect(painted[w] == RGB(255, 0, 170))
    #expect(painted[f4] == RGB(10, 20, 30))
    let replace = try OverlayParser.parseKeys(
        ["keys": ["W": "#ff00aa"], "duration": 8, "brightness": 1, "mode": "replace"],
        now: 0
    )
    let replaced = replace.composite(base: base, now: 1)
    #expect(replaced[w] == RGB(255, 0, 170))
    #expect(replaced[f4].isBlack)
}

@Test func loopAndNarrativeCues() throws {
    let frames = try OverlayParser.parseFrames(
        [
            "duration": 10,
            "brightness": 1,
            "loop": true,
            "fps": 2,
            "frames": [["W": "#ff0000"], ["W": "#0000ff"]],
        ],
        now: 0
    )
    let w = KeyboardProfile.scopeII.index(named: "W")
    #expect(frames.pixels(at: 0.1)[w]!.r > 200)
    #expect(frames.pixels(at: 0.6)[w]!.b > 200)
    #expect(frames.pixels(at: 1.1)[w]!.r > 200)
    let story = try OverlayParser.parseFrames(
        [
            "duration": 12,
            "brightness": 1,
            "loop": false,
            "cues": [
                ["at": 0, "keys": ["W": "#ff0000"]],
                ["at": 3, "keys": ["W": "#00ff00"]],
                ["at": 9, "keys": ["W": "#0000ff"]],
            ],
        ],
        now: 0
    )
    #expect(story.pixels(at: 1)[w]!.r > 200)
    #expect(story.pixels(at: 4)[w]!.g > 200)
    #expect(story.pixels(at: 11)[w]!.b > 200)
    let base = Array(repeating: RGB(1, 2, 3), count: AK.ledCount)
    #expect(story.composite(base: base, now: 12.01)[w] == RGB(1, 2, 3))
}

@Test func mcpInitializeListsTools() throws {
    let backend = MCPBackend(
        applyOverlay: { $0.snapshot(now: $0.startedAt) },
        releaseOverlay: { MCPOverlay.inactiveSnapshot() },
        snapshot: { ["agents": []] as [String: Any] },
        health: { ["ok": true] as [String: Any] }
    )
    let body = Data(#"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}"#.utf8)
    let (code, data) = try MCPProtocol.handle(body: body, now: 0, backend: backend)
    #expect(code == 200)
    let obj = try JSONSerialization.jsonObject(with: data!) as? [String: Any]
    let result = obj?["result"] as? [String: Any]
    #expect(result?["instructions"] is String)
    let listed = try MCPProtocol.handle(
        body: Data(#"{"jsonrpc":"2.0","id":2,"method":"tools/list"}"#.utf8),
        now: 0,
        backend: backend
    )
    let listedObj = try JSONSerialization.jsonObject(with: listed.1!) as? [String: Any]
    let tools = (listedObj?["result"] as? [String: Any])?["tools"] as? [[String: Any]] ?? []
    let names = tools.compactMap { $0["name"] as? String }
    #expect(names.contains("keyboard_keys"))
    #expect(names.contains("keyboard_frames"))
}

@Test func mergeCursorMCPIsIdempotent() throws {
    let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let url = dir.appending(path: "mcp.json")
    try """
    {
      "mcpServers": {
        "github": { "url": "https://example.com" }
      }
    }
    """.write(to: url, atomically: true, encoding: .utf8)
    _ = try HookInstaller.mergeCursorMCP(url: url)
    _ = try HookInstaller.mergeCursorMCP(url: url)
    let root = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
    let servers = root?["mcpServers"] as? [String: Any]
    #expect(servers?["github"] != nil)
    let agent = servers?["agent-keyboard"] as? [String: Any]
    #expect(agent?["url"] as? String == AK.mcpEndpoint)
}
