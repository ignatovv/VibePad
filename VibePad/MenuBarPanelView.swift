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
            HeaderRow(appDelegate: appDelegate)

            Divider()

            // MARK: Options
            VStack(spacing: 0) {
                ActionRow(
                    icon: appDelegate.isHUDEnabled ? "checkmark.square" : "square",
                    label: "Learning Mode (hints)"
                ) {
                    appDelegate.isHUDEnabled.toggle()
                }

                if !appDelegate.launchAtLoginOnStartup {
                    ActionRow(
                        icon: appDelegate.launchAtLogin ? "sunrise.fill" : "sunrise",
                        label: "Launch at Login"
                    ) {
                        appDelegate.setLaunchAtLogin(!appDelegate.launchAtLogin)
                    }
                }

                if let hotkey = appDelegate.voiceHotkeyLabel {
                    ActionRow(
                        icon: "mic.fill",
                        label: "Voice-to-text (\(hotkey))"
                    ) {
                        appDelegate.showVoiceShortcutPicker()
                    }
                } else {
                    ActionRow(
                        icon: "mic",
                        label: "Voice-to-text: Set Up"
                    ) {
                        appDelegate.showVoiceShortcutPicker()
                    }
                }
            }

            Divider()

            // MARK: Accessibility warning
            if !appDelegate.isAccessibilityGranted {
                ActionRow(
                    icon: "exclamationmark.triangle.fill",
                    iconColor: .yellow,
                    label: "Please Grant Accessibility Access"
                ) {
                    AccessibilityHelper.checkAndPrompt()
                }

                Divider()
            }

            // MARK: Actions
            VStack(spacing: 0) {
                ActionRow(icon: "doc.text", label: "Custom Key Bindings") {
                    if !FileManager.default.fileExists(atPath: VibePadConfig.configFileURL.path) {
                        VibePadConfig.writeCurrentDefaults()
                    }
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
                Rectangle()
                    .fill(isHovering ? Color.primary.opacity(0.1) : .clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Header Row

private struct HeaderRow: View {
    @Bindable var appDelegate: AppDelegate

    @State private var isHovering = false

    var body: some View {
        Button {
            appDelegate.isEnabled.toggle()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(appDelegate.menuBarIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 22, height: 22)
                        .foregroundStyle(.secondary)
                    Text("VibePad")
                        .font(.headline)
                    Spacer()
                    Toggle("", isOn: $appDelegate.isEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .allowsHitTesting(false)
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
            .contentShape(Rectangle())
            .background(
                Rectangle()
                    .fill(isHovering ? Color.primary.opacity(0.1) : .clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

