//
//  InputMapper.swift
//  VibePad
//

import CoreGraphics

enum MappedAction {
    case keystroke(key: String, modifiers: [String])
    case typeText(String)
}

final class InputMapper {

    private let emitter: KeyboardEmitter
    private var isL1Held = false

    // MARK: - Default mappings (Claude Code / terminal)

    static let defaultMappings: [GamepadButton: MappedAction] = [
        .buttonA:              .typeText("y\n"),                                      // Accept tool use
        .buttonB:              .typeText("n\n"),                                      // Reject tool use
        .buttonX:              .keystroke(key: "c", modifiers: ["control"]),           // Ctrl+C interrupt
        .buttonY:              .keystroke(key: "v", modifiers: ["command"]),           // ⌘V paste
        .dpadUp:               .keystroke(key: "upArrow", modifiers: []),              // Command history
        .dpadDown:             .keystroke(key: "downArrow", modifiers: []),            // Command history
        .dpadLeft:             .keystroke(key: "leftBracket", modifiers: ["command", "shift"]),  // Prev tab
        .dpadRight:            .keystroke(key: "rightBracket", modifiers: ["command", "shift"]), // Next tab
        .rightShoulder:        .keystroke(key: "tab", modifiers: []),                  // Shell autocomplete
        .leftTrigger:          .keystroke(key: "space", modifiers: ["option"]),        // Voice (future)
        .rightTrigger:         .keystroke(key: "return", modifiers: []),               // Submit / Enter
        .leftThumbstickButton: .keystroke(key: "r", modifiers: ["control"]),           // Ctrl+R reverse search
        .rightThumbstickButton: .keystroke(key: "l", modifiers: ["control"]),          // Ctrl+L clear screen
        .buttonMenu:           .typeText("/commit\n"),                                 // Ship it
        .buttonOptions:        .typeText("/help\n"),                                   // Quick reference
    ]

    // MARK: - L1 layer mappings

    static let l1Mappings: [GamepadButton: MappedAction] = [
        .buttonA: .typeText("/compact\n"),                          // Compact context
        .buttonB: .keystroke(key: "z", modifiers: ["command"]),     // Undo
        .buttonX: .keystroke(key: "d", modifiers: ["control"]),     // EOF / exit
        .buttonY: .typeText("/review\n"),                           // Review changes
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
        if button == .leftShoulder {
            isL1Held = pressed
            return
        }
        guard pressed else { return }

        let action = isL1Held
            ? Self.l1Mappings[button] ?? Self.defaultMappings[button]
            : Self.defaultMappings[button]

        guard let action else { return }
        switch action {
        case .keystroke(let key, let modifiers):
            emitter.postKeystroke(key: key, modifiers: modifiers)
        case .typeText(let text):
            emitter.typeText(text)
        }
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
