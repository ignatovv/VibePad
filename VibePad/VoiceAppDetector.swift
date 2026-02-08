//
//  VoiceAppDetector.swift
//  VibePad
//

import AppKit
import Foundation

struct DetectedVoiceApp {
    let name: String
    let action: MappedAction
    let hotkeyLabel: String
}

enum VoiceAppDetector {

    private struct KnownApp {
        let name: String
        let bundleID: String
        let prefKey: String
        let defaultAction: MappedAction
        let defaultHotkeyLabel: String
    }

    private static let knownApps: [KnownApp] = [
        KnownApp(
            name: "VoiceInk",
            bundleID: "com.prakashjoshipax.VoiceInk",
            prefKey: "KeyboardShortcuts_toggleMiniRecorder",
            defaultAction: .keystroke(key: "space", modifiers: ["option"]),
            defaultHotkeyLabel: "⌥Space"
        ),
        KnownApp(
            name: "Superwhisper",
            bundleID: "com.superduper.superwhisper",
            prefKey: "globalHotkey",
            defaultAction: .keystroke(key: "space", modifiers: ["option"]),
            defaultHotkeyLabel: "⌥Space"
        ),
        KnownApp(
            name: "MacWhisper",
            bundleID: "com.goodsnooze.MacWhisperMacWhisper.MacWhisper",
            prefKey: "globalHotkey",
            defaultAction: .keystroke(key: "space", modifiers: ["option"]),
            defaultHotkeyLabel: "⌥Space"
        ),
    ]

    // Carbon modifier flags → VibePad modifier names
    private static let carbonModifierMap: [Int: String] = [
        0x100:  "shift",
        0x200:  "control",
        0x800:  "option",
        0x1000: "command",
    ]

    // Reverse keyCodeMap: CGKeyCode → key name (built once lazily)
    private static let reverseKeyCodeMap: [CGKeyCode: String] = {
        var map: [CGKeyCode: String] = [:]
        for (name, code) in KeyboardEmitter.keyCodeMap {
            map[code] = name
        }
        return map
    }()

    static func detect() -> DetectedVoiceApp? {
        for app in knownApps {
            guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleID) != nil else {
                continue
            }
            print("[VibePad] Found voice app: \(app.name) (\(app.bundleID))")

            // Try to read the hotkey from the app's preferences
            if let action = readHotkey(bundleID: app.bundleID, prefKey: app.prefKey) {
                let label = OverlayHUD.label(for: action)
                return DetectedVoiceApp(name: app.name, action: action, hotkeyLabel: label)
            }

            // Fall back to the app's known default hotkey
            return DetectedVoiceApp(name: app.name, action: app.defaultAction, hotkeyLabel: app.defaultHotkeyLabel)
        }
        return nil
    }

    private static func readHotkey(bundleID: String, prefKey: String) -> MappedAction? {
        guard let defaults = UserDefaults(suiteName: bundleID),
              let raw = defaults.string(forKey: prefKey) else {
            print("[VibePad] Could not read pref \(prefKey) for \(bundleID)")
            return nil
        }

        // Parse JSON: {"carbonKeyCode": <int>, "carbonModifiers": <int>}
        guard let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let carbonKeyCode = json["carbonKeyCode"] as? Int,
              let carbonModifiers = json["carbonModifiers"] as? Int else {
            print("[VibePad] Could not parse hotkey JSON: \(raw)")
            return nil
        }

        // Resolve key name from carbon key code
        guard let keyName = reverseKeyCodeMap[CGKeyCode(carbonKeyCode)] else {
            print("[VibePad] Unknown carbon keycode: \(carbonKeyCode)")
            return nil
        }

        // Decode modifier flags
        var modifiers: [String] = []
        for (flag, name) in carbonModifierMap {
            if carbonModifiers & flag != 0 {
                modifiers.append(name)
            }
        }

        return .keystroke(key: keyName, modifiers: modifiers)
    }
}
