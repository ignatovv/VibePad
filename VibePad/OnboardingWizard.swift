//
//  OnboardingWizard.swift
//  VibePad
//

import AppKit
import SwiftUI

// MARK: - OnboardingWizard

final class OnboardingWizard {

    private var panel: KeyablePanel?
    private var recorder: ShortcutRecorderState?

    func show(
        prefilled: MappedAction,
        completion: @escaping (_ voiceAction: MappedAction?, _ voiceLabel: String?, _ launchAtLogin: Bool) -> Void
    ) {
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

        let view = OnboardingView(
            recorder: recorder,
            onComplete: { [weak self] voiceAction, voiceLabel, launchAtLogin in
                self?.dismiss()
                completion(voiceAction, voiceLabel, launchAtLogin)
            }
        )

        let hosting = NSHostingView(rootView: view)
        let size = CGSize(width: 360, height: 340)
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

// MARK: - Onboarding Step

private enum OnboardingStep: CaseIterable {
    case welcome
    case accessibility
    case voice
    case launchAtLogin
}

// MARK: - SwiftUI Onboarding View

private struct OnboardingView: View {
    @Bindable var recorder: ShortcutRecorderState
    let onComplete: (_ voiceAction: MappedAction?, _ voiceLabel: String?, _ launchAtLogin: Bool) -> Void

    @State private var step: OnboardingStep = .welcome
    @State private var voiceSaved = false

    var body: some View {
        VStack(spacing: 16) {
            switch step {
            case .welcome:
                welcomeStep
            case .accessibility:
                accessibilityStep
            case .voice:
                voiceStep
            case .launchAtLogin:
                launchAtLoginStep
            }
        }
        .padding(24)
        .frame(width: 360, height: 340)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .animation(.easeInOut(duration: 0.2), value: step)
    }

    // MARK: - Welcome

    private var welcomeStep: some View {
        VStack(spacing: 16) {
            Spacer()

            Image("onboarding-mascot")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)

            Text("Welcome to VibePad")
                .font(.system(size: 18, weight: .semibold))

            Text("Ship code from your couch.\nControl your AI coding assistant\nwith a gamepad")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Button("Get Started") {
                step = .accessibility
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
    }

    // MARK: - Accessibility

    private var accessibilityStep: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "gamecontroller")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("Grant Accessibility Access")
                .font(.system(size: 16, weight: .semibold))

            Text("VibePad needs Accessibility access to turn gamepad inputs into keystrokes for your coding tools.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 4) {
                Text("It's safe — VibePad")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Link("code is open", destination: URL(string: "https://github.com/ignatovv/VibePad")!)
                    .font(.system(size: 11))
            }

            Spacer()

            Button("Grant Access") {
                AccessibilityHelper.checkAndPrompt()
                step = .voice
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
    }

    // MARK: - Voice Shortcut

    private var voiceStep: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("What's your voice-to-text shortcut?")
                .font(.system(size: 16, weight: .semibold))

            ShortcutRecorderField(recorder: recorder)

            Spacer()

            Button("Save") {
                voiceSaved = true
                step = .launchAtLogin
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(recorder.isRecording)

            Button("I don't use voice-to-text") {
                step = .launchAtLogin
            }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Launch at Login

    private var launchAtLoginStep: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "sunrise")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("Launch at Login")
                .font(.system(size: 16, weight: .semibold))

            Text("Start VibePad automatically when you log in so it's always ready.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            HStack(spacing: 16) {
                Button("Not Now") {
                    onComplete(voiceSaved ? recorder.action : nil,
                               voiceSaved ? recorder.label : nil,
                               false)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Button("Enable") {
                    onComplete(voiceSaved ? recorder.action : nil,
                               voiceSaved ? recorder.label : nil,
                               true)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
        }
    }
}
