//
//  InputMapper.swift
//  VibePad
//

import AppKit
import CoreGraphics
import Foundation

enum MappedAction: Equatable {
    case keystroke(key: String, modifiers: [String])
    case stickyKeystroke(key: String, modifiers: [String], stickyModifiers: [String])
    case typeText(String)
    case smartPaste
}

enum TriggerMode: String, Codable, Sendable {
    case onPress
    case onRelease
    case onPressAndRelease
}

final class InputMapper {

    private let emitter: KeyboardEmitter
    private var isL1Held = false

    var onAction: ((GamepadButton?, MappedAction, String?) -> Void)?

    // MARK: - Button repeat constants

    private static let buttonRepeatDelay: CFAbsoluteTime = 0.15
    private static let buttonRepeatInterval: CFAbsoluteTime = 0.02

    // MARK: - Default mappings (Claude Code / terminal)

    static let defaultMappings: [GamepadButton: MappedAction] = [
        .buttonA:              .keystroke(key: "return", modifiers: []),                // ✕ Accept/confirm (Enter)
        .buttonB:              .keystroke(key: "escape", modifiers: []),               // ○ Cancel/back (Escape)
        .buttonX:              .keystroke(key: "c", modifiers: ["control"]),           // □ Ctrl+C interrupt
        .buttonY:              .smartPaste,                                            // △ Smart paste (Ctrl+V for images, ⌘V for text)
        .dpadUp:               .keystroke(key: "upArrow", modifiers: []),              // Command history
        .dpadDown:             .keystroke(key: "downArrow", modifiers: []),            // Command history
        .dpadLeft:             .keystroke(key: "leftBracket", modifiers: ["command", "shift"]),  // Prev tab
        .dpadRight:            .keystroke(key: "rightBracket", modifiers: ["command", "shift"]), // Next tab
        .rightShoulder:        .keystroke(key: "tab", modifiers: ["shift"]),             // R1 Shift+Tab mode switch
        .leftTrigger:          .keystroke(key: "space", modifiers: ["option"]),        // Voice (future)
        .rightTrigger:         .keystroke(key: "return", modifiers: []),               // Submit / Enter
        // L3 (.leftThumbstickButton) — unassigned
        .rightThumbstickButton:.keystroke(key: "tab", modifiers: []),                  // R3 Tab (complete)
        .buttonMenu:           .typeText("/"),                                           // Slash command prefix
        // Options (.buttonOptions) — unassigned
    ]

    // MARK: - L1 layer mappings

    static let l1Mappings: [GamepadButton: MappedAction] = [
        .buttonY:              .keystroke(key: "c", modifiers: ["command"]),               // L1+△ ⌘C Copy
        .buttonB:              .keystroke(key: "delete", modifiers: []),                  // L1+○ Delete
        .dpadLeft:             .stickyKeystroke(key: "tab", modifiers: ["shift"], stickyModifiers: ["command"]),  // L1+← Prev app
        .dpadRight:            .stickyKeystroke(key: "tab", modifiers: [], stickyModifiers: ["command"]),               // L1+→ Next app
    ]

    static let l1Descriptions: [GamepadButton: String] = [
        .buttonY:       "Copy",
        .buttonB:       "Delete",
        .dpadLeft:      "Prev App",
        .dpadRight:     "Next App",
    ]

    // MARK: - Default repeat configs

    static let defaultRepeatConfigs: [GamepadButton: (delay: CFAbsoluteTime, interval: CFAbsoluteTime)] = [
        .dpadUp:    (buttonRepeatDelay, buttonRepeatInterval),
        .dpadDown:  (buttonRepeatDelay, buttonRepeatInterval),
        .dpadLeft:  (buttonRepeatDelay, buttonRepeatInterval),
        .dpadRight: (buttonRepeatDelay, buttonRepeatInterval),
    ]

    static let l1RepeatDefaults: [GamepadButton: (delay: CFAbsoluteTime, interval: CFAbsoluteTime)] = [
        .buttonB: (buttonRepeatDelay, buttonRepeatInterval),  // L1+Circle Delete repeats
    ]

    // MARK: - Default trigger modes

    static let defaultTriggerModes: [GamepadButton: TriggerMode] = [
        .leftTrigger: .onPressAndRelease,  // Hold-to-talk for voice input
    ]

    static let l1TriggerDefaults: [GamepadButton: TriggerMode] = [:]

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
        .rightThumbstickButton: "Autocomplete",
        .buttonMenu:    "Slash Command",
    ]

    // MARK: - Active mappings (from config or defaults)

    private let activeMappings: [GamepadButton: MappedAction]
    private let activeL1Mappings: [GamepadButton: MappedAction]
    private let activeDescriptions: [GamepadButton: String]
    private let activeL1Descriptions: [GamepadButton: String]

    // MARK: - Button repeat config & state

    private let activeRepeatConfigs: [GamepadButton: (delay: CFAbsoluteTime, interval: CFAbsoluteTime)]
    private let activeL1RepeatConfigs: [GamepadButton: (delay: CFAbsoluteTime, interval: CFAbsoluteTime)]

    // MARK: - Trigger modes

    private let activeTriggerModes: [GamepadButton: TriggerMode]
    private let activeL1TriggerModes: [GamepadButton: TriggerMode]
    private var heldRepeatButtons: [GamepadButton: (lastFire: CFAbsoluteTime, isL1: Bool)] = [:]
    private var repeatTimer: Timer?
    private var heldStickyModifiers: Set<String> = []

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

    // Right stick scroll HUD state (fire once per direction)
    private var scrollUpActive = false
    private var scrollDownActive = false
    private var scrollLeftActive = false
    private var scrollRightActive = false

    // L1+right stick app switching (single-fire per deflection)
    private var l1RightStickLeftActive = false
    private var l1RightStickRightActive = false

    // MARK: - Init

    init(emitter: KeyboardEmitter) {
        self.emitter = emitter
        self.activeMappings = Self.defaultMappings
        self.activeL1Mappings = Self.l1Mappings
        self.activeDescriptions = Self.defaultDescriptions
        self.activeL1Descriptions = Self.l1Descriptions
        self.activeRepeatConfigs = Self.defaultRepeatConfigs
        self.activeL1RepeatConfigs = Self.l1RepeatDefaults
        self.activeTriggerModes = Self.defaultTriggerModes
        self.activeL1TriggerModes = Self.l1TriggerDefaults
        self.arrowPressThreshold = 0.5
        self.arrowReleaseThreshold = 0.3
        self.scrollSensitivity = 15.0
    }

    init(emitter: KeyboardEmitter, voiceOverride: MappedAction) {
        self.emitter = emitter
        var mappings = Self.defaultMappings
        mappings[.leftTrigger] = voiceOverride
        self.activeMappings = mappings
        self.activeL1Mappings = Self.l1Mappings
        self.activeDescriptions = Self.defaultDescriptions
        self.activeL1Descriptions = Self.l1Descriptions
        self.activeRepeatConfigs = Self.defaultRepeatConfigs
        self.activeL1RepeatConfigs = Self.l1RepeatDefaults
        self.activeTriggerModes = Self.defaultTriggerModes
        self.activeL1TriggerModes = Self.l1TriggerDefaults
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
        self.activeRepeatConfigs = Self.defaultRepeatConfigs.merging(config.mappings.toButtonRepeatConfigs()) { _, new in new }
        self.activeL1RepeatConfigs = Self.l1RepeatDefaults.merging(config.l1Mappings?.toButtonRepeatConfigs() ?? [:]) { _, new in new }
        self.activeTriggerModes = Self.defaultTriggerModes.merging(config.mappings.toButtonTriggerModes()) { _, new in new }
        self.activeL1TriggerModes = Self.l1TriggerDefaults.merging(config.l1Mappings?.toButtonTriggerModes() ?? [:]) { _, new in new }
        let stick = config.stickConfig
        self.arrowPressThreshold = stick?.arrowPressThreshold ?? 0.5
        self.arrowReleaseThreshold = stick?.arrowReleaseThreshold ?? 0.3
        self.scrollSensitivity = stick?.scrollSensitivity ?? 15.0
    }

    // MARK: - Button handling

    func handleButton(_ button: GamepadButton, pressed: Bool) {
        if button == .leftShoulder {
            isL1Held = pressed
            if !pressed {
                // L1 released — stop all L1-layer repeats
                for (btn, state) in heldRepeatButtons where state.isL1 {
                    heldRepeatButtons.removeValue(forKey: btn)
                }
                if heldRepeatButtons.isEmpty { stopRepeatTimer() }
                // Release any sticky modifiers (e.g. Cmd from app switching)
                releaseStickyModifiers()
            }
            return
        }

        let usingL1 = isL1Held

        // L1 held but no L1 mapping → show "coming soon" HUD on press, block fallthrough
        if usingL1 && activeL1Mappings[button] == nil {
            if pressed {
                onAction?(button, .typeText("Customizable — coming soon"), nil)
            }
            return
        }

        let action = usingL1
            ? activeL1Mappings[button]
            : activeMappings[button]

        let repeatConfig = usingL1
            ? activeL1RepeatConfigs[button]
            : activeRepeatConfigs[button]

        let triggerMode = usingL1
            ? (activeL1TriggerModes[button] ?? .onPress)
            : (activeTriggerModes[button] ?? .onPress)

        let shouldFire: Bool
        switch triggerMode {
        case .onPress:            shouldFire = pressed
        case .onRelease:          shouldFire = !pressed
        case .onPressAndRelease:  shouldFire = true
        }

        if shouldFire {
            guard let action else { return }
            // If switching from sticky to non-sticky action while L1 held, release sticky modifiers first
            if usingL1 && !heldStickyModifiers.isEmpty {
                if case .stickyKeystroke = action {
                    // Same sticky family — keep modifiers held
                } else {
                    releaseStickyModifiers()
                }
            }
            let description = usingL1 ? activeL1Descriptions[button] : activeDescriptions[button]
            onAction?(button, action, description)
            fireAction(action)
        }

        if pressed {
            if repeatConfig != nil {
                heldRepeatButtons[button] = (lastFire: CFAbsoluteTimeGetCurrent(), isL1: usingL1)
                startRepeatTimerIfNeeded()
            }
        } else {
            // Release — stop repeat for this button
            if heldRepeatButtons.removeValue(forKey: button) != nil {
                if heldRepeatButtons.isEmpty { stopRepeatTimer() }
            }
        }
    }

    private func fireAction(_ action: MappedAction) {
        switch action {
        case .keystroke(let key, let modifiers):
            emitter.postKeystroke(key: key, modifiers: modifiers)
        case .stickyKeystroke(let key, let modifiers, let stickyModifiers):
            // Hold sticky modifiers that aren't already held
            for mod in stickyModifiers where !heldStickyModifiers.contains(mod) {
                emitter.holdModifier(mod)
                heldStickyModifiers.insert(mod)
            }
            // Fire keystroke with combined modifiers (sticky + per-keystroke)
            emitter.postKeystroke(key: key, modifiers: modifiers + stickyModifiers)
        case .typeText(let text):
            emitter.typeText(text)
        case .smartPaste:
            let pb = NSPasteboard.general
            let imageTypes: [NSPasteboard.PasteboardType] = [.png, .tiff]
            let hasImage = pb.types?.contains(where: { imageTypes.contains($0) }) ?? false
            if hasImage {
                emitter.postKeystroke(key: "v", modifiers: ["control"])
            } else {
                emitter.postKeystroke(key: "v", modifiers: ["command"])
            }
        }
    }

    private func releaseStickyModifiers() {
        for mod in heldStickyModifiers {
            emitter.releaseModifier(mod)
        }
        heldStickyModifiers.removeAll()
    }

    // MARK: - Button repeat timer

    private func startRepeatTimerIfNeeded() {
        guard repeatTimer == nil else { return }
        repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] _ in
            self?.tickRepeat()
        }
    }

    private func stopRepeatTimer() {
        repeatTimer?.invalidate()
        repeatTimer = nil
    }

    private func tickRepeat() {
        let now = CFAbsoluteTimeGetCurrent()
        for (button, state) in heldRepeatButtons {
            let usingL1 = state.isL1
            let repeatCfg = usingL1
                ? activeL1RepeatConfigs[button]
                : activeRepeatConfigs[button]
            guard let repeatCfg else { continue }

            let elapsed = now - state.lastFire
            let threshold = elapsed < repeatCfg.delay + repeatCfg.interval ? repeatCfg.delay : repeatCfg.interval
            if elapsed >= threshold {
                let action = usingL1
                    ? activeL1Mappings[button]
                    : activeMappings[button]
                if let action { fireAction(action) }
                heldRepeatButtons[button] = (lastFire: now, isL1: usingL1)
            }
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

    // MARK: - Right stick → scroll (or L1+right stick → app switching)

    func handleRightStick(x: Float, y: Float) {
        if isL1Held {
            handleL1RightStick(x: x)
            return
        }

        // Reset L1+right stick state when not in L1 layer
        l1RightStickLeftActive = false
        l1RightStickRightActive = false

        let dx = Int32(x * scrollSensitivity)
        let dy = Int32(y * scrollSensitivity)

        // HUD on initial scroll — dominant axis only to avoid crosstalk
        let dominantVertical = abs(dy) >= abs(dx)

        if dominantVertical {
            if dy > 0 && !scrollUpActive {
                scrollUpActive = true
                onAction?(nil, .typeText("Scroll ↑"), nil)
            } else if dy <= 0 { scrollUpActive = false }
            if dy < 0 && !scrollDownActive {
                scrollDownActive = true
                onAction?(nil, .typeText("Scroll ↓"), nil)
            } else if dy >= 0 { scrollDownActive = false }
            scrollLeftActive = false
            scrollRightActive = false
        } else {
            if dx > 0 && !scrollRightActive {
                scrollRightActive = true
                onAction?(nil, .typeText("Scroll →"), nil)
            } else if dx <= 0 { scrollRightActive = false }
            if dx < 0 && !scrollLeftActive {
                scrollLeftActive = true
                onAction?(nil, .typeText("Scroll ←"), nil)
            } else if dx >= 0 { scrollLeftActive = false }
            scrollUpActive = false
            scrollDownActive = false
        }

        if dx != 0 || dy != 0 {
            emitter.postScroll(deltaX: dx, deltaY: dy)
        }
    }

    private func handleL1RightStick(x: Float) {
        // Right → next app (Cmd+Tab)
        if !l1RightStickRightActive && x > arrowPressThreshold {
            l1RightStickRightActive = true
            let action = MappedAction.stickyKeystroke(key: "tab", modifiers: [], stickyModifiers: ["command"])
            onAction?(nil, action, "Next App")
            fireAction(action)
        } else if l1RightStickRightActive && x < arrowReleaseThreshold {
            l1RightStickRightActive = false
        }

        // Left → prev app (Cmd+Shift+Tab)
        if !l1RightStickLeftActive && x < -arrowPressThreshold {
            l1RightStickLeftActive = true
            let action = MappedAction.stickyKeystroke(key: "tab", modifiers: ["shift"], stickyModifiers: ["command"])
            onAction?(nil, action, "Prev App")
            fireAction(action)
        } else if l1RightStickLeftActive && x > -arrowReleaseThreshold {
            l1RightStickLeftActive = false
        }
    }
}
