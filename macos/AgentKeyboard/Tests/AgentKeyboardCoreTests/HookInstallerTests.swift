import Foundation
import Testing
@testable import AgentKeyboardCore

@Test func notifyInvocationQuotesApplicationSupport() {
    let command = HookInstaller.notifyInvocation(agent: "cursor", event: "beforeSubmitPrompt")
    #expect(command.hasPrefix("'"))
    #expect(command.contains("notify.sh"))
    #expect(command.contains("cursor beforeSubmitPrompt"))
    let path = String(command.dropFirst().split(separator: "'").first ?? "")
    #expect(path.contains(" "))
}

@Test func mergeJSONHooksPreservesExistingCommands() throws {
    let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let url = dir.appending(path: "hooks.json")
    try """
    {
      "version": 1,
      "hooks": {
        "beforeSubmitPrompt": [
          { "command": "memmy-resume-hook.mjs", "timeout": 60 }
        ]
      }
    }
    """.write(to: url, atomically: true, encoding: .utf8)
    _ = try HookInstaller.mergeJSONHooks(
        url: url,
        events: ["beforeSubmitPrompt": "running", "stop": "done"],
        agent: "cursor",
        createIfMissing: false
    )
    let text = try String(contentsOf: url, encoding: .utf8)
    #expect(text.contains("memmy-resume-hook.mjs"))
    #expect(text.contains("notify.sh"))
    let root = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
    let hooks = root?["hooks"] as? [String: Any]
    let prompts = hooks?["beforeSubmitPrompt"] as? [[String: Any]] ?? []
    #expect((prompts.first?["command"] as? String)?.contains("notify.sh") == true)
    #expect((prompts.dropFirst().first?["command"] as? String)?.contains("memmy") == true)
    #expect((prompts.first?["timeout"] as? NSNumber)?.intValue == 2)
}

@Test func mergeNestedJSONHooksPreservesMnemon() throws {
    let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let url = dir.appending(path: "hooks.json")
    try """
    {
      "hooks": {
        "UserPromptSubmit": [
          {
            "hooks": [
              { "command": "/hooks/mnemon/user_prompt.sh", "type": "command" }
            ]
          }
        ]
      }
    }
    """.write(to: url, atomically: true, encoding: .utf8)
    _ = try HookInstaller.mergeNestedJSONHooks(
        url: url,
        events: ["UserPromptSubmit": "running"],
        agent: "codex",
        createIfMissing: false
    )
    let text = try String(contentsOf: url, encoding: .utf8)
    #expect(text.contains("mnemon"))
    #expect(text.contains("user_prompt.sh"))
    #expect(text.contains("notify.sh"))
    let root = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
    let hooks = root?["hooks"] as? [String: Any]
    let prompts = hooks?["UserPromptSubmit"] as? [[String: Any]] ?? []
    let firstNested = prompts.first?["hooks"] as? [[String: Any]]
    #expect((firstNested?.first?["command"] as? String)?.contains("notify.sh") == true)
    #expect((firstNested?.first?["timeout"] as? NSNumber)?.intValue == 2)
}

@Test func mergeNestedJSONHooksPreservesUnrelatedWorkbuddySettings() throws {
    let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let url = dir.appending(path: "settings.json")
    // Mirrors a real ~/.workbuddy/settings.json: no "hooks" key, unrelated top-level sections.
    try """
    {
      "enabledPlugins" : { "weixinpay@workbuddy-builtin" : true },
      "sandbox" : { "extraAllowWrite" : ["~/.tmeet"] },
      "claw" : { "channels" : {} }
    }
    """.write(to: url, atomically: true, encoding: .utf8)
    _ = try HookInstaller.mergeNestedJSONHooks(
        url: url,
        events: ["SessionStart": "running", "Stop": "done"],
        agent: "workbuddy",
        createIfMissing: false
    )
    let root = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
    #expect(root?["enabledPlugins"] != nil)
    #expect(root?["sandbox"] != nil)
    #expect(root?["claw"] != nil)
    let hooks = root?["hooks"] as? [String: Any]
    #expect(hooks?["SessionStart"] != nil)
    #expect(hooks?["Stop"] != nil)
    let text = try String(contentsOf: url, encoding: .utf8)
    #expect(text.contains("workbuddy SessionStart"))
}

@Test func mergeHermesHookPrependsWithoutReplacingMnemon() {
    let yaml = """
    hooks:
      on_session_start:
        - command: /Users/hanxin/.hermes/agent-hooks/mnemon/prime.sh
          timeout: 10
    """
    let wrapper = "/tmp/AgentKeyboard/hermes-on_session_start.sh"
    let merged = HookInstaller.mergeHermesHook(in: yaml, key: "on_session_start", wrapper: wrapper)
    #expect(merged.contains("mnemon/prime.sh"))
    #expect(merged.contains(wrapper))
    let again = HookInstaller.mergeHermesHook(in: merged, key: "on_session_start", wrapper: wrapper)
    #expect(again.components(separatedBy: wrapper).count == 2)
}
