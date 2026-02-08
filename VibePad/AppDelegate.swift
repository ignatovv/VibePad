//
//  AppDelegate.swift
//  VibePad
//
//  Created by Vova Ignatov on 2/6/26.
//

import Cocoa
import GameController
import Observation
import ServiceManagement

@Observable
final class AppDelegate: NSObject, NSApplicationDelegate {

    var isEnabled = true
    var isHUDEnabled = true
    var controllerName: String?
    var isAccessibilityGranted = false

    var menuBarIcon: String {
        if !isAccessibilityGranted {
            return "menubar-alert"
        } else if controllerName == nil {
            return "menubar-disconnected"
        } else if !isEnabled {
            return "menubar-sleeping"
        } else {
            return "menubar-active"
        }
    }

    var launchAtLogin = false
    private(set) var launchAtLoginOnStartup = false

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            print("[VibePad] Launch at Login error: \(error)")
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    var voiceHotkeyLabel: String?

    private var gamepadManager: GamepadManager?
    private var inputMapper: InputMapper?
    private var hud: OverlayHUD?
    private var voiceShortcutPicker: VoiceShortcutPicker?
    private var statusTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        isAccessibilityGranted = AccessibilityHelper.checkAndPrompt()
        launchAtLogin = SMAppService.mainApp.status == .enabled
        launchAtLoginOnStartup = launchAtLogin
        print("[VibePad] Accessibility granted: \(isAccessibilityGranted)")

        let config = VibePadConfig.load()
        let emitter = KeyboardEmitter()

        // Detect voice app only on first launch (no config yet)
        let detectedVoiceApp = config == nil ? VoiceAppDetector.detect() : nil

        let mapper: InputMapper
        if let config {
            mapper = InputMapper(emitter: emitter, config: config)
        } else if let voiceApp = detectedVoiceApp {
            mapper = InputMapper(emitter: emitter, voiceOverride: voiceApp.action)
        } else {
            mapper = InputMapper(emitter: emitter)
        }
        let stickConfig = config?.stickConfig
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

        // Populate voice status
        if let config {
            // Existing config — read label from persisted L2 mapping
            if let l2Config = config.mappings[GamepadButton.leftTrigger.rawValue],
               let action = l2Config.toMappedAction() {
                voiceHotkeyLabel = OverlayHUD.label(for: action)
            }
        } else {
            // First launch — show picker after 1s delay
            let prefillAction = detectedVoiceApp?.action ?? .keystroke(key: "space", modifiers: ["option"])
            let detectedName = detectedVoiceApp?.name
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self else { return }
                let picker = VoiceShortcutPicker()
                self.voiceShortcutPicker = picker
                picker.show(prefilled: prefillAction) { [weak self] result in
                    guard let self else { return }
                    let (action, label) = result ?? (prefillAction, OverlayHUD.label(for: prefillAction))
                    self.voiceHotkeyLabel = label
                    if let detectedName {
                        VibePadConfig.writeCurrentDefaults(voiceOverride: action, voiceAppName: detectedName)
                    } else {
                        VibePadConfig.writeCurrentDefaults(voiceOverride: action)
                    }
                    if result != nil {
                        self.hud?.show(action: action, description: "Voice Input", duration: 2.0)
                    }
                }
            }
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
            self.launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    func showVoiceShortcutPicker() {
        // Pre-fill with current L2 action from config, or default
        let config = VibePadConfig.load()
        let currentAction: MappedAction
        if let l2Config = config?.mappings[GamepadButton.leftTrigger.rawValue],
           let action = l2Config.toMappedAction() {
            currentAction = action
        } else {
            currentAction = .keystroke(key: "space", modifiers: ["option"])
        }

        let picker = VoiceShortcutPicker()
        self.voiceShortcutPicker = picker
        picker.show(prefilled: currentAction) { [weak self] result in
            guard let self, let (action, label) = result else { return }
            self.voiceHotkeyLabel = label
            VibePadConfig.writeCurrentDefaults(voiceOverride: action)
            self.hud?.show(action: action, description: "Restart to apply", duration: 2.0)
        }
    }
}
