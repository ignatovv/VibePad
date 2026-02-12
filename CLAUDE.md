# VibePad — Ship code from your couch

## Overview
VibePad is a macOS menu bar app that lets you control your AI coding assistant with a gamepad. Maps controller inputs to keyboard shortcuts for Claude Code and Codex CLI. Uses GameController framework for input and CGEvent for keyboard injection.

## CRITICAL RULES
1. **NEVER commit/stage without explicit user request**
2. **NEVER run destructive git operations** without explicit approval (`--amend`, `reset --hard`, `push --force`, `clean -fd`)
3. **Read before edit** — always read the full file before making changes
4. **Minimize diffs** — prefer the smallest change that solves the problem
5. **No speculative fallbacks** — don't add error handling for scenarios that can't happen
6. **This is macOS, not iOS** — use AppKit/Cocoa patterns, not UIKit

## Tech Stack
- **Language:** Swift 5+
- **Platform:** macOS 14+ (Sonoma)
- **UI:** SwiftUI MenuBarExtra + AppKit (NSStatusItem, NSWindow for HUD)
- **Gamepad:** GameController framework (GCController, GCExtendedGamepad)
- **Keyboard injection:** CGEvent / CGEventPost (Quartz Event Services)
- **Config:** JSON (Codable), stored at `~/.vibepad/config.json`
- **Build:** Xcode (no SPM dependencies currently)

## Architecture
```
VibePad/
├── VibePadApp.swift         — @main entry, MenuBarExtra
├── AppDelegate.swift        — NSApplicationDelegate, GameController setup
├── GamepadManager           — GCController monitoring, connect/disconnect
├── InputMapper              — Config loading, maps inputs → actions
├── KeyboardEmitter          — CGEvent keystroke injection
├── OverlayHUD               — Transparent feedback window
├── StatusBarController      — Menu bar UI, enable/disable toggle
└── Config                   — JSON mapping model (Codable)
```

## Key Technical Notes
- **Accessibility required** — CGEvent injection needs System Settings → Privacy → Accessibility
- **App Sandbox disabled** — required for CGEvent access
- **Menu bar only** — no Dock icon (LSUIElement = true)
- **Analog sticks** — deadzone handling (0.2–0.3), threshold-based for arrow keys, continuous for scroll
- **Triggers (L2/R2)** — analog 0.0–1.0, treated as button when > 0.5

## Build & Test
```bash
# Build
xcodebuild -scheme VibePad -destination 'platform=macOS' build

# Test
xcodebuild -scheme VibePad -destination 'platform=macOS' test
```

## Project Spec
Full specification: `.claude/Docs/Gamepad Coding Interface Spec.md`
