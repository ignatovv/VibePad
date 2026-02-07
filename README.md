# VibePad

> Ship code from your couch. A macOS menu bar app that turns your gamepad into a vibe coding controller.

A lightweight macOS menu bar app that maps gamepad inputs to keyboard shortcuts optimized for AI-assisted development in VS Code, Cursor, and terminal.

## Features

- Native PS5/Xbox controller support via Apple's GameController framework
- Optimized default mappings for Cursor, VS Code, and terminal
- JSON-based configuration at `~/.vibepad/config.json`
- Visual HUD overlay showing button actions
- Menu bar controls with enable/disable toggle

## Default Mapping

Optimized for Claude Code and terminal workflows.

| Button | Action | Output |
|--------|--------|--------|
| **X / A** | Accept/Confirm | `Return` |
| **O / B** | Cancel/Back | `Escape` |
| **□ / X** | Interrupt | `Ctrl+C` |
| **△ / Y** | Paste | `Cmd+V` |
| **D-pad ↑↓** | Command history | `↑` / `↓` |
| **D-pad ←→** | Switch tabs | `Cmd+Shift+[` / `]` |
| **L1 (hold)** | Modifier layer | See L1 layer below |
| **R1** | Autocomplete | `Tab` |
| **L2** | Voice (future) | `Option+Space` |
| **R2** | Submit | `Return` |
| **L3 (stick click)** | Reverse search | `Ctrl+R` |
| **R3 (stick click)** | Clear screen | `Ctrl+L` |
| **Menu** | Ship it | types `/commit` + Enter |
| **Options** | Help | types `/help` + Enter |
| **Left Stick** | Arrow keys | Arrow keys (with deadzone) |
| **Right Stick** | Scroll | Scroll viewport |

### L1 Layer (hold L1 + press)

| Button | Action | Output |
|--------|--------|--------|
| **A** | Compact context | types `/compact` + Enter |
| **B** | Undo | `Cmd+Z` |
| **X** | EOF / exit | `Ctrl+D` |
| **Y** | Review changes | types `/review` + Enter |

## Custom Mappings

VibePad writes its default config to `~/.vibepad/config.json` on first launch. Edit this file to customize your layout, then restart the app.

```json
{
  "version": 1,
  "profile": "claude-code",
  "mappings": {
    "buttonA": { "type": "keystroke", "key": "return", "modifiers": [] },
    "buttonX": { "type": "keystroke", "key": "c", "modifiers": ["control"] },
    "buttonMenu": { "type": "typeText", "text": "/commit\n" }
  },
  "l1Mappings": {
    "buttonA": { "type": "typeText", "text": "/compact\n" },
    "buttonB": { "type": "keystroke", "key": "z", "modifiers": ["command"] }
  },
  "stickConfig": {
    "leftStickDeadzone": 0.3,
    "rightStickDeadzone": 0.2,
    "arrowPressThreshold": 0.5,
    "arrowReleaseThreshold": 0.3,
    "scrollSensitivity": 5.0
  }
}
```

### Action types

- **`keystroke`** — press a key with optional modifiers. `key` is any key name from the [key list](#available-keys), `modifiers` is an array of `"command"`, `"control"`, `"shift"`, `"option"`.
- **`typeText`** — type a string character by character. Use `\n` for Enter.

### Available buttons

`buttonA`, `buttonB`, `buttonX`, `buttonY`, `dpadUp`, `dpadDown`, `dpadLeft`, `dpadRight`, `leftShoulder`, `rightShoulder`, `leftTrigger`, `rightTrigger`, `leftThumbstickButton`, `rightThumbstickButton`, `buttonMenu`, `buttonOptions`

Note: `leftShoulder` (L1) is reserved as the modifier layer key and cannot be remapped.

### Available keys

Letters (`a`-`z`), numbers (`0`-`9`), `return`, `escape`, `space`, `tab`, `delete`, `forwardDelete`, arrows (`upArrow`, `downArrow`, `leftArrow`, `rightArrow`), punctuation (`grave`, `minus`, `equal`, `leftBracket`, `rightBracket`, `backslash`, `semicolon`, `quote`, `comma`, `period`, `slash`), function keys (`f1`-`f12`).

## Requirements

- macOS 14 (Sonoma) or later
- PS5 DualSense, Xbox, or MFi controller
- Accessibility permission (for keyboard injection)

## Installation

1. Download the latest release
2. Move VibePad.app to Applications
3. Launch and grant Accessibility permission when prompted

## Tech Stack

- Swift 5.9+
- AppKit (menu bar app)
- GameController framework
- CGEvent for keyboard injection

## Acknowledgments

Inspired by [enjoy2](https://github.com/fyber/enjoy2) — a macOS joystick-to-keyboard mapper.

## License

MIT
