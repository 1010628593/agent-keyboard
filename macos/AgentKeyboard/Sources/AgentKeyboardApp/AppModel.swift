import AgentKeyboardCore
import AppKit
import Foundation
import SwiftUI

@Observable
@MainActor
final class AppModel {
    var dashboard = Dashboard()
    var lastPixels: [RGB] = Array(repeating: .black, count: AK.ledCount)
    var connection: ConnectionState = .disconnected
    var style: RenderStyle = .dashboard
    var idleWhite: Double = AK.defaultIdleWhite
    var simulate = false
    var lastError: String?
    var lightingMap: LightingMap = .scopeII
    var identity: DeviceIdentity?
    var discovered: [DeviceIdentity] = []
    var logs: [LogEntry] = []
    var integrations: [IntegrationSpec] = []
    var selectedAgentID: String? = "hermes"
    var lightingState: AgentStatus = .running
    var sidebar: SidebarItem = .devices
    var selectedPeripheral: PeripheralKind = .keyboard
    var agentLooks: [String: [AgentStatus: StateLook]] = AgentLookBook.seeded()
    var pinnedCanvas: StateLook?
    var lightingAppliedAt: TimeInterval = 0
    var agentLightingEnabled = true
    var brightness: Double = AK.defaultBrightness
    var appearance: AppearancePreference = .system
    var language: LanguagePreference = .system
    var bridgeListening = false
    var watchdogEnabled = true
    var eventsInWindow = 0
    var lastHIDWrite: Date?
    var hidWriteFailures = 0
    var startedAt = Date()

    @ObservationIgnored private var keyboard: KeyboardDriver?
    @ObservationIgnored private var bridge = EventBridge()
    @ObservationIgnored private var engineTask: Task<Void, Never>?
    @ObservationIgnored private var reconnectTask: Task<Void, Never>?
    @ObservationIgnored private let snapshots = SnapshotBox()
    @ObservationIgnored private(set) var frames = 0
    @ObservationIgnored private var didStart = false
    @ObservationIgnored private var eventTimes: [TimeInterval] = []
    @ObservationIgnored private var config = AgentKeyboardConfig()
    @ObservationIgnored private var reconnectAttempt = 0
    @ObservationIgnored private var userStopped = false
    @ObservationIgnored private var persistTask: Task<Void, Never>?
    @ObservationIgnored private var persistLooksTask: Task<Void, Never>?

    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected(String)
        case failed(String)

        var title: String {
            switch self {
            case .disconnected: "Disconnected"
            case .connecting: "Connecting"
            case .connected(let name): name
            case .failed(let message): message
            }
        }

        var isLive: Bool {
            if case .connected = self { return true }
            return false
        }
    }

    var selectedSlot: AgentSlot? {
        if let selectedAgentID {
            return dashboard.resolve(selectedAgentID) ?? dashboard.slot(forAgentID: selectedAgentID)
        }
        return dashboard.primary
    }

    var peripherals: [PeripheralSnapshot] {
        [
            .init(
                kind: .keyboard,
                name: identity?.product ?? PeripheralKind.keyboard.product,
                connected: connection.isLive
            ),
            .init(kind: .mouse, name: PeripheralKind.mouse.product, connected: false),
        ]
    }

    var connectedPeripherals: [PeripheralSnapshot] { peripherals.filter(\.connected) }

    var connectedCount: Int { peripherals.filter(\.connected).count }

    var resolvedLocale: Locale {
        language.locale ?? .autoupdatingCurrent
    }

    var framesRendered: Int { frames }

    var uptimeInterval: TimeInterval {
        Date().timeIntervalSince(startedAt)
    }

    func productName(for kind: PeripheralKind) -> String {
        if kind == .keyboard { return identity?.product ?? kind.product }
        return kind.product
    }

    func isConnected(_ kind: PeripheralKind) -> Bool {
        switch kind {
        case .keyboard: connection.isLive
        case .mouse: false
        }
    }

    func look(for status: AgentStatus, agentID: String? = nil) -> StateLook {
        let id = agentID ?? selectedAgentID ?? "hermes"
        return AgentLookBook.look(agentID: id, status: status, book: agentLooks)
    }

    var lightingAppliedRecently: Bool {
        lightingAppliedAt > 0 && uptime - lightingAppliedAt < 2
    }

    func start() {
        guard !didStart else { return }
        didStart = true
        startedAt = Date()
        loadConfig()
        loadPreferences()
        applyAppearance()
        if selectedAgentID == nil {
            selectedAgentID = "hermes"
        }
        startBridge()
        ensureAgentHooks()
        refreshDevices()
        connect()
        startEngine()
    }

    func shutdown() {
        userStopped = true
        reconnectTask?.cancel()
        reconnectTask = nil
        engineTask?.cancel()
        engineTask = nil
        bridge.stop()
        bridgeListening = false
        try? keyboard?.restoreStatic(color: .white, brightness: 8)
        keyboard?.close()
        keyboard = nil
        connection = .disconnected
    }

    func connect() {
        persistPreferences()
        userStopped = false
        connection = .connecting
        lastError = nil
        keyboard?.close()
        keyboard = nil
        refreshDevices()
        do {
            if simulate {
                let null = NullKeyboard()
                try null.open()
                keyboard = null
                identity = null.identity
                lightingMap = null.lightingMap
                connection = .connected(null.identity.product)
                log("hid", "Simulator connected")
            } else {
                let hid = KeyboardHID()
                try hid.open()
                keyboard = hid
                identity = hid.identity
                lightingMap = hid.lightingMap
                lastPixels = Array(repeating: .black, count: lightingMap.ledCount)
                connection = .connected(hid.identity.product)
                reconnectAttempt = 0
                log("hid", "Opened \(hid.identity.product) \(hid.identity.pidHex)")
            }
        } catch {
            keyboard = nil
            lastError = describe(error)
            connection = .failed(AKString("Keyboard not available", locale: resolvedLocale))
            log("hid", lastError ?? "open failed")
            scheduleReconnect()
        }
    }

    func apply(_ event: AgentEvent) {
        if event.status != nil {
            clearCanvasPin()
        }
        do {
            try dashboard.apply(event, now: uptime)
            markEvent()
            log("bridge", "\(event.agent) \(event.status?.rawValue ?? "update")", agent: event.agent)
        } catch {
            log("bridge", String(describing: error), agent: event.agent)
        }
        publishNow()
    }

    func setStatus(_ status: AgentStatus, for slot: AgentSlot) {
        apply(AgentEvent(agent: slot.spec.slot, status: status))
    }

    func setContext(_ context: Double, for slot: AgentSlot) {
        apply(AgentEvent(agent: slot.spec.slot, context: context))
    }

    func idleAll() {
        for slot in dashboard.slots where slot.isAssigned {
            apply(AgentEvent(agent: slot.spec.slot, status: .idle, context: 0))
        }
    }

    func selectAgent(_ agentID: String) {
        selectedAgentID = agentID
    }

    /// Move the agent on a slot one position left/right on the F-row. Persists to agents.toml.
    func moveAgent(slotID: String, offset: Int) {
        guard let index = dashboard.slots.firstIndex(where: { $0.spec.slot == slotID }) else { return }
        let target = index + offset
        guard dashboard.slots.indices.contains(target) else { return }
        let neighborSlot = dashboard.slots[target].spec.slot
        let movedName = dashboard.slots[index].spec.name
        dashboard.swapAssignments(slotA: slotID, slotB: neighborSlot)
        persistAgentSpecs()
        log("config", "Moved \(movedName) to \(dashboard.slots[target].spec.keyName)")
    }

    /// Rewrite agents.toml from the current dashboard slot assignments.
    func persistAgentSpecs() {
        let url = AgentKeyboardConfig.applicationSupportDirectory.appending(path: "agents.toml")
        let text = agentsTOMLText()
        do {
            try FileManager.default.createDirectory(
                at: AgentKeyboardConfig.applicationSupportDirectory,
                withIntermediateDirectories: true
            )
            try text.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            log("config", "write agents.toml failed: \(error)")
        }
    }

    var agentsConfigURL: URL {
        AgentKeyboardConfig.applicationSupportDirectory.appending(path: "agents.toml")
    }

    func revealAgentsConfig() {
        NSWorkspace.shared.selectFile(
            agentsConfigURL.path,
            inFileViewerRootedAtPath: AgentKeyboardConfig.applicationSupportDirectory.path
        )
    }

    func useForAgentLighting() {
        agentLightingEnabled = true
        sidebar = .agents
        persistPreferences()
    }

    func openLighting(for status: AgentStatus) {
        lightingState = status
        selectedPeripheral = .keyboard
        sidebar = .lighting
    }

    func setEffect(_ effect: LightingEffect) {
        var look = look(for: lightingState)
        look.effect = effect
        writeLook(look)
    }

    func setColor(_ color: Color) {
        var look = look(for: lightingState)
        look.color = RGB(color)
        writeLook(look)
    }

    func setBrightness(_ value: Double) {
        var look = look(for: lightingState)
        look.brightness = value
        writeLook(look)
    }

    func setSpeed(_ value: Double) {
        var look = look(for: lightingState)
        look.speed = value
        writeLook(look)
    }

    func applyLighting() {
        selectedPeripheral = .keyboard
        let look = look(for: lightingState)
        writeLook(look)
        agentLightingEnabled = true
        pinnedCanvas = look
        lightingAppliedAt = uptime
        persistPreferences()
        persistPinnedCanvas()
        flushLighting()
        log("lighting", "Applied \(selectedAgentID ?? "?") \(lightingState.rawValue)")
    }

    func applyAppearance() {
        NSApp.appearance = appearance.nsAppearance
    }

    func runDemo() {
        Task { await playDemo() }
    }

    func refreshDevices() {
        discovered = KeyboardHID.enumerateDevices()
    }

    var libraryIntegrations: [IntegrationSpec] {
        let ids = Set(AgentProfile.libraryIDs)
        return integrations.filter { ids.contains($0.agentID) }
    }

    var needsHookInstall: Bool {
        libraryIntegrations.contains { $0.available && !$0.installed }
    }

    func refreshIntegrations() {
        integrations = HookInstaller.specs()
    }

    func installHooks() {
        do {
            try HookInstaller.installSupportScripts()
            integrations = try HookInstaller.installAll()
            log("hooks", "Installed available agent hooks")
        } catch {
            lastError = String(describing: error)
            log("hooks", lastError ?? "install failed")
        }
    }

    private func ensureAgentHooks() {
        do {
            integrations = try HookInstaller.installAll()
            log("hooks", "Merged notify.sh into agent configs")
        } catch {
            integrations = HookInstaller.specs()
            log("hooks", String(describing: error))
        }
    }

    func installHook(agentID: String) {
        do {
            try HookInstaller.install(agentID: agentID)
            integrations = HookInstaller.specs()
            log("hooks", "Installed \(agentID)")
        } catch {
            lastError = String(describing: error)
            log("hooks", lastError ?? "install failed", agent: agentID)
        }
    }

    func persistPreferences() {
        UserDefaults.standard.set(style.rawValue, forKey: Prefs.style)
        UserDefaults.standard.set(idleWhite, forKey: Prefs.idleWhite)
        UserDefaults.standard.set(simulate, forKey: Prefs.simulate)
        UserDefaults.standard.set(watchdogEnabled, forKey: Prefs.watchdog)
        UserDefaults.standard.set(brightness, forKey: Prefs.brightness)
        UserDefaults.standard.set(appearance.rawValue, forKey: Prefs.appearance)
        UserDefaults.standard.set(language.rawValue, forKey: Prefs.language)
        UserDefaults.standard.set(agentLightingEnabled, forKey: Prefs.agentLighting)
        persistLooks()
        persistPinnedCanvas()
    }

    /// Debounced variant for continuous controls (sliders) that fire many times per drag.
    func persistPreferencesDebounced() {
        persistTask?.cancel()
        persistTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            self?.persistPreferences()
        }
    }

    func snapshot() -> [String: Any] {
        [
            "agents": dashboard.slots.map { slot -> [String: Any] in
                var row: [String: Any] = [
                    "slot": slot.spec.slot,
                    "id": slot.spec.agentID,
                    "name": slot.spec.name,
                    "key": slot.spec.keyName,
                    "status": slot.status.rawValue,
                    "context": slot.context,
                    "message": slot.message,
                ]
                if let progress = slot.progress {
                    row["progress"] = progress
                }
                return row
            }
        ]
    }

    private var uptime: TimeInterval {
        ProcessInfo.processInfo.systemUptime
    }

    private func loadConfig() {
        config = AgentKeyboardConfig.load()
        dashboard = Dashboard(specs: config.agents)
        style = config.style
        idleWhite = config.idleWhite
        writeDefaultConfigIfNeeded()
    }

    private func writeDefaultConfigIfNeeded() {
        let url = AgentKeyboardConfig.applicationSupportDirectory.appending(path: "agents.toml")
        guard !FileManager.default.isReadableFile(atPath: url.path) else { return }
        try? FileManager.default.createDirectory(
            at: AgentKeyboardConfig.applicationSupportDirectory,
            withIntermediateDirectories: true
        )
        try? agentsTOMLText().write(to: url, atomically: true, encoding: .utf8)
    }

    private func agentsTOMLText() -> String {
        """
        [bridge]
        host = "127.0.0.1"
        port = \(config.port)

        [render]
        fps = \(config.fps)
        style = "\(style.rawValue)"
        idle_white = \(idleWhite)
        idle_timeout = \(Int(config.idleTimeout))

        """ + dashboard.slots.map { slot in
            let spec = slot.spec
            return """
            [[agents]]
            slot = "\(spec.slot)"
            id = "\(spec.agentID)"
            name = "\(spec.name)"
            key = "\(spec.keyName)"
            """
        }.joined(separator: "\n\n") + "\n"
    }

    private func loadPreferences() {
        if let raw = UserDefaults.standard.string(forKey: Prefs.style),
           let stored = RenderStyle(rawValue: raw)
        {
            style = stored
        }
        if UserDefaults.standard.object(forKey: Prefs.idleWhite) != nil {
            idleWhite = UserDefaults.standard.double(forKey: Prefs.idleWhite)
        }
        simulate = UserDefaults.standard.bool(forKey: Prefs.simulate)
        if UserDefaults.standard.object(forKey: Prefs.watchdog) != nil {
            watchdogEnabled = UserDefaults.standard.bool(forKey: Prefs.watchdog)
        }
        if UserDefaults.standard.object(forKey: Prefs.brightness) != nil {
            brightness = UserDefaults.standard.double(forKey: Prefs.brightness)
        }
        if let raw = UserDefaults.standard.string(forKey: Prefs.appearance),
           let stored = AppearancePreference(rawValue: raw)
        {
            appearance = stored
        }
        if let raw = UserDefaults.standard.string(forKey: Prefs.language),
           let stored = LanguagePreference(rawValue: raw)
        {
            language = stored
        }
        if UserDefaults.standard.object(forKey: Prefs.agentLighting) != nil {
            agentLightingEnabled = UserDefaults.standard.bool(forKey: Prefs.agentLighting)
        }
        loadLooks()
        loadPinnedCanvas()
    }

    private func persistLooks() {
        var payload: [String: [String: [String: Any]]] = [:]
        for (agentID, looks) in agentLooks {
            var row: [String: [String: Any]] = [:]
            for (status, look) in looks {
                row[status.rawValue] = look.dictionary()
            }
            payload[agentID] = row
        }
        UserDefaults.standard.set(payload, forKey: Prefs.agentLooks)
    }

    private func persistPinnedCanvas() {
        if let pinnedCanvas {
            UserDefaults.standard.set(pinnedCanvas.dictionary(), forKey: Prefs.pinnedCanvas)
        } else {
            UserDefaults.standard.removeObject(forKey: Prefs.pinnedCanvas)
        }
    }

    private func loadLooks() {
        var overlay: [AgentStatus: StateLook] = [:]
        if let payload = UserDefaults.standard.dictionary(forKey: Prefs.looks) {
            for (key, value) in payload {
                guard let status = AgentStatus(rawValue: key),
                      let row = value as? [String: Any],
                      let look = StateLook(dictionary: row)
                else { continue }
                overlay[status] = look
            }
        }
        if let payload = UserDefaults.standard.dictionary(forKey: Prefs.agentLooks) {
            var loaded = AgentLookBook.seeded()
            for (agentID, value) in payload {
                guard let rows = value as? [String: Any] else { continue }
                var looks = loaded[agentID] ?? AgentLookBook.defaults(for: agentID)
                for (statusRaw, lookValue) in rows {
                    guard let status = AgentStatus(rawValue: statusRaw),
                          let row = lookValue as? [String: Any],
                          let look = StateLook(dictionary: row)
                    else { continue }
                    looks[status] = look
                }
                loaded[agentID] = looks
            }
            agentLooks = loaded
        } else if let numpad = numpadLooksFromLegacy() {
            agentLooks = AgentLookBook.seeded(overlay: overlay.merging(numpad) { _, new in new })
        } else if !overlay.isEmpty {
            agentLooks = AgentLookBook.seeded(overlay: overlay)
        } else {
            agentLooks = AgentLookBook.seeded()
        }
    }

    private func numpadLooksFromLegacy() -> [AgentStatus: StateLook]? {
        guard let payload = UserDefaults.standard.dictionary(forKey: Prefs.zoneLooks),
              let rows = payload["numpad"] as? [String: Any]
        else { return nil }
        var looks: [AgentStatus: StateLook] = [:]
        for (statusRaw, lookValue) in rows {
            guard let status = AgentStatus(rawValue: statusRaw),
                  let row = lookValue as? [String: Any],
                  let look = StateLook(dictionary: row)
            else { continue }
            looks[status] = look
        }
        return looks.isEmpty ? nil : looks
    }

    private func loadPinnedCanvas() {
        if let row = UserDefaults.standard.dictionary(forKey: Prefs.pinnedCanvas),
           let look = StateLook(dictionary: row)
        {
            pinnedCanvas = look
            return
        }
        guard let payload = UserDefaults.standard.dictionary(forKey: Prefs.pinnedLooks) else { return }
        for key in ["main", "numpad", "fRow"] {
            guard let row = payload[key] as? [String: Any],
                  let look = StateLook(dictionary: row)
            else { continue }
            pinnedCanvas = look
            return
        }
    }

    private func writeLook(_ look: StateLook) {
        let id = selectedAgentID ?? "hermes"
        var book = agentLooks[id] ?? AgentLookBook.defaults(for: id)
        book[lightingState] = look
        agentLooks[id] = book
        persistLooksDebounced()
    }

    /// Looks change with every slider tick; coalesce UserDefaults writes.
    private func persistLooksDebounced() {
        persistLooksTask?.cancel()
        persistLooksTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            self?.persistLooks()
        }
    }

    private func clearCanvasPin() {
        guard pinnedCanvas != nil else { return }
        pinnedCanvas = nil
        persistPinnedCanvas()
    }

    private func lightingPreview() -> SceneRenderer.BoardPreview? {
        guard sidebar == .lighting else { return nil }
        return .canvas(look(for: lightingState))
    }

    private func paintFrame(now: TimeInterval, preview: SceneRenderer.BoardPreview?) -> [RGB] {
        if agentLightingEnabled {
            return SceneRenderer.renderBoard(
                dashboard,
                looks: agentLooks,
                now: now,
                map: lightingMap,
                idleWhite: idleWhite,
                globalBrightness: brightness,
                pinnedCanvas: pinnedCanvas,
                preview: preview
            )
        }
        let dim = RGB.white.scaled(idleWhite * brightness)
        return Array(repeating: dim, count: lightingMap.ledCount)
    }

    private func writePixels(_ pixels: [RGB]) {
        guard let keyboard else { return }
        do {
            try keyboard.writePixels(pixels)
            lastHIDWrite = Date()
            hidWriteFailures = 0
        } catch {
            hidWriteFailures += 1
            if hidWriteFailures == 1 || hidWriteFailures % 32 == 0 {
                log("hid", "write failed: \(error)")
            }
            if hidWriteFailures >= 64 {
                connection = .failed(AKString("HID write failed.", locale: resolvedLocale))
                scheduleReconnect()
            }
        }
    }

    private func flushLighting() {
        lastPixels = paintFrame(now: uptime, preview: lightingPreview())
        writePixels(lastPixels)
    }

    private func startEngine() {
        engineTask?.cancel()
        engineTask = Task { [weak self] in
            let interval = Duration.seconds(1.0 / Double(AK.defaultFPS))
            while !Task.isCancelled {
                self?.tick()
                try? await Task.sleep(for: interval)
            }
        }
    }

    private func tick() {
        let now = uptime
        dashboard.tick(now: now, idleTimeout: watchdogEnabled ? config.idleTimeout : 0)
        pruneEvents(now: now)
        lastPixels = paintFrame(now: now, preview: lightingPreview())
        frames += 1
        writePixels(lastPixels)
        publishNow()
    }

    private func publishNow() {
        var device: [String: Any] = [
            "product": identity?.product ?? keyboard?.identity.product ?? "none",
            "backend": simulate ? "null" : "iokit",
            "connected": connection.isLive,
            "exclusive": connection.isLive,
        ]
        if let identity {
            device["vid"] = String(format: "0x%04X", identity.vendorID)
            device["pid"] = identity.pidHex
            device["layout"] = identity.layoutName ?? "unmapped"
            device["vendor"] = identity.vendor.rawValue
        }
        snapshots.update(
            state: snapshot(),
            health: [
                "ok": true,
                "frames": frames,
                "bridge": bridgeListening,
                "device": device,
            ]
        )
    }

    private func startBridge() {
        bridge.onEvent = { [weak self] event in
            Task { @MainActor in
                self?.apply(event)
            }
        }
        bridge.snapshot = { [snapshots] in
            snapshots.state()
        }
        bridge.health = { [snapshots] in
            snapshots.health()
        }
        do {
            try bridge.start(port: config.port)
            bridgeListening = true
            log("bridge", "Listening on 127.0.0.1:\(config.port)")
        } catch {
            bridgeListening = false
            lastError = "HTTP :\(config.port) failed. Is python -m agent_keyboard serve still running?"
            log("bridge", lastError ?? "listen failed")
        }
    }

    private func scheduleReconnect() {
        guard !simulate, !userStopped else { return }
        reconnectTask?.cancel()
        let delay = Swift.min(30, pow(2.0, Double(Swift.min(reconnectAttempt, 4))))
        reconnectAttempt += 1
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !self.userStopped, !self.simulate else { return }
            self.connect()
        }
    }

    private func playDemo() async {
        let scenes: [(AgentStatus, Double)] = [
            (.idle, 0),
            (.running, 0.35),
            (.tool, 0.55),
            (.approval, 0.55),
            (.done, 0),
            (.error, 0),
            (.running, 0.92),
            (.idle, 0),
        ]
        let targets = [selectedAgentID ?? "hermes"]
        for (status, context) in scenes {
            for agent in targets {
                apply(AgentEvent(agent: agent, status: status, context: context, message: status.rawValue))
            }
            try? await Task.sleep(for: .seconds(1.6))
        }
    }

    private func markEvent() {
        eventTimes.append(uptime)
        pruneEvents(now: uptime)
        eventsInWindow = eventTimes.count
    }

    private func pruneEvents(now: TimeInterval) {
        eventTimes.removeAll { now - $0 > 60 }
        eventsInWindow = eventTimes.count
    }

    private func log(_ source: String, _ message: String, agent: String? = nil) {
        logs.insert(LogEntry(source: source, message: message, agent: agent), at: 0)
        if logs.count > AK.eventLogLimit {
            logs = Array(logs.prefix(AK.eventLogLimit))
        }
    }

    private func describe(_ error: Error) -> String {
        if let hid = error as? HIDError {
            switch hid {
            case .notFound:
                return AKString(
                    "No ASUS Aura keyboard. Close Armoury Crate, OpenRGB, and python -m agent_keyboard serve.",
                    locale: resolvedLocale
                )
            case .openFailed:
                return AKString(
                    "Aura interface is busy. Stop the Python daemon or Armoury Crate, then Connect.",
                    locale: resolvedLocale
                )
            case .notConnected:
                return AKString("Keyboard disconnected.", locale: resolvedLocale)
            case .setReport:
                return AKString("HID write failed.", locale: resolvedLocale)
            case .layoutUnmapped(let name):
                return AKString(
                    "\(name) is ASUS Aura but the LED map is not implemented yet.",
                    locale: resolvedLocale
                )
            }
        }
        return String(describing: error)
    }

    static var preview: AppModel {
        let model = AppModel()
        var dash = Dashboard()
        try? dash.apply(AgentEvent(agent: "hermes", status: .running, context: 0.42), now: 1)
        model.dashboard = dash
        model.selectedAgentID = "hermes"
        model.connection = .connected("ROG STRIX SCOPE II RX")
        model.identity = AsusAuraCatalog.identity(
            productID: 0x1AB5,
            product: "ROG STRIX SCOPE II RX",
            firmware: "01.00.15"
        )
        model.bridgeListening = true
        model.eventsInWindow = 12
        model.lastHIDWrite = Date()
        model.lightingMap = .scopeII
        model.discovered = [model.identity!]
        model.lastPixels = SceneRenderer.renderBoard(
            dash,
            looks: AgentLookBook.seeded(),
            now: 2.2,
            globalBrightness: 0.8
        )
        model.sidebar = .devices
        model.integrations = HookInstaller.specs()
        return model
    }

    static var previewChinese: AppModel {
        let model = preview
        model.language = .simplifiedChinese
        return model
    }
}

private enum Prefs {
    static let style = "ak.style"
    static let idleWhite = "ak.idleWhite"
    static let simulate = "ak.simulate"
    static let watchdog = "ak.watchdog"
    static let brightness = "ak.brightness"
    static let appearance = "ak.appearance"
    static let language = "ak.language"
    static let agentLighting = "ak.agentLighting"
    static let looks = "ak.stateLooks"
    static let zoneLooks = "ak.zoneLooks"
    static let agentLooks = "ak.agentLooks"
    static let pinnedLooks = "ak.pinnedLooks"
    static let pinnedCanvas = "ak.pinnedCanvas"
}

private final class SnapshotBox: @unchecked Sendable {
    private let lock = NSLock()
    private var published: [String: Any] = [:]
    private var publishedHealth: [String: Any] = ["ok": true]

    func update(state: [String: Any], health: [String: Any]) {
        lock.lock()
        published = state
        publishedHealth = health
        lock.unlock()
    }

    func state() -> [String: Any] {
        lock.lock()
        defer { lock.unlock() }
        return published
    }

    func health() -> [String: Any] {
        lock.lock()
        defer { lock.unlock() }
        return publishedHealth
    }
}
