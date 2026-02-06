//
//  InputMapper.swift
//  VibePad
//

import CoreGraphics

struct KeyMapping {
    let key: String
    let modifiers: [String]
}

final class InputMapper {

    private let emitter: KeyboardEmitter

    // MARK: - Default mappings (from spec)

    static let defaultMappings: [GamepadButton: KeyMapping] = [
        .buttonA:              KeyMapping(key: "return", modifiers: []),
        .buttonB:              KeyMapping(key: "escape", modifiers: []),
        .buttonY:              KeyMapping(key: "l", modifiers: ["command"]),
        .buttonX:              KeyMapping(key: "s", modifiers: ["command"]),
        .dpadUp:               KeyMapping(key: "upArrow", modifiers: []),
        .dpadDown:             KeyMapping(key: "downArrow", modifiers: []),
        .dpadLeft:             KeyMapping(key: "leftBracket", modifiers: ["command", "shift"]),
        .dpadRight:            KeyMapping(key: "rightBracket", modifiers: ["command", "shift"]),
        .leftShoulder:         KeyMapping(key: "grave", modifiers: ["command"]),
        .rightShoulder:        KeyMapping(key: "p", modifiers: ["command", "shift"]),
        .leftTrigger:          KeyMapping(key: "space", modifiers: ["option"]),
        .rightTrigger:         KeyMapping(key: "return", modifiers: ["command"]),
        .leftThumbstickButton: KeyMapping(key: "b", modifiers: ["command"]),
        .rightThumbstickButton: KeyMapping(key: "grave", modifiers: ["control"]),
        .buttonMenu:           KeyMapping(key: "g", modifiers: ["command", "shift"]),
        .buttonOptions:        KeyMapping(key: "period", modifiers: ["command"]),
    ]

    // MARK: - Arrow key hold state (left stick)

    private var arrowUpHeld = false
    private var arrowDownHeld = false
    private var arrowLeftHeld = false
    private var arrowRightHeld = false

    // Hysteresis thresholds for stick → arrow
    private let arrowPressThreshold: Float = 0.5
    private let arrowReleaseThreshold: Float = 0.3

    // Scroll sensitivity
    private let scrollSensitivity: Float = 5.0

    // MARK: - Init

    init(emitter: KeyboardEmitter) {
        self.emitter = emitter
    }

    // MARK: - Button handling

    func handleButton(_ button: GamepadButton, pressed: Bool) {
        guard pressed else { return }
        guard let mapping = Self.defaultMappings[button] else { return }
        emitter.postKeystroke(key: mapping.key, modifiers: mapping.modifiers)
    }

    // MARK: - Left stick → arrow keys

    func handleLeftStick(x: Float, y: Float) {
        updateArrow(
            axis: y, held: &arrowUpHeld,
            keyCode: KeyboardEmitter.keyCodeMap["upArrow"]!,
            positive: true
        )
        updateArrow(
            axis: y, held: &arrowDownHeld,
            keyCode: KeyboardEmitter.keyCodeMap["downArrow"]!,
            positive: false
        )
        updateArrow(
            axis: x, held: &arrowRightHeld,
            keyCode: KeyboardEmitter.keyCodeMap["rightArrow"]!,
            positive: true
        )
        updateArrow(
            axis: x, held: &arrowLeftHeld,
            keyCode: KeyboardEmitter.keyCodeMap["leftArrow"]!,
            positive: false
        )
    }

    private func updateArrow(axis: Float, held: inout Bool, keyCode: CGKeyCode, positive: Bool) {
        let value = positive ? axis : -axis
        if !held && value > arrowPressThreshold {
            held = true
            emitter.postKeyDown(keyCode: keyCode)
        } else if held && value < arrowReleaseThreshold {
            held = false
            emitter.postKeyUp(keyCode: keyCode)
        }
    }

    // MARK: - Right stick → scroll

    func handleRightStick(x: Float, y: Float) {
        let dx = Int32(x * scrollSensitivity)
        let dy = Int32(-y * scrollSensitivity)   // inverted: stick up = scroll up (negative pixel delta)
        if dx != 0 || dy != 0 {
            emitter.postScroll(deltaX: dx, deltaY: dy)
        }
    }
}
