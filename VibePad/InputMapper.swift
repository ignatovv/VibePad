//
//  InputMapper.swift
//  VibePad
//

import CoreGraphics

enum MappedAction: Equatable {
    case keystroke(key: String, modifiers: [String])
    case typeText(String)
}

final class InputMapper {

    private let emitter: KeyboardEmitter
    private var isL1Held = false

    var onAction: ((GamepadButton?, MappedAction, String?) -> Void)?

    // MARK: - Default mappings (Claude Code / terminal)

    static let defaultMappings: [GamepadButton: MappedAction] = [
        .buttonA:              .keystroke(key: "return", modifiers: []),                // ✕ Accept/confirm (Enter)
        .buttonB:              .keystroke(key: "escape", modifiers: []),               // ○ Cancel/back (Escape)
        .buttonX:              .keystroke(key: "c", modifiers: ["control"]),           // □ Ctrl+C interrupt
        .buttonY:              .keystroke(key: "v", modifiers: ["command"]),           // △ ⌘V paste
        .dpadUp:               .keystroke(key: "upArrow", modifiers: []),              // Command history
        .dpadDown:             .keystroke(key: "downArrow", modifiers: []),            // Command history
        .dpadLeft:             .keystroke(key: "leftBracket", modifiers: ["command", "shift"]),  // Prev tab
        .dpadRight:            .keystroke(key: "rightBracket", modifiers: ["command", "shift"]), // Next tab
        .rightShoulder:        .keystroke(key: "tab", modifiers: ["shift"]),             // R1 Shift+Tab mode switch
        .leftTrigger:          .keystroke(key: "space", modifiers: ["option"]),        // Voice (future)
        .rightTrigger:         .keystroke(key: "return", modifiers: []),               // Submit / Enter
        // L3 (.leftThumbstickButton) — unassigned
        // R3 (.rightThumbstickButton) — unassigned
        .buttonMenu:           .typeText("/"),                                           // Slash command prefix
        // Options (.buttonOptions) — unassigned, reserved for future use
    ]

    // MARK: - L1 layer mappings

    static let l1Mappings: [GamepadButton: MappedAction] = [
        .buttonB:              .keystroke(key: "delete", modifiers: []),                  // L1+○ Delete
    ]

    static let l1Descriptions: [GamepadButton: String] = [
        .buttonB:       "Delete",
    ]

    // MARK: - Default descriptions

    static let defaultDescriptions: [GamepadButton: String] = [
        .buttonA:       "Accept",
        .buttonB:       "Cancel",
        .buttonX:       "Interrupt",
        .buttonY:       "Paste",
        .dpadUp:        "History Up",
        .dpadDown:      "History Down",
        .dpadLeft:      "Prev Tab",
        .dpadRight:     "Next Tab",
        .rightShoulder: "Switch Mode",
        .leftTrigger:   "Voice Input",
        .rightTrigger:  "Submit",
        .buttonMenu:    "Slash Command",
    ]

    // MARK: - Active mappings (from config or defaults)

    private let activeMappings: [GamepadButton: MappedAction]
    private let activeL1Mappings: [GamepadButton: MappedAction]
    private let activeDescriptions: [GamepadButton: String]
    private let activeL1Descriptions: [GamepadButton: String]

    // MARK: - Arrow key hold state (left stick)

    private var arrowUpHeld = false
    private var arrowDownHeld = false
    private var arrowLeftHeld = false
    private var arrowRightHeld = false

    // Arrow key repeat timing (CFAbsoluteTime)
    private var arrowUpLastFire: CFAbsoluteTime = 0
    private var arrowDownLastFire: CFAbsoluteTime = 0
    private var arrowLeftLastFire: CFAbsoluteTime = 0
    private var arrowRightLastFire: CFAbsoluteTime = 0

    private let arrowRepeatDelay: CFAbsoluteTime = 0.15   // initial delay before repeat
    private let arrowRepeatInterval: CFAbsoluteTime = 0.02 // ~50 repeats/sec

    // Hysteresis thresholds for stick → arrow
    private let arrowPressThreshold: Float
    private let arrowReleaseThreshold: Float

    // Scroll sensitivity
    private let scrollSensitivity: Float

    // MARK: - Init

    init(emitter: KeyboardEmitter) {
        self.emitter = emitter
        self.activeMappings = Self.defaultMappings
        self.activeL1Mappings = Self.l1Mappings
        self.activeDescriptions = Self.defaultDescriptions
        self.activeL1Descriptions = Self.l1Descriptions
        self.arrowPressThreshold = 0.5
        self.arrowReleaseThreshold = 0.3
        self.scrollSensitivity = 15.0
    }

    init(emitter: KeyboardEmitter, config: VibePadConfig) {
        self.emitter = emitter
        self.activeMappings = Self.defaultMappings.merging(config.mappings.toButtonMappings()) { _, new in new }
        self.activeL1Mappings = Self.l1Mappings.merging(config.l1Mappings?.toButtonMappings() ?? [:]) { _, new in new }
        self.activeDescriptions = Self.defaultDescriptions.merging(config.mappings.toButtonDescriptions()) { _, new in new }
        self.activeL1Descriptions = Self.l1Descriptions.merging(config.l1Mappings?.toButtonDescriptions() ?? [:]) { _, new in new }
        let stick = config.stickConfig
        self.arrowPressThreshold = stick?.arrowPressThreshold ?? 0.5
        self.arrowReleaseThreshold = stick?.arrowReleaseThreshold ?? 0.3
        self.scrollSensitivity = stick?.scrollSensitivity ?? 15.0
    }

    // MARK: - Button handling

    func handleButton(_ button: GamepadButton, pressed: Bool) {
        if button == .leftShoulder {
            isL1Held = pressed
            return
        }
        guard pressed else { return }

        let action = isL1Held
            ? activeL1Mappings[button] ?? activeMappings[button]
            : activeMappings[button]

        guard let action else { return }
        let description = isL1Held ? (activeL1Descriptions[button] ?? activeDescriptions[button]) : activeDescriptions[button]
        onAction?(button, action, description)
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
            axis: y, held: &arrowUpHeld, lastFire: &arrowUpLastFire,
            keyCode: KeyboardEmitter.keyCodeMap["upArrow"]!,
            positive: true,
            action: .keystroke(key: "upArrow", modifiers: []), description: "Move Up"
        )
        updateArrow(
            axis: y, held: &arrowDownHeld, lastFire: &arrowDownLastFire,
            keyCode: KeyboardEmitter.keyCodeMap["downArrow"]!,
            positive: false,
            action: .keystroke(key: "downArrow", modifiers: []), description: "Move Down"
        )
        updateArrow(
            axis: x, held: &arrowRightHeld, lastFire: &arrowRightLastFire,
            keyCode: KeyboardEmitter.keyCodeMap["rightArrow"]!,
            positive: true,
            action: .keystroke(key: "rightArrow", modifiers: []), description: "Move Right"
        )
        updateArrow(
            axis: x, held: &arrowLeftHeld, lastFire: &arrowLeftLastFire,
            keyCode: KeyboardEmitter.keyCodeMap["leftArrow"]!,
            positive: false,
            action: .keystroke(key: "leftArrow", modifiers: []), description: "Move Left"
        )
    }

    private func updateArrow(axis: Float, held: inout Bool, lastFire: inout CFAbsoluteTime,
                             keyCode: CGKeyCode, positive: Bool,
                             action: MappedAction, description: String) {
        let value = positive ? axis : -axis
        let now = CFAbsoluteTimeGetCurrent()

        if !held && value > arrowPressThreshold {
            held = true
            onAction?(nil, action, description)
            emitter.postKeystroke(keyCode: keyCode)
            lastFire = now
        } else if held && value >= arrowReleaseThreshold {
            // Still held — repeat after initial delay, then at repeat interval
            let elapsed = now - lastFire
            let threshold = (elapsed < arrowRepeatDelay + arrowRepeatInterval) ? arrowRepeatDelay : arrowRepeatInterval
            if now - lastFire >= threshold {
                emitter.postKeystroke(keyCode: keyCode)
                lastFire = now
            }
        } else if held && value < arrowReleaseThreshold {
            held = false
        }
    }

    // MARK: - Right stick → scroll

    func handleRightStick(x: Float, y: Float) {
        let dx = Int32(x * scrollSensitivity)
        let dy = Int32(y * scrollSensitivity)
        if dx != 0 || dy != 0 {
            emitter.postScroll(deltaX: dx, deltaY: dy)
        }
    }
}
