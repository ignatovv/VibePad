//
//  KeyboardEmitter.swift
//  VibePad
//

import CoreGraphics

final class KeyboardEmitter {

    // MARK: - Key code map

    static let keyCodeMap: [String: CGKeyCode] = [
        // Letters
        "a": 0x00, "b": 0x0B, "c": 0x08, "d": 0x02, "e": 0x0E,
        "f": 0x03, "g": 0x05, "h": 0x04, "i": 0x22, "j": 0x26,
        "k": 0x28, "l": 0x25, "m": 0x2E, "n": 0x2D, "o": 0x1F,
        "p": 0x23, "q": 0x0C, "r": 0x0F, "s": 0x01, "t": 0x11,
        "u": 0x20, "v": 0x09, "w": 0x0D, "x": 0x07, "y": 0x10,
        "z": 0x06,
        // Numbers
        "0": 0x1D, "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15,
        "5": 0x17, "6": 0x16, "7": 0x1A, "8": 0x1C, "9": 0x19,
        // Special keys
        "return": 0x24,
        "escape": 0x35,
        "space": 0x31,
        "tab": 0x30,
        "delete": 0x33,
        "forwardDelete": 0x75,
        // Arrows
        "upArrow": 0x7E,
        "downArrow": 0x7D,
        "leftArrow": 0x7B,
        "rightArrow": 0x7C,
        // Punctuation / symbols
        "grave": 0x32,          // ` ~
        "minus": 0x1B,          // - _
        "equal": 0x18,          // = +
        "leftBracket": 0x21,    // [ {
        "rightBracket": 0x1E,   // ] }
        "backslash": 0x2A,      // \ |
        "semicolon": 0x29,      // ; :
        "quote": 0x27,          // ' "
        "comma": 0x2B,          // , <
        "period": 0x2F,         // . >
        "slash": 0x2C,          // / ?
        // Function keys
        "f1": 0x7A, "f2": 0x78, "f3": 0x63, "f4": 0x76,
        "f5": 0x60, "f6": 0x61, "f7": 0x62, "f8": 0x64,
        "f9": 0x65, "f10": 0x6D, "f11": 0x67, "f12": 0x6F,
    ]

    // MARK: - Modifier mapping

    static func modifierFlags(from modifiers: [String]) -> CGEventFlags {
        var flags = CGEventFlags()
        for mod in modifiers {
            switch mod {
            case "command":  flags.insert(.maskCommand)
            case "shift":    flags.insert(.maskShift)
            case "option":   flags.insert(.maskAlternate)
            case "control":  flags.insert(.maskControl)
            default: break
            }
        }
        return flags
    }

    // MARK: - Keystroke (press + release)

    func postKeystroke(key: String, modifiers: [String] = []) {
        guard let keyCode = Self.keyCodeMap[key] else {
            print("[VibePad] Unknown key: \(key)")
            return
        }
        print("[VibePad] Posting keystroke: \(key) (0x\(String(keyCode, radix: 16))) modifiers=\(modifiers)")
        let flags = Self.modifierFlags(from: modifiers)

        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
        else { return }

        down.flags = flags
        up.flags = flags
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    // MARK: - Type text (string of characters)

    private static let charToKeyName: [Character: String] = [
        "/": "slash", " ": "space", "\t": "tab",
        "`": "grave", "-": "minus", "=": "equal",
        "[": "leftBracket", "]": "rightBracket", "\\": "backslash",
        ";": "semicolon", "'": "quote", ",": "comma", ".": "period",
    ]

    func typeText(_ text: String) {
        for ch in text {
            if ch == "\n" {
                postKeystroke(key: "return")
            } else if let keyName = Self.charToKeyName[ch] {
                postKeystroke(key: keyName)
            } else if Self.keyCodeMap[String(ch)] != nil {
                postKeystroke(key: String(ch))
            }
        }
    }

    func postKeystroke(keyCode: CGKeyCode) {
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
        else { return }
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    // MARK: - Modifier hold / release (for sticky modifiers like Cmd during app switching)

    static let modifierKeyCodes: [String: CGKeyCode] = [
        "command": 0x37, "shift": 0x38, "option": 0x3A, "control": 0x3B,
    ]

    func holdModifier(_ modifier: String) {
        guard let keyCode = Self.modifierKeyCodes[modifier] else { return }
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) else { return }
        event.flags = Self.modifierFlags(from: [modifier])
        event.post(tap: .cghidEventTap)
    }

    func releaseModifier(_ modifier: String) {
        guard let keyCode = Self.modifierKeyCodes[modifier] else { return }
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else { return }
        event.post(tap: .cghidEventTap)
    }

    // MARK: - Key down / up (for held keys like arrows)

    func postKeyDown(keyCode: CGKeyCode) {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) else { return }
        event.post(tap: .cghidEventTap)
    }

    func postKeyUp(keyCode: CGKeyCode) {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else { return }
        event.post(tap: .cghidEventTap)
    }

    // MARK: - Scroll

    func postScroll(deltaX: Int32, deltaY: Int32) {
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: deltaY,
            wheel2: deltaX,
            wheel3: 0
        ) else { return }
        event.post(tap: .cghidEventTap)
    }
}
