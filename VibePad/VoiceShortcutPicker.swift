//
//  VoiceShortcutPicker.swift
//  VibePad
//

import AppKit
import SwiftUI

// MARK: - Shortcut Recorder State

@Observable
final class ShortcutRecorderState {
    var key: String
    var modifiers: [String]  // macOS-standard order
    var isRecording = false
    var isModifierOnly = false
    var modifierOnlyName: String?
    var pendingModifier: String?  // transient, used during recording

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // Reverse map: CGKeyCode → key name
    private static let reverseKeyCodeMap: [UInt16: String] = {
        var map: [UInt16: String] = [:]
        for (name, code) in KeyboardEmitter.keyCodeMap {
            map[UInt16(code)] = name
        }
        return map
    }()

    // Reverse map: modifier CGKeyCode → modifier name (left and right)
    private static let modifierKeyCodeToName: [UInt16: String] = [
        0x37: "command", 0x38: "shift", 0x3A: "option", 0x3B: "control",
        0x36: "rightCommand", 0x3C: "rightShift", 0x3D: "rightOption", 0x3E: "rightControl",
    ]

    // macOS-standard modifier order for sorting
    private static let modifierOrder: [String: Int] = [
        "control": 0, "rightControl": 1,
        "option": 2, "rightOption": 3,
        "shift": 4, "rightShift": 5,
        "command": 6, "rightCommand": 7,
    ]

    init(key: String, modifiers: [String]) {
        self.key = key
        self.modifiers = modifiers
    }

    init(modifierOnly modifier: String) {
        self.key = ""
        self.modifiers = []
        self.isModifierOnly = true
        self.modifierOnlyName = modifier
    }

    var label: String {
        OverlayHUD.label(for: action)
    }

    var action: MappedAction {
        if isModifierOnly, let mod = modifierOnlyName {
            return .modifierTap(modifier: mod)
        }
        return .keystroke(key: key, modifiers: modifiers)
    }

    func startRecording() {
        stopRecording()
        pendingModifier = nil
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let callback: CGEventTapCallBack = { _, type, event, userInfo -> Unmanaged<CGEvent>? in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let state = Unmanaged<ShortcutRecorderState>.fromOpaque(userInfo).takeUnretainedValue()

            // Handle modifier-only shortcuts via flagsChanged
            if type == .flagsChanged {
                let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
                let flags = event.flags
                let hasModifier = !flags.intersection([.maskCommand, .maskShift, .maskAlternate, .maskControl]).isEmpty

                if let modName = ShortcutRecorderState.modifierKeyCodeToName[keyCode] {
                    if hasModifier {
                        // Modifier pressed — remember it, wait for release
                        state.pendingModifier = modName
                    } else if let pending = state.pendingModifier {
                        // Modifier released with no intervening keyDown → modifier-only shortcut
                        state.pendingModifier = nil
                        DispatchQueue.main.async {
                            state.key = ""
                            state.modifiers = []
                            state.isModifierOnly = true
                            state.modifierOnlyName = pending
                            state.isRecording = false
                            state.stopRecording()
                        }
                        return nil
                    }
                }
                return Unmanaged.passUnretained(event)
            }

            // keyDown — clear pending modifier (user pressed modifier+key, not modifier-only)
            state.pendingModifier = nil

            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            guard let keyName = ShortcutRecorderState.reverseKeyCodeMap[keyCode] else {
                return Unmanaged.passUnretained(event)
            }

            let flags = event.flags
            var mods: [String] = []
            if flags.contains(.maskControl) { mods.append("control") }
            if flags.contains(.maskAlternate) { mods.append("option") }
            if flags.contains(.maskShift) { mods.append("shift") }
            if flags.contains(.maskCommand) { mods.append("command") }
            mods.sort { (ShortcutRecorderState.modifierOrder[$0] ?? 99) < (ShortcutRecorderState.modifierOrder[$1] ?? 99) }

            DispatchQueue.main.async {
                state.key = keyName
                state.modifiers = mods
                state.isModifierOnly = false
                state.modifierOnlyName = nil
                state.isRecording = false
                state.stopRecording()
            }

            // Suppress the event so voice apps don't see it
            return nil
        }

        let eventsOfInterest = CGEventMask(
            (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        )

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventsOfInterest,
            callback: callback,
            userInfo: selfPtr
        ) else { return }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.eventTap = tap
        self.runLoopSource = source
        self.isRecording = true
    }

    func stopRecording() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }
}

// MARK: - Keyable Panel (borderless panel that accepts key input)

final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

// MARK: - VoiceShortcutPicker

final class VoiceShortcutPicker {

    private var panel: KeyablePanel?
    private var recorder: ShortcutRecorderState?

    func show(prefilled: MappedAction, completion: @escaping ((MappedAction, String)?) -> Void) {
        let recorder: ShortcutRecorderState
        switch prefilled {
        case .keystroke(let key, let modifiers):
            recorder = ShortcutRecorderState(key: key, modifiers: modifiers)
        case .modifierTap(let modifier):
            recorder = ShortcutRecorderState(modifierOnly: modifier)
        default:
            recorder = ShortcutRecorderState(key: "space", modifiers: ["option"])
        }

        let view = VoiceShortcutPickerView(
            recorder: recorder,
            onSave: { [weak self] in
                self?.dismiss()
                completion((recorder.action, recorder.label))
            },
            onSkip: { [weak self] in
                self?.dismiss()
                completion(nil)
            }
        )

        let hosting = NSHostingView(rootView: view)
        let size = CGSize(width: 300, height: 220)
        hosting.frame = NSRect(origin: .zero, size: size)

        let panel = KeyablePanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = false
        panel.contentView = hosting

        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - size.width / 2
            let y = screenFrame.midY - size.height / 2
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.makeKey()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            panel.animator().alphaValue = 1
        }

        self.recorder = recorder
        self.panel = panel
    }

    func dismiss() {
        recorder?.stopRecording()
        recorder = nil
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            self?.panel?.orderOut(nil)
            self?.panel = nil
        }
    }
}

// MARK: - Reusable Shortcut Recorder Field

struct ShortcutRecorderField: View {
    @Bindable var recorder: ShortcutRecorderState

    var body: some View {
        Button {
            recorder.startRecording()
        } label: {
            VStack(spacing: 6) {
                if recorder.isRecording {
                    Text("Press a shortcut\u{2026}")
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                } else {
                    Text(recorder.label)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(recorder.isRecording ? Color.accentColor.opacity(0.08) : Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(recorder.isRecording ? Color.accentColor : Color.primary.opacity(0.15), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)

        if !recorder.isRecording {
            Text("Click to record a new shortcut")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        } else {
            Text("Press any key combination\u{2026}")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - SwiftUI Picker View

private struct VoiceShortcutPickerView: View {
    @Bindable var recorder: ShortcutRecorderState
    let onSave: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Voice-to-text Shortcut")
                .font(.system(size: 16, weight: .semibold))

            ShortcutRecorderField(recorder: recorder)

            HStack(spacing: 16) {
                Button("Cancel") { onSkip() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                Button("Save") { onSave() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .disabled(recorder.isRecording)
            }
        }
        .padding(24)
        .frame(width: 300, height: 220)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
