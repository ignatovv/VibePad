//
//  MenuBarPanelView.swift
//  VibePad
//

import SwiftUI

struct MenuBarPanelView: View {
    @Bindable var appDelegate: AppDelegate

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // MARK: Header
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                    Text("VibePad")
                        .font(.headline)
                }

                HStack(spacing: 6) {
                    Circle()
                        .fill(appDelegate.controllerName != nil ? .green : Color(.systemGray))
                        .frame(width: 8, height: 8)
                    Text(appDelegate.controllerName ?? "No controller")
                        .font(.subheadline)
                        .foregroundStyle(appDelegate.controllerName != nil ? .primary : .secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 12)

            Divider()

            // MARK: Toggle
            Toggle("Enabled", isOn: $appDelegate.isEnabled)
                .toggleStyle(.switch)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            Divider()

            // MARK: Accessibility warning
            if !appDelegate.isAccessibilityGranted {
                ActionRow(
                    icon: "exclamationmark.triangle.fill",
                    iconColor: .yellow,
                    label: "Grant Accessibility Access..."
                ) {
                    AccessibilityHelper.checkAndPrompt()
                }

                Divider()
            }

            // MARK: Actions
            VStack(spacing: 0) {
                ActionRow(icon: "doc.text", label: "Open Config...") {
                    NSWorkspace.shared.open(VibePadConfig.configFileURL)
                }

                ActionRow(icon: "power", label: "Quit VibePad", shortcut: "\u{2318}Q") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(.vertical, 4)
        }
        .frame(width: 320)
    }
}

// MARK: - Action Row

private struct ActionRow: View {
    let icon: String
    var iconColor: Color = .secondary
    let label: String
    var shortcut: String? = nil
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                    .frame(width: 20)
                Text(label)
                Spacer()
                if let shortcut {
                    Text(shortcut)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovering ? Color.primary.opacity(0.1) : .clear)
                    .padding(.horizontal, 8)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
