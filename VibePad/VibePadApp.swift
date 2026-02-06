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
            Button("Quit VibePad") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
