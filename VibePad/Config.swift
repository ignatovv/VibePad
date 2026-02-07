//
//  Config.swift
//  VibePad
//

import Foundation

struct VibePadConfig: Codable, Sendable {
    var version: Int
    var profile: String
    var mappings: [String: ActionConfig]
    var l1Mappings: [String: ActionConfig]?
    var stickConfig: StickConfig?
}

struct ActionConfig: Codable, Sendable {
    var type: String          // "keystroke", "stickyKeystroke", or "typeText"
    var key: String?          // for keystroke / stickyKeystroke
    var modifiers: [String]?  // for keystroke / stickyKeystroke (per-keystroke)
    var stickyModifiers: [String]?  // for stickyKeystroke (held until L1 release)
    var text: String?         // for typeText
    var description: String?  // human-readable label for HUD
    var repeats: Bool?        // hold-to-repeat (default false)
    var repeatDelay: Double?  // seconds before repeat starts (default 0.3)
    var repeatInterval: Double? // seconds between repeats (default 0.05)
    var trigger: String?      // "onPress" (default), "onRelease", "onPressAndRelease"
}

struct StickConfig: Codable, Sendable {
    var leftStickDeadzone: Float?
    var rightStickDeadzone: Float?
    var arrowPressThreshold: Float?
    var arrowReleaseThreshold: Float?
    var scrollSensitivity: Float?
}

// MARK: - Load / Save

extension VibePadConfig {

    private static var configDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".vibepad")
    }

    static var configFileURL: URL {
        configDirectory.appendingPathComponent("config.json")
    }

    /// Load config from disk. Returns nil if the file doesn't exist.
    static func load() -> VibePadConfig? {
        let path = configFileURL
        guard FileManager.default.fileExists(atPath: path.path) else {
            print("[VibePad] No config file at \(path.path), using defaults")
            return nil
        }
        do {
            let data = try Data(contentsOf: path)
            let decoder = JSONDecoder()
            let config = try decoder.decode(VibePadConfig.self, from: data)
            print("[VibePad] Loaded config from \(path.path) (profile: \(config.profile))")
            return config
        } catch {
            print("[VibePad] Failed to parse config: \(error). Using defaults.")
            return nil
        }
    }

    /// Write current code defaults to disk (on-demand, e.g. when user opens Custom Key Bindings).
    static func writeCurrentDefaults() {
        let config = defaultConfig()
        do {
            let dir = configDirectory
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)
            try data.write(to: configFileURL, options: .atomic)
            print("[VibePad] Wrote default config to \(configFileURL.path)")
        } catch {
            print("[VibePad] Failed to write config: \(error)")
        }
    }

    /// Build a config from the hardcoded defaults in InputMapper.
    static func defaultConfig() -> VibePadConfig {
        VibePadConfig(
            version: 1,
            profile: "claude-code",
            mappings: InputMapper.defaultMappings.reduce(into: [:]) { dict, pair in
                dict[pair.key.rawValue] = ActionConfig(from: pair.value, description: InputMapper.defaultDescriptions[pair.key],
                                                       repeatConfig: InputMapper.defaultRepeatConfigs[pair.key],
                                                       triggerMode: InputMapper.defaultTriggerModes[pair.key])
            },
            l1Mappings: InputMapper.l1Mappings.reduce(into: [:]) { dict, pair in
                dict[pair.key.rawValue] = ActionConfig(from: pair.value, description: InputMapper.l1Descriptions[pair.key],
                                                       repeatConfig: InputMapper.l1RepeatDefaults[pair.key],
                                                       triggerMode: InputMapper.l1TriggerDefaults[pair.key])
            },
            stickConfig: StickConfig(
                leftStickDeadzone: 0.3,
                rightStickDeadzone: 0.2,
                arrowPressThreshold: 0.5,
                arrowReleaseThreshold: 0.3,
                scrollSensitivity: 15.0
            )
        )
    }
}

// MARK: - ActionConfig ↔ MappedAction conversion

extension ActionConfig {

    init(from action: MappedAction, description: String? = nil,
         repeatConfig: (delay: CFAbsoluteTime, interval: CFAbsoluteTime)? = nil,
         triggerMode: TriggerMode? = nil) {
        switch action {
        case .keystroke(let key, let modifiers):
            self.init(type: "keystroke", key: key, modifiers: modifiers, stickyModifiers: nil, text: nil, description: description,
                      repeats: repeatConfig != nil ? true : nil,
                      repeatDelay: repeatConfig?.delay, repeatInterval: repeatConfig?.interval,
                      trigger: triggerMode != .onPress ? triggerMode?.rawValue : nil)
        case .stickyKeystroke(let key, let modifiers, let stickyMods):
            self.init(type: "stickyKeystroke", key: key, modifiers: modifiers, stickyModifiers: stickyMods, text: nil, description: description,
                      repeats: repeatConfig != nil ? true : nil,
                      repeatDelay: repeatConfig?.delay, repeatInterval: repeatConfig?.interval,
                      trigger: triggerMode != .onPress ? triggerMode?.rawValue : nil)
        case .typeText(let text):
            self.init(type: "typeText", key: nil, modifiers: nil, stickyModifiers: nil, text: text, description: description,
                      repeats: repeatConfig != nil ? true : nil,
                      repeatDelay: repeatConfig?.delay, repeatInterval: repeatConfig?.interval,
                      trigger: triggerMode != .onPress ? triggerMode?.rawValue : nil)
        case .smartPaste:
            self.init(type: "smartPaste", key: nil, modifiers: nil, stickyModifiers: nil, text: nil, description: description,
                      repeats: nil, repeatDelay: nil, repeatInterval: nil,
                      trigger: triggerMode != .onPress ? triggerMode?.rawValue : nil)
        }
    }

    func toMappedAction() -> MappedAction? {
        switch type {
        case "keystroke":
            guard let key, KeyboardEmitter.keyCodeMap[key] != nil else {
                print("[VibePad] Config: unknown key \"\(key ?? "<nil>")\"")
                return nil
            }
            return .keystroke(key: key, modifiers: modifiers ?? [])
        case "stickyKeystroke":
            guard let key, KeyboardEmitter.keyCodeMap[key] != nil else {
                print("[VibePad] Config: unknown key \"\(key ?? "<nil>")\"")
                return nil
            }
            return .stickyKeystroke(key: key, modifiers: modifiers ?? [], stickyModifiers: stickyModifiers ?? [])
        case "typeText":
            guard let text else {
                print("[VibePad] Config: typeText action missing text")
                return nil
            }
            return .typeText(text)
        case "smartPaste":
            return .smartPaste
        default:
            print("[VibePad] Config: unknown action type \"\(type)\"")
            return nil
        }
    }
}

// MARK: - Dictionary conversion

extension Dictionary where Key == String, Value == ActionConfig {

    func toButtonMappings() -> [GamepadButton: MappedAction] {
        var result: [GamepadButton: MappedAction] = [:]
        for (name, actionConfig) in self {
            guard let button = GamepadButton(rawValue: name) else {
                print("[VibePad] Config: unknown button \"\(name)\", skipping")
                continue
            }
            guard let action = actionConfig.toMappedAction() else {
                continue
            }
            result[button] = action
        }
        return result
    }

    func toButtonDescriptions() -> [GamepadButton: String] {
        var result: [GamepadButton: String] = [:]
        for (name, actionConfig) in self {
            guard let button = GamepadButton(rawValue: name),
                  let desc = actionConfig.description else { continue }
            result[button] = desc
        }
        return result
    }

    func toButtonRepeatConfigs() -> [GamepadButton: (delay: CFAbsoluteTime, interval: CFAbsoluteTime)] {
        var result: [GamepadButton: (delay: CFAbsoluteTime, interval: CFAbsoluteTime)] = [:]
        for (name, actionConfig) in self {
            guard let button = GamepadButton(rawValue: name),
                  actionConfig.repeats == true else { continue }
            result[button] = (
                delay: actionConfig.repeatDelay ?? 0.3,
                interval: actionConfig.repeatInterval ?? 0.05
            )
        }
        return result
    }

    func toButtonTriggerModes() -> [GamepadButton: TriggerMode] {
        var result: [GamepadButton: TriggerMode] = [:]
        for (name, actionConfig) in self {
            guard let button = GamepadButton(rawValue: name),
                  let triggerStr = actionConfig.trigger,
                  let mode = TriggerMode(rawValue: triggerStr) else { continue }
            result[button] = mode
        }
        return result
    }
}
