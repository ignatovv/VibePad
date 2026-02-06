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
    var controllerName: String?
    var isAccessibilityGranted = false

    private var gamepadManager: GamepadManager?
    private var inputMapper: InputMapper?
    private var statusTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        isAccessibilityGranted = AccessibilityHelper.checkAndPrompt()
        print("[VibePad] Accessibility granted: \(isAccessibilityGranted)")

        let emitter = KeyboardEmitter()
        let mapper = InputMapper(emitter: emitter)
        let manager = GamepadManager()

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
