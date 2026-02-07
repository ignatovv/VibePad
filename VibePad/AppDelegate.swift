//
//  AppDelegate.swift
//  VibePad
//
//  Created by Vova Ignatov on 2/6/26.
//

import Cocoa
import GameController
import Observation

@Observable
final class AppDelegate: NSObject, NSApplicationDelegate {

    var isEnabled = true
    var isHUDEnabled = true
    var controllerName: String?
    var isAccessibilityGranted = false

    private var gamepadManager: GamepadManager?
    private var inputMapper: InputMapper?
    private var hud: OverlayHUD?
    private var statusTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        isAccessibilityGranted = AccessibilityHelper.checkAndPrompt()
        print("[VibePad] Accessibility granted: \(isAccessibilityGranted)")

        let (config, existed) = VibePadConfig.load()
        if !existed {
            VibePadConfig.writeDefaults(config)
        }

        let emitter = KeyboardEmitter()
        let mapper = InputMapper(emitter: emitter, config: config)
        let stickConfig = config.stickConfig
        let manager = GamepadManager(
            leftStickDeadzone: stickConfig?.leftStickDeadzone ?? 0.3,
            rightStickDeadzone: stickConfig?.rightStickDeadzone ?? 0.2
        )

        let hud = OverlayHUD()
        self.hud = hud

        mapper.onAction = { [weak self] _, action, description in
            guard let self, self.isHUDEnabled else { return }
            hud.show(action: action, description: description)
        }

        manager.onButtonPressed = { [weak self] button, pressed in
            guard let self, self.isEnabled else {
                print("[VibePad] Button ignored: isEnabled=\(self?.isEnabled ?? false)")
                return
            }
            print("[VibePad] Dispatching button: \(button.rawValue) pressed=\(pressed)")
            mapper.handleButton(button, pressed: pressed)
        }

        manager.onLeftStick = { [weak self] x, y in
            guard let self, self.isEnabled else { return }
            mapper.handleLeftStick(x: x, y: y)
        }

        manager.onRightStick = { [weak self] x, y in
            guard let self, self.isEnabled else { return }
            mapper.handleRightStick(x: x, y: y)
        }

        manager.startMonitoring()

        self.inputMapper = mapper
        self.gamepadManager = manager

        // Poll controller status + accessibility for UI updates
        statusTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.controllerName = self.gamepadManager?.connectedControllerName
            self.isAccessibilityGranted = AccessibilityHelper.isTrusted
        }
    }
}
