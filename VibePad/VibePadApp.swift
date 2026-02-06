//
//  VibePadApp.swift
//  VibePad
//
//  Created by Vova Ignatov on 2/6/26.
//

import SwiftUI

@main
struct VibePadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("VibePad", systemImage: "gamecontroller.fill") {
            if let name = appDelegate.controllerName {
                Text(name)
            } else {
                Text("No controller")
                    .foregroundStyle(.secondary)
            }

            Divider()

            Toggle("Enabled", isOn: Bindable(appDelegate).isEnabled)

            if !appDelegate.isAccessibilityGranted {
                Button("Grant Accessibility Access...") {
                    AccessibilityHelper.checkAndPrompt()
                }
            }

            Divider()

            Button("Quit VibePad") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
