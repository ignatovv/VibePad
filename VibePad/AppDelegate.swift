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
import Sparkle

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
        if launchAtLogin {
            Analytics.send(Analytics.launchAtLoginEnabled)
        }
    }

    var voiceHotkeyLabel: String?

    private var gamepadManager: GamepadManager?
    private var inputMapper: InputMapper?
    private var hud: OverlayHUD?
    private var voiceShortcutPicker: VoiceShortcutPicker?
    private var onboardingWizard: OnboardingWizard?
    private var statusTimer: Timer?
    private var hasTrackedFirstButton = false
    private var updaterController: SPUStandardUpdaterController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

        Analytics.start()

        let config = VibePadConfig.load()

        // Only prompt for accessibility on subsequent launches; wizard handles first launch
        if config != nil {
            isAccessibilityGranted = AccessibilityHelper.checkAndPrompt()
        } else {
            isAccessibilityGranted = AccessibilityHelper.isTrusted
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
        launchAtLoginOnStartup = launchAtLogin
        print("[VibePad] Accessibility granted: \(isAccessibilityGranted)")

        Analytics.send(Analytics.appLaunched, parameters: [
            "isFirstLaunch": String(config == nil),
            "hasConfig": String(config != nil),
        ])
        Analytics.send(Analytics.sessionStarted, parameters: [
            "daysSinceInstall": String(Analytics.daysSinceInstall()),
        ])
        Analytics.send(Analytics.accessibilityGranted, parameters: [
            "granted": String(isAccessibilityGranted),
        ])
        if let hudPref = config?.hudEnabled {
            isHUDEnabled = hudPref
        }

        let emitter = KeyboardEmitter()

        // Detect voice app only on first launch (no config yet)
        let detectedVoiceApp = config == nil ? VoiceAppDetector.detect() : nil

        let mapper: InputMapper
        if let config {
            mapper = InputMapper(emitter: emitter, config: config)
        } else if let voiceApp = detectedVoiceApp {
            Analytics.send(Analytics.voiceAppDetected, parameters: ["appName": voiceApp.name])
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
            if let action = voiceAction(from: config) {
                voiceHotkeyLabel = OverlayHUD.label(for: action)
            }
        } else {
            // First launch — show onboarding wizard after 1s delay
            let prefillAction = detectedVoiceApp?.action ?? .keystroke(key: "space", modifiers: ["option"])
            let detectedName = detectedVoiceApp?.name
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self else { return }
                let wizard = OnboardingWizard()
                self.onboardingWizard = wizard
                wizard.show(prefilled: prefillAction) { [weak self] voiceAction, voiceLabel, launchAtLogin in
                    guard let self else { return }

                    // Apply voice shortcut
                    let finalAction = voiceAction ?? prefillAction
                    self.voiceHotkeyLabel = voiceLabel ?? OverlayHUD.label(for: finalAction)

                    // Apply launch at login
                    if launchAtLogin {
                        self.setLaunchAtLogin(true)
                    }

                    // Write config
                    if let detectedName {
                        VibePadConfig.writeCurrentDefaults(voiceOverride: finalAction, voiceAppName: detectedName)
                    } else {
                        VibePadConfig.writeCurrentDefaults(voiceOverride: finalAction)
                    }

                    self.onboardingWizard = nil
                }
            }
        }

        manager.onButtonPressed = { [weak self] button, pressed in
            guard let self, self.isEnabled else {
                print("[VibePad] Button ignored: isEnabled=\(self?.isEnabled ?? false)")
                return
            }
            if pressed && !self.hasTrackedFirstButton {
                self.hasTrackedFirstButton = true
                Analytics.send(Analytics.firstButtonPress)
            }
            print("[VibePad] Dispatching button: \(button.rawValue) pressed=\(pressed)")
            mapper.handleButton(button, pressed: pressed)
        }

        manager.onLeftStick = { [weak self] x, y in
            guard let self, self.isEnabled else { return }
            DispatchQueue.main.async {
                mapper.handleLeftStick(x: x, y: y)
            }
        }

        manager.onRightStick = { [weak self] x, y in
            guard let self, self.isEnabled else { return }
            DispatchQueue.main.async {
                mapper.handleRightStick(x: x, y: y)
            }
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

    func setHUDEnabled(_ enabled: Bool) {
        isHUDEnabled = enabled
        VibePadConfig.update { $0.hudEnabled = enabled }
    }

    func checkForUpdates() {
        updaterController?.checkForUpdates(nil)
    }

    func showVoiceShortcutPicker() {
        // Pre-fill with current L2 action from config, or default
        let config = VibePadConfig.load()
        let currentAction = voiceAction(from: config) ?? .keystroke(key: "space", modifiers: ["option"])

        let picker = VoiceShortcutPicker()
        self.voiceShortcutPicker = picker
        picker.show(prefilled: currentAction) { [weak self] result in
            guard let self, let (action, label) = result else { return }
            self.voiceHotkeyLabel = label
            VibePadConfig.writeCurrentDefaults(voiceOverride: action)
            self.hud?.show(action: action, description: "Restart to apply", duration: 2.0)
        }
    }

    private func voiceAction(from config: VibePadConfig?) -> MappedAction? {
        config?.mappings[GamepadButton.leftTrigger.rawValue]?.toMappedAction()
    }
}
