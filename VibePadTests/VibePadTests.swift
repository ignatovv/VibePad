//
//  VibePadTests.swift
//  VibePadTests
//
//  Created by Vova Ignatov on 2/6/26.
//

import Foundation
import Testing
@testable import VibePad

// MARK: - ActionConfig ↔ MappedAction conversion

struct ActionConfigConversionTests {

    @Test func keystrokeRoundTrip() {
        let action = MappedAction.keystroke(key: "c", modifiers: ["control"])
        let config = ActionConfig(from: action)

        #expect(config.type == "keystroke")
        #expect(config.key == "c")
        #expect(config.modifiers == ["control"])
        #expect(config.text == nil)

        let back = config.toMappedAction()
        #expect(back == action)
    }

    @Test func typeTextRoundTrip() {
        let action = MappedAction.typeText("/compact\n")
        let config = ActionConfig(from: action)

        #expect(config.type == "typeText")
        #expect(config.text == "/compact\n")
        #expect(config.key == nil)

        let back = config.toMappedAction()
        #expect(back == action)
    }

    @Test func keystrokeWithNoModifiers() {
        let config = ActionConfig(type: "keystroke", key: "return", modifiers: nil, text: nil)
        let action = config.toMappedAction()
        #expect(action == .keystroke(key: "return", modifiers: []))
    }

    @Test func keystrokeWithUnknownKeyReturnsNil() {
        let config = ActionConfig(type: "keystroke", key: "banana", modifiers: [], text: nil)
        #expect(config.toMappedAction() == nil)
    }

    @Test func keystrokeWithNilKeyReturnsNil() {
        let config = ActionConfig(type: "keystroke", key: nil, modifiers: [], text: nil)
        #expect(config.toMappedAction() == nil)
    }

    @Test func typeTextWithMissingTextReturnsNil() {
        let config = ActionConfig(type: "typeText", key: nil, modifiers: nil, text: nil)
        #expect(config.toMappedAction() == nil)
    }

    @Test func unknownActionTypeReturnsNil() {
        let config = ActionConfig(type: "explode", key: nil, modifiers: nil, text: nil)
        #expect(config.toMappedAction() == nil)
    }
}

// MARK: - Dictionary → [GamepadButton: MappedAction]

struct ButtonMappingConversionTests {

    @Test func validButtonsConvert() {
        let dict: [String: ActionConfig] = [
            "buttonA": ActionConfig(type: "keystroke", key: "return", modifiers: [], text: nil),
            "buttonX": ActionConfig(type: "typeText", key: nil, modifiers: nil, text: "hello"),
        ]
        let mappings = dict.toButtonMappings()

        #expect(mappings.count == 2)
        #expect(mappings[.buttonA] == .keystroke(key: "return", modifiers: []))
        #expect(mappings[.buttonX] == .typeText("hello"))
    }

    @Test func unknownButtonNameIsSkipped() {
        let dict: [String: ActionConfig] = [
            "buttonA": ActionConfig(type: "keystroke", key: "return", modifiers: [], text: nil),
            "turboButton": ActionConfig(type: "keystroke", key: "a", modifiers: [], text: nil),
        ]
        let mappings = dict.toButtonMappings()

        #expect(mappings.count == 1)
        #expect(mappings[.buttonA] != nil)
    }

    @Test func invalidActionIsSkipped() {
        let dict: [String: ActionConfig] = [
            "buttonA": ActionConfig(type: "keystroke", key: "return", modifiers: [], text: nil),
            "buttonB": ActionConfig(type: "keystroke", key: "notAKey", modifiers: [], text: nil),
        ]
        let mappings = dict.toButtonMappings()

        #expect(mappings.count == 1)
        #expect(mappings[.buttonA] != nil)
        #expect(mappings[.buttonB] == nil)
    }

    @Test func emptyDictProducesEmptyMappings() {
        let dict: [String: ActionConfig] = [:]
        #expect(dict.toButtonMappings().isEmpty)
    }
}

// MARK: - VibePadConfig JSON round-trip

struct ConfigJSONTests {

    @Test func encodeDecodeRoundTrip() throws {
        let config = VibePadConfig(
            version: 1,
            profile: "test",
            mappings: [
                "buttonA": ActionConfig(type: "keystroke", key: "return", modifiers: [], text: nil),
                "buttonX": ActionConfig(type: "typeText", key: nil, modifiers: nil, text: "y\n"),
            ],
            l1Mappings: [
                "buttonB": ActionConfig(type: "keystroke", key: "z", modifiers: ["command"], text: nil),
            ],
            stickConfig: StickConfig(
                leftStickDeadzone: 0.25,
                rightStickDeadzone: 0.15,
                arrowPressThreshold: 0.6,
                arrowReleaseThreshold: 0.2,
                scrollSensitivity: 8.0
            )
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(config)
        let decoded = try JSONDecoder().decode(VibePadConfig.self, from: data)

        #expect(decoded.version == 1)
        #expect(decoded.profile == "test")
        #expect(decoded.mappings.count == 2)
        #expect(decoded.l1Mappings?.count == 1)
        #expect(decoded.stickConfig?.leftStickDeadzone == 0.25)
        #expect(decoded.stickConfig?.scrollSensitivity == 8.0)
    }

    @Test func decodesWithOptionalFieldsMissing() throws {
        let json = """
        {"version":1,"profile":"minimal","mappings":{}}
        """
        let config = try JSONDecoder().decode(VibePadConfig.self, from: Data(json.utf8))

        #expect(config.version == 1)
        #expect(config.profile == "minimal")
        #expect(config.mappings.isEmpty)
        #expect(config.l1Mappings == nil)
        #expect(config.stickConfig == nil)
    }

    @Test func decodesFullJSONFromSpec() throws {
        let json = """
        {
          "version": 1,
          "profile": "claude-code",
          "mappings": {
            "buttonA": { "type": "typeText", "text": "y\\n" },
            "buttonX": { "type": "keystroke", "key": "c", "modifiers": ["control"] }
          },
          "l1Mappings": {
            "buttonA": { "type": "typeText", "text": "/compact\\n" },
            "buttonB": { "type": "keystroke", "key": "z", "modifiers": ["command"] }
          },
          "stickConfig": {
            "leftStickDeadzone": 0.3,
            "rightStickDeadzone": 0.2,
            "arrowPressThreshold": 0.5,
            "arrowReleaseThreshold": 0.3,
            "scrollSensitivity": 5.0
          }
        }
        """
        let config = try JSONDecoder().decode(VibePadConfig.self, from: Data(json.utf8))

        #expect(config.mappings.count == 2)
        #expect(config.l1Mappings?.count == 2)

        // Verify the full conversion pipeline works
        let mappings = config.mappings.toButtonMappings()
        #expect(mappings[.buttonA] == .typeText("y\n"))
        #expect(mappings[.buttonX] == .keystroke(key: "c", modifiers: ["control"]))

        let l1 = config.l1Mappings!.toButtonMappings()
        #expect(l1[.buttonA] == .typeText("/compact\n"))
        #expect(l1[.buttonB] == .keystroke(key: "z", modifiers: ["command"]))
    }
}

// MARK: - defaultConfig

struct DefaultConfigTests {

    @Test func defaultConfigCoversAllDefaultMappings() {
        let config = VibePadConfig.defaultConfig()

        #expect(config.version == 1)
        #expect(config.profile == "claude-code")

        // Every button in InputMapper.defaultMappings should appear
        for button in InputMapper.defaultMappings.keys {
            #expect(config.mappings[button.rawValue] != nil, "Missing default mapping for \(button.rawValue)")
        }

        // Every button in InputMapper.l1Mappings should appear
        for button in InputMapper.l1Mappings.keys {
            #expect(config.l1Mappings?[button.rawValue] != nil, "Missing L1 mapping for \(button.rawValue)")
        }
    }

    @Test func defaultConfigRoundTripsBackToSameMappings() {
        let config = VibePadConfig.defaultConfig()
        let mappings = config.mappings.toButtonMappings()

        // Should produce the same mappings as the hardcoded defaults
        for (button, action) in InputMapper.defaultMappings {
            #expect(mappings[button] == action, "Mismatch for \(button.rawValue)")
        }
        #expect(mappings.count == InputMapper.defaultMappings.count)
    }

    @Test func defaultConfigHasStickValues() {
        let config = VibePadConfig.defaultConfig()
        let stick = config.stickConfig

        #expect(stick?.leftStickDeadzone == 0.3)
        #expect(stick?.rightStickDeadzone == 0.2)
        #expect(stick?.arrowPressThreshold == 0.5)
        #expect(stick?.arrowReleaseThreshold == 0.3)
        #expect(stick?.scrollSensitivity == 15.0)
    }

    @Test func defaultConfigSerializesToValidJSON() throws {
        let config = VibePadConfig.defaultConfig()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        let decoded = try JSONDecoder().decode(VibePadConfig.self, from: data)

        #expect(decoded.mappings.count == config.mappings.count)
        #expect(decoded.l1Mappings?.count == config.l1Mappings?.count)
    }
}

// MARK: - Config file I/O (uses temp directory)

struct ConfigFileIOTests {

    @Test func writeAndLoadRoundTrip() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("vibepad-test-\(UUID().uuidString)")
        let configFile = tmpDir.appendingPathComponent("config.json")
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let config = VibePadConfig.defaultConfig()

        // Write
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: configFile, options: .atomic)

        // Read back
        let loaded = try JSONDecoder().decode(VibePadConfig.self, from: Data(contentsOf: configFile))
        #expect(loaded.version == config.version)
        #expect(loaded.profile == config.profile)
        #expect(loaded.mappings.count == config.mappings.count)
    }
}
