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
        MenuBarExtra {
            MenuBarPanelView(appDelegate: appDelegate)
        } label: {
            Image(nsImage: menuBarNSImage(named: appDelegate.menuBarIcon))
        }
        .menuBarExtraStyle(.window)
    }

    private func menuBarNSImage(named name: String) -> NSImage {
        let image = NSImage(named: name) ?? NSImage()
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = true
        return image
    }
}
