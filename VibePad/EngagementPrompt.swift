//
//  EngagementPrompt.swift
//  VibePad
//

import AppKit
import SwiftUI

// MARK: - EngagementTracker

final class EngagementTracker {

    private enum Keys {
        static let sessionCount = "VibePad_sessionCount"
        static let engagementDismissed = "VibePad_engagementDismissed"
        static let lastPromptSessionCount = "VibePad_lastPromptSessionCount"
    }

    private let defaults = UserDefaults.standard
    private var toast: EngagementToast?

    func recordSessionEnd() {
        let count = defaults.integer(forKey: Keys.sessionCount) + 1
        defaults.set(count, forKey: Keys.sessionCount)
    }

    func shouldShowPrompt() -> Bool {
        let sessionCount = defaults.integer(forKey: Keys.sessionCount)
        guard sessionCount >= 3 else { return false }

        guard Analytics.daysSinceInstall() >= 2 else { return false }

        guard !defaults.bool(forKey: Keys.engagementDismissed) else { return false }

        let lastPrompt = defaults.integer(forKey: Keys.lastPromptSessionCount)
        if lastPrompt > 0 {
            guard sessionCount - lastPrompt >= 3 else { return false }
        }

        return true
    }

    func showToast() {
        defaults.set(defaults.integer(forKey: Keys.sessionCount), forKey: Keys.lastPromptSessionCount)
        Analytics.send(Analytics.engagementPromptShown)

        let toast = EngagementToast()
        self.toast = toast
        toast.show { [weak self] action in
            switch action {
            case .feedback:
                Analytics.send(Analytics.engagementFeedbackTapped)
                let subject = "VibePad Feedback"
                let body = """
                Hey! Thanks for taking a moment.

                1. What's working well for you?


                2. What's frustrating or could be better?


                3. What feature would make VibePad a must-have?


                """
                var components = URLComponents()
                components.scheme = "mailto"
                components.path = "feedback@vibepad.now"
                components.queryItems = [
                    URLQueryItem(name: "subject", value: subject),
                    URLQueryItem(name: "body", value: body),
                ]
                if let url = components.url {
                    NSWorkspace.shared.open(url)
                }
            case .notNow:
                Analytics.send(Analytics.engagementDismissed, parameters: ["permanent": "false"])
            case .never:
                Analytics.send(Analytics.engagementDismissed, parameters: ["permanent": "true"])
                self?.defaults.set(true, forKey: Keys.engagementDismissed)
            case .timeout:
                break
            }
            self?.toast = nil
        }
    }
}

// MARK: - EngagementToast

private enum ToastAction {
    case feedback, notNow, never, timeout
}

private final class EngagementToast {

    private var panel: NSPanel?
    private var dismissTimer: Timer?
    private var completion: ((ToastAction) -> Void)?

    func show(completion: @escaping (ToastAction) -> Void) {
        self.completion = completion

        let view = EngagementToastView(
            onFeedback: { [weak self] in self?.finish(.feedback) },
            onNotNow: { [weak self] in self?.finish(.notNow) },
            onNever: { [weak self] in self?.finish(.never) }
        )

        let hosting = NSHostingView(rootView: view)
        let size = hosting.fittingSize

        let panel = NSPanel(
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

        // Position below the menu bar icon (find the status item button window)
        if let screen = NSScreen.main {
            let screenFrame = screen.frame
            let statusButtonFrame = Self.findStatusItemFrame()
            let anchorX = statusButtonFrame?.midX ?? (screenFrame.maxX - size.width / 2 - 20)
            let x = anchorX - size.width / 2
            let y = screenFrame.maxY - NSStatusBar.system.thickness - size.height - 4
            panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
        }

        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            panel.animator().alphaValue = 1
        }

        self.panel = panel

        dismissTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: false) { [weak self] _ in
            self?.finish(.timeout)
        }
    }

    /// Find the VibePad status item button frame by scanning app windows.
    private static func findStatusItemFrame() -> NSRect? {
        for window in NSApp.windows {
            // The MenuBarExtra's status item lives in an NSStatusBarWindow
            let className = String(describing: type(of: window))
            if className.contains("StatusBar") {
                return window.frame
            }
        }
        return nil
    }

    private func finish(_ action: ToastAction) {
        dismissTimer?.invalidate()
        dismissTimer = nil
        let cb = completion
        completion = nil

        guard let panel else {
            cb?(action)
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            self?.panel?.orderOut(nil)
            self?.panel = nil
            cb?(action)
        }
    }
}

// MARK: - SwiftUI Toast View

private struct EngagementToastView: View {
    let onFeedback: () -> Void
    let onNotNow: () -> Void
    let onNever: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Arrow pointing up toward menu bar icon
            Triangle()
                .fill(.ultraThinMaterial)
                .frame(width: 16, height: 8)

            VStack(spacing: 10) {
                VStack(spacing: 4) {
                    Text("VibePad needs your feedback")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    Text("It would really help us get better")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Button(action: onFeedback) {
                    Text("Leave Feedback")
                        .font(.system(size: 13, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)

                HStack(spacing: 8) {
                    Button("Not now", action: onNotNow)
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    Text("\u{00B7}")
                        .foregroundStyle(.quaternary)
                        .font(.system(size: 11))

                    Button("Never", action: onNever)
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        }
        .fixedSize()
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
        }
    }
}
