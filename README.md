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

| Button | Action | Shortcut |
|--------|--------|----------|
| **X / A** | Accept/Confirm | `Return` |
| **O / B** | Cancel/Dismiss | `Escape` |
| **△ / Y** | AI Chat | `Cmd+L` |
| **□ / X** | Save | `Cmd+S` |
| **D-pad** | Navigate | Arrow keys / Tab switching |
| **L1** | Switch Panel | `Cmd+\`` |
| **R1** | Command Palette | `Cmd+Shift+P` |
| **L2** | Voice Trigger | Configurable |
| **R2** | Run/Execute | `Cmd+Enter` |
| **Left Stick** | Cursor Movement | Arrow keys |
| **Right Stick** | Scroll | Scroll viewport |

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
