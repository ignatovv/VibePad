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
    var type: String          // "keystroke" or "typeText"
    var key: String?          // for keystroke
    var modifiers: [String]?  // for keystroke
    var text: String?         // for typeText
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

    /// Load config from disk. Returns (config, existed) where `existed` is false if the file was missing.
    static func load() -> (config: VibePadConfig, existed: Bool) {
        let path = configFileURL
        guard FileManager.default.fileExists(atPath: path.path) else {
            print("[VibePad] No config file at \(path.path), using defaults")
            return (defaultConfig(), false)
        }
        do {
            let data = try Data(contentsOf: path)
            let decoder = JSONDecoder()
            let config = try decoder.decode(VibePadConfig.self, from: data)
            print("[VibePad] Loaded config from \(path.path) (profile: \(config.profile))")
            return (config, true)
        } catch {
            print("[VibePad] Failed to parse config: \(error). Using defaults.")
            return (defaultConfig(), true)
        }
    }

    /// Write the given config (or defaults) to disk.
    static func writeDefaults(_ config: VibePadConfig? = nil) {
        let config = config ?? defaultConfig()
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
                dict[pair.key.rawValue] = ActionConfig(from: pair.value)
            },
            l1Mappings: InputMapper.l1Mappings.reduce(into: [:]) { dict, pair in
                dict[pair.key.rawValue] = ActionConfig(from: pair.value)
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

    init(from action: MappedAction) {
        switch action {
        case .keystroke(let key, let modifiers):
            self.init(type: "keystroke", key: key, modifiers: modifiers, text: nil)
        case .typeText(let text):
            self.init(type: "typeText", key: nil, modifiers: nil, text: text)
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
        case "typeText":
            guard let text else {
                print("[VibePad] Config: typeText action missing text")
                return nil
            }
            return .typeText(text)
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
}
