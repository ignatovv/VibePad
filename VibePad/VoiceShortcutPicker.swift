//
//  VoiceShortcutPicker.swift
//  VibePad
//

import AppKit
import SwiftUI

// MARK: - Shortcut Recorder State

@Observable
private final class ShortcutRecorderState {
    var key: String
    var modifiers: [String]  // macOS-standard order
    var isRecording = false

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

    // macOS-standard modifier order for sorting
    private static let modifierOrder: [String: Int] = [
        "control": 0, "option": 1, "shift": 2, "command": 3,
    ]

    init(key: String, modifiers: [String]) {
        self.key = key
        self.modifiers = modifiers
    }

    var label: String {
        OverlayHUD.label(for: action)
    }

    var action: MappedAction {
        .keystroke(key: key, modifiers: modifiers)
    }

    func startRecording() {
        stopRecording()
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let callback: CGEventTapCallBack = { _, _, event, userInfo -> Unmanaged<CGEvent>? in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let state = Unmanaged<ShortcutRecorderState>.fromOpaque(userInfo).takeUnretainedValue()

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
                state.isRecording = false
                state.stopRecording()
            }

            // Suppress the event so voice apps don't see it
            return nil
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
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

private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

// MARK: - VoiceShortcutPicker

final class VoiceShortcutPicker {

    private var panel: KeyablePanel?
    private var recorder: ShortcutRecorderState?

    func show(prefilled: MappedAction, completion: @escaping ((MappedAction, String)?) -> Void) {
        let initialKey: String
        let initialModifiers: [String]
        if case .keystroke(let key, let modifiers) = prefilled {
            initialKey = key
            initialModifiers = modifiers
        } else {
            initialKey = "space"
            initialModifiers = ["option"]
        }

        let recorder = ShortcutRecorderState(key: initialKey, modifiers: initialModifiers)

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

// MARK: - SwiftUI Picker View

private struct VoiceShortcutPickerView: View {
    @Bindable var recorder: ShortcutRecorderState
    let onSave: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Title
            Text("Voice Shortcut")
                .font(.system(size: 16, weight: .semibold))

            // Shortcut recorder field
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

            // Buttons
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
