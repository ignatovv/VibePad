<p align="center">
  <img src="assets/mascot.svg" alt="VibePad mascot" width="200">
</p>

<h1 align="center">VibePad</h1>

<p align="center">
  Ship code from your couch. Control your AI coding assistant with a gamepad.
</p>

<p align="center">
  <a href="https://github.com/ignatovv/VibePad/releases/latest"><img src="https://img.shields.io/github/v/release/ignatovv/VibePad?style=flat-square&label=download&color=blue" alt="Latest Release"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-black?style=flat-square&logo=apple" alt="macOS 14+">
  <img src="https://img.shields.io/badge/license-PolyForm%20NC-green?style=flat-square" alt="License">
</p>

<p align="center">
  <img src="assets/hero.gif" alt="VibePad demo — controlling Claude Code with a DualSense gamepad" width="720">
</p>

VibePad is a macOS menu bar app that turns your gamepad into a full coding controller — optimized for AI-assisted development with Claude Code, Cursor, and VS Code.

Accept AI suggestions, scroll through code, switch apps, dictate with voice — all without touching your keyboard.

## How It Works

1. Connect your PS5, Xbox, or MFi controller
2. VibePad maps buttons to keyboard shortcuts optimized for Claude Code, Cursor, and VS Code
3. Accept AI suggestions, navigate code, switch tabs — all from your controller

## Features

- **Two-layer mapping** — default layer + L1 modifier layer doubles your button count
- **Smart Paste** — clipboard-aware: Ctrl+V for images, Cmd+V for text
- **Left stick = arrow keys** — hysteresis thresholds and hold-to-repeat
- **Right stick = scroll** — continuous smooth scrolling
- **L1+stick = app switch & mouse** — switch apps or move the cursor without leaving the couch
- **Mouse clicks** — L3/R3 for left/right click
- **Hold-to-repeat** — configurable per-button repeat delay and interval
- **Trigger modes** — fire on press, release, or both (e.g. hold-to-talk for voice input)
- **HUD overlay** — shows action labels on every button press
- **JSON config** — full customization at `~/.vibepad/config.json`
- **Menu bar app** — lives in your status bar, launch at login

## Install

1. Download the latest release from [GitHub Releases](https://github.com/ignatovv/VibePad/releases)
2. Move **VibePad.app** to Applications
3. Launch and grant Accessibility permission when prompted

> Accessibility permission is required for keyboard injection — this is how VibePad sends keystrokes to your apps.

## Custom Mappings

VibePad writes its default config to `~/.vibepad/config.json` on first launch. Edit this file to customize your layout, then restart the app.

```json
{
  "version": 1,
  "profile": "claude-code",
  "mappings": {
    "buttonA": { "type": "keystroke", "key": "return", "modifiers": [] },
    "buttonX": { "type": "keystroke", "key": "c", "modifiers": ["control"] },
    "buttonMenu": { "type": "typeText", "text": "/" }
  },
  "l1Mappings": {
    "buttonB": { "type": "keystroke", "key": "delete", "modifiers": [] }
  },
  "stickConfig": {
    "leftStickDeadzone": 0.3,
    "rightStickDeadzone": 0.2,
    "arrowPressThreshold": 0.5,
    "arrowReleaseThreshold": 0.3,
    "scrollSensitivity": 15.0
  }
}
```

### Action types

- **`keystroke`** — press a key with optional modifiers. `key` is any key name from the [key list](#available-keys), `modifiers` is an array of `"command"`, `"control"`, `"shift"`, `"option"`.
- **`typeText`** — type a string character by character. Use `\n` for Enter.
- **`smartPaste`** — clipboard-aware paste: sends Ctrl+V when the clipboard contains an image, Cmd+V otherwise. No `key` or `modifiers` needed.
- **`leftMouseClick`** / **`rightMouseClick`** — simulate a mouse click at the current cursor position.

### Available buttons

`buttonA`, `buttonB`, `buttonX`, `buttonY`, `dpadUp`, `dpadDown`, `dpadLeft`, `dpadRight`, `leftShoulder`, `rightShoulder`, `leftTrigger`, `rightTrigger`, `leftThumbstickButton`, `rightThumbstickButton`, `buttonMenu`, `buttonOptions`

Note: `leftShoulder` (L1) is reserved as the modifier layer key and cannot be remapped.

### Available keys

Letters (`a`-`z`), numbers (`0`-`9`), `return`, `escape`, `space`, `tab`, `delete`, `forwardDelete`, arrows (`upArrow`, `downArrow`, `leftArrow`, `rightArrow`), punctuation (`grave`, `minus`, `equal`, `leftBracket`, `rightBracket`, `backslash`, `semicolon`, `quote`, `comma`, `period`, `slash`), function keys (`f1`-`f12`).

## Button Layout

<img src="docs/vibepad-layout.png" alt="VibePad default layer — controller mapping diagram" width="700">

<img src="docs/vibepad-l1-layout.png" alt="VibePad L1 layer — hold L1 for extra actions" width="700">

> [View interactive layout on PadCrafter](https://www.padcrafter.com/index.php?templates=VibePad%7CL1%20Layer%20%28Hold%20L1%29&leftTrigger=Voice-to-text&rightTrigger=Submit&leftBumper=Layer%20Modifier%20%28L1%29&rightBumper=Switch%20Mode&aButton=Accept&bButton=Cancel%7CDelete&xButton=Interrupt&yButton=Paste%7CCopy&dpadUp=History%20Up&dpadDown=History%20Down&dpadLeft=Prev%20Tab%7CPrev%20App&dpadRight=Next%20Tab%7CNext%20App&leftStickClick=Right%20Click%7CRight%20Click&rightStickClick=Left%20Click%7CLeft%20Click&startButton=Slash%20Command&backButton=Clear%20Chat&leftStick=Arrow%20Keys%7CPrev%2FNext%20App&rightStick=Scroll%7CMouse%20Cursor)

## Requirements

- macOS 14 (Sonoma) or later
- PS5 DualSense, Xbox, or MFi controller
- Accessibility permission (for keyboard injection)

Built with Swift, AppKit, GameController framework, and CGEvent.

## Acknowledgments

Inspired by [enjoy2](https://github.com/fyber/enjoy2) — a macOS joystick-to-keyboard mapper.

## License

[PolyForm Noncommercial 1.0.0](https://polyformproject.org/licenses/noncommercial/1.0.0/) — source available, non-commercial use permitted. See [LICENSE](LICENSE) for details.
