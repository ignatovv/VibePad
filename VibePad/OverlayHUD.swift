//
//  OverlayHUD.swift
//  VibePad
//

import AppKit
import SwiftUI

final class OverlayHUD {

    private let panel: NSPanel
    private let hostingView: NSHostingView<HUDContentView>
    private var dismissTimer: Timer?

    // Published state for SwiftUI view
    private var actionLabel = ""
    private var descriptionLabel: String?

    init() {
        let contentView = HUDContentView()
        let hosting = NSHostingView(rootView: contentView)
        hosting.frame = NSRect(x: 0, y: 0, width: 200, height: 40)

        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = true
        panel.contentView = hosting

        self.panel = panel
        self.hostingView = hosting
    }

    func show(action: MappedAction, description: String? = nil) {
        actionLabel = Self.label(for: action)
        descriptionLabel = description

        let content = HUDContentView(action: actionLabel, description: description)
        hostingView.rootView = content

        // Size to fit content
        let size = hostingView.fittingSize
        hostingView.frame.size = size

        // Position top-right of main screen, below menu bar
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.maxX - size.width - 20
            let y = screenFrame.maxY - size.height - 8
            panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
        }

        panel.alphaValue = 1
        panel.orderFrontRegardless()

        // Reset dismiss timer
        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            self?.hide()
        }
    }

    func hide() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            self?.panel.orderOut(nil)
        }
    }

    // MARK: - Display helpers

    private static let modifierSymbols: [String: String] = [
        "command": "\u{2318}",  // ⌘
        "shift": "\u{21E7}",   // ⇧
        "control": "\u{2303}", // ⌃
        "option": "\u{2325}",  // ⌥
    ]

    private static let keyDisplayNames: [String: String] = [
        "return": "Enter",
        "escape": "Esc",
        "tab": "Tab",
        "space": "Space",
        "delete": "Delete",
        "upArrow": "\u{2191}",
        "downArrow": "\u{2193}",
        "leftArrow": "\u{2190}",
        "rightArrow": "\u{2192}",
        "leftBracket": "[",
        "rightBracket": "]",
    ]

    static func label(for action: MappedAction) -> String {
        switch action {
        case .keystroke(let key, let modifiers):
            let mods = modifiers.map { modifierSymbols[$0] ?? $0 }.joined()
            let keyName = keyDisplayNames[key] ?? key
            return mods + keyName
        case .stickyKeystroke(let key, let modifiers, let stickyModifiers):
            let allMods = (stickyModifiers + modifiers).map { modifierSymbols[$0] ?? $0 }.joined()
            let keyName = keyDisplayNames[key] ?? key
            return allMods + keyName
        case .typeText(let text):
            return text
        case .smartPaste:
            return "⌘V"
        }
    }
}

// MARK: - SwiftUI Content View

private struct HUDContentView: View {
    var action: String = ""
    var description: String?

    var body: some View {
        HStack(spacing: 6) {
            Text(action)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
            if let description {
                Text("\u{00B7}")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 14))
                Text(description)
                    .foregroundStyle(.secondary)
                    .font(.system(size: 13, weight: .medium))
            }
        }
        .fixedSize()
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}
