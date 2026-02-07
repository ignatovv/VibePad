//
//  GamepadManager.swift
//  VibePad
//

import GameController

enum GamepadButton: String, CaseIterable {
    case buttonA, buttonB, buttonX, buttonY
    case dpadUp, dpadDown, dpadLeft, dpadRight
    case leftShoulder, rightShoulder
    case leftTrigger, rightTrigger
    case leftThumbstickButton, rightThumbstickButton
    case buttonMenu, buttonOptions
}

final class GamepadManager {

    // MARK: - Callbacks

    var onButtonPressed: ((GamepadButton, Bool) -> Void)?
    var onLeftStick: ((Float, Float) -> Void)?
    var onRightStick: ((Float, Float) -> Void)?

    // MARK: - State

    private(set) var connectedControllerName: String?
    private var controller: GCController?
    private var pollTimer: Timer?

    // Trigger hysteresis state
    private var leftTriggerPressed = false
    private var rightTriggerPressed = false

    // Deadzone constants
    private let leftStickDeadzone: Float = 0.3
    private let rightStickDeadzone: Float = 0.2

    // Trigger hysteresis thresholds
    private let triggerPressThreshold: Float = 0.5
    private let triggerReleaseThreshold: Float = 0.3

    // MARK: - Start / Stop

    func startMonitoring() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerDidConnect),
            name: .GCControllerDidConnect,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerDidDisconnect),
            name: .GCControllerDidDisconnect,
            object: nil
        )

        // Pick up any already-connected controller
        if let existing = GCController.controllers().first {
            setupController(existing)
        }
    }

    func stopMonitoring() {
        NotificationCenter.default.removeObserver(self)
        pollTimer?.invalidate()
        pollTimer = nil
        controller = nil
        connectedControllerName = nil
    }

    // MARK: - Connection handling

    @objc private func controllerDidConnect(_ notification: Notification) {
        guard let gc = notification.object as? GCController else { return }
        if controller == nil {
            setupController(gc)
        }
    }

    @objc private func controllerDidDisconnect(_ notification: Notification) {
        guard let gc = notification.object as? GCController, gc === controller else { return }
        pollTimer?.invalidate()
        pollTimer = nil
        controller = nil
        connectedControllerName = nil
    }

    // MARK: - Controller setup

    private func setupController(_ gc: GCController) {
        GCController.shouldMonitorBackgroundEvents = true
        controller = gc
        connectedControllerName = gc.vendorName
        print("[VibePad] Controller setup: \(gc.vendorName ?? "unknown"), hasExtendedGamepad: \(gc.extendedGamepad != nil)")
        registerButtonHandlers(gc)
        startPolling()
    }

    private func registerButtonHandlers(_ gc: GCController) {
        guard let gp = gc.extendedGamepad else { return }

        gp.valueChangedHandler = { [weak self] gamepad, element in
            guard let self else { return }

            let button: GamepadButton?
            switch element {
            case gamepad.buttonA:               button = .buttonA
            case gamepad.buttonB:               button = .buttonB
            case gamepad.buttonX:               button = .buttonX
            case gamepad.buttonY:               button = .buttonY
            case gamepad.leftShoulder:          button = .leftShoulder
            case gamepad.rightShoulder:         button = .rightShoulder
            case gamepad.leftThumbstickButton:  button = .leftThumbstickButton
            case gamepad.rightThumbstickButton: button = .rightThumbstickButton
            case gamepad.buttonMenu:            button = .buttonMenu
            case gamepad.buttonOptions:         button = .buttonOptions
            default:                            button = nil
            }

            if let button, let input = element as? GCControllerButtonInput {
                let pressed = input.isPressed
                print("[VibePad] Button: \(button.rawValue) pressed=\(pressed)")
                DispatchQueue.main.async {
                    self.onButtonPressed?(button, pressed)
                }
            }
        }

        // D-pad: register individual handlers since some controllers (e.g. DualSense)
        // report the dpad as a single GCControllerDirectionPad element
        let dpadMappings: [(GCControllerButtonInput, GamepadButton)] = [
            (gp.dpad.up, .dpadUp),
            (gp.dpad.down, .dpadDown),
            (gp.dpad.left, .dpadLeft),
            (gp.dpad.right, .dpadRight),
        ]
        for (input, button) in dpadMappings {
            input.pressedChangedHandler = { [weak self] _, _, pressed in
                print("[VibePad] Button: \(button.rawValue) pressed=\(pressed)")
                DispatchQueue.main.async {
                    self?.onButtonPressed?(button, pressed)
                }
            }
        }
    }

    // MARK: - Polling (sticks + triggers at 60Hz)

    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.pollSticks()
        }
    }

    private func pollSticks() {
        guard let gp = controller?.extendedGamepad else { return }

        // Left stick
        let lx = gp.leftThumbstick.xAxis.value
        let ly = gp.leftThumbstick.yAxis.value
        let leftApplied = applyRadialDeadzone(x: lx, y: ly, deadzone: leftStickDeadzone)
        onLeftStick?(leftApplied.x, leftApplied.y)

        // Right stick
        let rx = gp.rightThumbstick.xAxis.value
        let ry = gp.rightThumbstick.yAxis.value
        let rightApplied = applyRadialDeadzone(x: rx, y: ry, deadzone: rightStickDeadzone)
        onRightStick?(rightApplied.x, rightApplied.y)

        // Triggers (analog → digital with hysteresis)
        let ltValue = gp.leftTrigger.value
        if !leftTriggerPressed && ltValue > triggerPressThreshold {
            leftTriggerPressed = true
            onButtonPressed?(.leftTrigger, true)
        } else if leftTriggerPressed && ltValue < triggerReleaseThreshold {
            leftTriggerPressed = false
            onButtonPressed?(.leftTrigger, false)
        }

        let rtValue = gp.rightTrigger.value
        if !rightTriggerPressed && rtValue > triggerPressThreshold {
            rightTriggerPressed = true
            onButtonPressed?(.rightTrigger, true)
        } else if rightTriggerPressed && rtValue < triggerReleaseThreshold {
            rightTriggerPressed = false
            onButtonPressed?(.rightTrigger, false)
        }
    }

    // MARK: - Deadzone

    private func applyRadialDeadzone(x: Float, y: Float, deadzone: Float) -> (x: Float, y: Float) {
        let magnitude = sqrt(x * x + y * y)
        guard magnitude > deadzone else { return (0, 0) }
        let scale = (magnitude - deadzone) / (1.0 - deadzone)
        let normalized = scale / magnitude
        return (x * normalized, y * normalized)
    }
}
