//
//  Analytics.swift
//  VibePad
//

import Foundation
import TelemetryDeck

enum Analytics {

    private static let appID = Secrets.telemetryDeckAppID

    // MARK: - Event Names

    static let appLaunched          = "appLaunched"
    static let accessibilityGranted = "accessibilityGranted"
    static let controllerConnected  = "controllerConnected"
    static let firstButtonPress     = "firstButtonPress"
    static let sessionStarted       = "sessionStarted"
    static let launchAtLoginEnabled = "launchAtLoginEnabled"
    static let learningModeToggled  = "learningModeToggled"
    static let customConfigOpened   = "customConfigOpened"
    static let voiceAppDetected     = "voiceAppDetected"
    static let appQuit              = "appQuit"

    // MARK: - Lifecycle

    static func start() {
        let config = TelemetryDeck.Config(appID: appID)
        TelemetryDeck.initialize(config: config)
    }

    static func send(_ event: String, parameters: [String: String] = [:]) {
        TelemetryDeck.signal(event, parameters: parameters)
    }

    // MARK: - Helpers

    private static let installDateKey = "VibePad_installDate"

    static func daysSinceInstall() -> Int {
        let defaults = UserDefaults.standard
        if let stored = defaults.object(forKey: installDateKey) as? Date {
            return Calendar.current.dateComponents([.day], from: stored, to: Date()).day ?? 0
        }
        defaults.set(Date(), forKey: installDateKey)
        return 0
    }
}
