# VibePad — Project Spec

> Ship code from your couch. A macOS menu bar app that turns your gamepad into a vibe coding controller.

## Overview

VibePad is a lightweight macOS menu bar app that maps gamepad inputs to keyboard shortcuts optimized for AI-assisted development in VS Code, Cursor, and terminal. It uses Apple's GameController framework for native PS5/Xbox controller support and CGEvent for keyboard injection.

**Target audience:** Developers who use AI coding tools (Cursor, Copilot, Claude Code).
**Primary goal:** Fun viral project + portfolio showcase for macOS/Swift skills.

---

## Architecture

```
VibePad (macOS menu bar app)
├── GamepadManager        — GameController framework, monitors connect/disconnect
├── InputMapper           — Reads config, maps GCController inputs → actions
├── KeyboardEmitter       — CGEvent-based keystroke injection
├── OverlayHUD            — Transparent window showing button → action feedback
├── StatusBarController   — Menu bar icon, enable/disable toggle, config access
└── Config                — JSON-based mapping loaded from ~/.vibepad/config.json
```

### Tech Stack

- **Language:** Swift 5.9+
- **UI:** AppKit (menu bar app, no main window)
- **Gamepad input:** Apple GameController framework (GCController)
- **Keyboard injection:** CGEvent / CGEventPost via Quartz Event Services
- **Config format:** JSON (Codable)
- **Min deployment target:** macOS 14 (Sonoma)
- **Build system:** Xcode / Swift Package Manager

### Why GameController framework over raw IOKit

- Native support for DualSense (PS5), Xbox, and MFi controllers
- Handles pairing, connection, disconnection automatically
- Clean Swift API with GCExtendedGamepad
- No need to parse raw HID reports
- Future-proof (Apple maintains it)

---

## MVP Feature Set

### 1. Gamepad Detection & Connection

- Detect controller connect/disconnect via `GCController.notifications`
- Support extended gamepad profile (`GCExtendedGamepad`)
- Show connection status in menu bar (icon change or indicator)
- Handle multiple controllers (use first connected)

### 2. Default "Vibe Mode" Mapping

Ship ONE opinionated preset optimized for Cursor/VS Code + terminal:

| Button | Action | Shortcut | Rationale |
|--------|--------|----------|-----------|
| **X / A** | Accept/Confirm | `Return` | Accept AI suggestion |
| **O / B** | Cancel/Dismiss | `Escape` | Dismiss suggestion |
| **△ / Y** | AI Chat | `Cmd+L` | Open Cursor AI chat |
| **□ / X** | Save | `Cmd+S` | Quick save |
| **D-pad Up** | Line Up | `↑` | Navigate code |
| **D-pad Down** | Line Down | `↓` | Navigate code |
| **D-pad Left** | Previous Tab | `Cmd+Shift+[` | Switch tabs |
| **D-pad Right** | Next Tab | `Cmd+Shift+]` | Switch tabs |
| **L1** | Switch Panel | `` Cmd+` `` | Toggle terminal/editor |
| **R1** | *Unassigned* | — | Reserved for future use |
| **L2 (hold)** | Voice Trigger | User-configured shortcut | Activate voice-to-text |
| **R2** | Run/Execute | `Cmd+Enter` | Run in terminal / accept |
| **Left Stick** | Arrow Keys | `↑↓←→` | Cursor movement |
| **Right Stick** | Scroll | Scroll events | Scroll viewport |
| **Left Stick Click** | *Unassigned* | — | Reserved for future use |
| **Right Stick Click** | *Unassigned* | — | Reserved for future use |
| **Start/Menu** | Slash prefix | Types `/` | Quick access to slash commands |
| **Select/Share** | *Unassigned* | — | Reserved for future use |

### 3. Keyboard Injection

- Use `CGEvent(keyboardEventSource:virtualKey:keyDown:)` for key events
- Support modifier keys (Cmd, Shift, Ctrl, Option)
- Handle key-down and key-up correctly for hold behaviors
- Requires Accessibility permission (prompt user on first launch)

### 4. Menu Bar Interface

- **Icon:** Gamepad icon in menu bar (SF Symbol: `gamecontroller.fill`)
- **Menu items:**
  - Enable/Disable toggle (with global state)
  - Controller status: "DualSense connected" / "No controller"
  - "Show Mapping" — opens a window or overlay showing current layout
  - "Open Config" — reveals config.json in Finder
  - "Quit"

### 5. Overlay HUD (Nice to Have for MVP)

- Transparent always-on-top window (like volume indicator)
- Shows button press → action name briefly (e.g., "△ → AI Chat")
- Auto-hides after 1.5 seconds
- Can be toggled off in menu

### 6. JSON Config

Located at `~/.vibepad/config.json`. Created with defaults on first launch.

```json
{
  "version": 1,
  "profile": "vibe-mode",
  "mappings": {
    "buttonA": { "type": "keystroke", "key": "return" },
    "buttonB": { "type": "keystroke", "key": "escape" },
    "buttonY": { "type": "keystroke", "key": "l", "modifiers": ["command"] },
    "buttonX": { "type": "keystroke", "key": "s", "modifiers": ["command"] },
    "dpadUp": { "type": "keystroke", "key": "upArrow" },
    "dpadDown": { "type": "keystroke", "key": "downArrow" },
    "dpadLeft": { "type": "keystroke", "key": "leftBracket", "modifiers": ["command", "shift"] },
    "dpadRight": { "type": "keystroke", "key": "rightBracket", "modifiers": ["command", "shift"] },
    "leftShoulder": { "type": "keystroke", "key": "grave", "modifiers": ["command"] },
    "rightShoulder": { "type": "keystroke", "key": "p", "modifiers": ["command", "shift"] },
    "leftTrigger": { "type": "keystroke", "key": "space", "modifiers": ["option"], "note": "Configure to match your voice-to-text shortcut" },
    "rightTrigger": { "type": "keystroke", "key": "return", "modifiers": ["command"] },
    "leftThumbstickButton": { "type": "keystroke", "key": "b", "modifiers": ["command"] },
    "rightThumbstickButton": { "type": "keystroke", "key": "grave", "modifiers": ["control"] },
    "buttonMenu": { "type": "keystroke", "key": "g", "modifiers": ["command", "shift"] },
    "buttonOptions": { "type": "keystroke", "key": "period", "modifiers": ["command"] }
  },
  "stickConfig": {
    "leftStick": { "type": "arrowKeys", "deadzone": 0.3 },
    "rightStick": { "type": "scroll", "deadzone": 0.2, "sensitivity": 5.0 }
  },
  "hudEnabled": true
}
```

---

## Implementation Plan

### Phase 1: Core Loop (Day 1)

1. Create new Xcode project (macOS App, menu bar only, Swift)
2. Set up `GCController` monitoring (connect/disconnect notifications)
3. Read extended gamepad inputs (button presses, stick values)
4. Implement `KeyboardEmitter` using CGEvent
5. Wire up: button press → mapped keystroke → CGEvent injection
6. Request Accessibility permissions with user prompt
7. Test with a PS5 or Xbox controller in VS Code

**Milestone:** Press X on controller → types Return in any app.

### Phase 2: Config & Polish (Day 2)

1. Implement JSON config loading from `~/.vibepad/config.json`
2. Create default config on first launch
3. Build menu bar UI with AppKit (NSStatusItem)
4. Add enable/disable toggle
5. Add controller status display
6. Implement analog stick → arrow keys with deadzone
7. Implement analog stick → scroll events

**Milestone:** Full mapping works, configurable via JSON, clean menu bar.

### Phase 3: HUD & Ship (Day 3)

1. Build transparent overlay HUD window
2. Show button → action feedback with auto-dismiss
3. Polish: app icon, menu bar icon
4. Handle edge cases (controller disconnect mid-use, permissions denied)
5. Create README with demo GIF
6. Build and notarize for distribution (or just GitHub release)

**Milestone:** Ready to record demo video and publish.

---

## Key Technical Notes

### Accessibility Permission

CGEvent injection requires Accessibility permission. The app must:
1. Be listed in System Settings → Privacy & Security → Accessibility
2. Prompt user on first launch with a helpful message
3. Gracefully handle "denied" state (show warning in menu bar)

### Analog Stick Handling

- Apply deadzone (0.2–0.3) to avoid drift
- For arrow keys: threshold-based (above 0.5 = key down, below 0.3 = key up)
- For scroll: continuous, scaled by sensitivity multiplier
- Poll via `valueChangedHandler` on `GCExtendedGamepad`

### Trigger Handling (L2/R2)

- Triggers are analog (0.0–1.0)
- Treat as button press when value > 0.5
- L2 "hold for voice" = fire shortcut on press, nothing on release

### App Lifecycle

- Menu bar only (set `LSUIElement = true` in Info.plist)
- Launch at login option (SMAppService or LaunchAgent)
- No Dock icon

---

## Post-MVP Ideas (V2+)

- **Custom mapping UI** — visual controller layout where you click a button and assign a shortcut
- **Multiple profiles** — switch between "Vibe Mode", "Git Mode", "Debug Mode"
- **Built-in voice-to-text** — capture audio from DualSense mic via AVAudioEngine, run through Whisper.cpp locally for zero-latency voice prompts (no external dictation app needed)
- **Haptic feedback** — DualSense adaptive triggers (rumble on build fail, pulse on success)
- **Stream overlay** — OBS-compatible overlay showing controller inputs for Twitch
- **Combo macros** — L1+X = custom multi-step action
- **Community configs** — share/import mapping profiles
- **Call-to-action** — prompt users to follow on Twitter/X (or donate). Could be a subtle link in the menu bar panel, a one-time HUD prompt, or both. Decide on handle and placement before implementing.

---

## Viral Launch Strategy

1. **Demo video** (30-60s): Split screen — left shows hands on PS5 controller, right shows Cursor accepting suggestions and shipping code. Caption: "I shipped a feature using a PS5 controller"
2. **Post on:** Twitter/X, Reddit (r/programming, r/cursor, r/vscode), Hacker News
3. **README** with high-quality GIF at the top, clear install instructions, and the controller mapping visual
4. **Hashtag:** #VibePad
