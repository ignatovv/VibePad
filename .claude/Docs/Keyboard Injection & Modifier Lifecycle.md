# Keyboard Injection & Modifier Lifecycle

Technical reference for how VibePad injects keyboard input and manages modifier key state. Covers the CGEvent model, sticky modifiers for app switching, and the safety nets that prevent stuck keys.

---

## CGEvent Primer

macOS keyboard injection uses Quartz Event Services (`CGEvent`). VibePad posts events at the HID event tap (`cghidEventTap`), which inserts them at the lowest level — before any app sees them.

There are two fundamentally different event types:

| Event type | What it represents | When to use |
|---|---|---|
| `.keyDown` / `.keyUp` | A character key was pressed/released | Typing keys (letters, arrows, Return, etc.) |
| `.flagsChanged` | Modifier state changed | Pressing/releasing Cmd, Shift, Option, Control |

This distinction matters. If you send a Cmd key-down as `.keyDown` instead of `.flagsChanged`, macOS will mostly ignore it — apps won't see the modifier as held.

---

## Three Levels of Modifier Usage

VibePad uses modifiers in three different ways, each with different lifecycle requirements:

### 1. Keystroke Modifiers (fire-and-forget)

The simplest case. A button maps to a shortcut like `Cmd+S`:

```
Button press → CGEvent(keyDown: "s", flags: .maskCommand) → CGEvent(keyUp: "s", flags: .maskCommand)
```

Both the down and up events carry the modifier flags. No separate modifier events are needed — macOS interprets the flags on the key event itself. The modifier is never "held" at the OS level.

**Code:** `KeyboardEmitter.postKeystroke(key:modifiers:)`

### 2. Sticky Modifiers (held across multiple keystrokes)

Used for app switching (Cmd+Tab). The macOS app switcher requires Cmd to stay held while you Tab through apps — releasing Cmd commits the selection. This can't be done with keystroke modifiers because Cmd would "release" between each Tab press.

The flow:

```
L1+DpadRight pressed:
  1. holdModifier("command")     → flagsChanged event, flags: .maskCommand
  2. postKeystroke("tab")        → keyDown+keyUp with .maskCommand flags
     (app switcher appears, Cmd is still held at OS level)

L1+DpadRight pressed again:
  1. Cmd already held, skip
  2. postKeystroke("tab")        → cycles to next app

L1 released:
  1. releaseModifier("command")  → flagsChanged event, flags: []
     (app switcher commits selection)
```

**Key detail:** `holdModifier()` and `releaseModifier()` use `.flagsChanged` event type with the modifier's own virtual key code (e.g., 0x37 for Cmd). The hold event sets the modifier flag; the release event sets empty flags `[]`. This is how macOS natively represents pressing and releasing a modifier key on a real keyboard.

**Code:** `KeyboardEmitter.holdModifier(_:)`, `KeyboardEmitter.releaseModifier(_:)`, `InputMapper.releaseStickyModifiers()`

**State tracking:** `InputMapper.heldStickyModifiers: Set<String>` tracks which modifiers are currently held. This prevents double-holding and ensures all held modifiers are released together.

### 3. Held Character Keys (arrow key repeat via sticks)

Analog sticks map to arrow keys with threshold-based activation. When the stick crosses the press threshold, the arrow key starts repeating. This uses `postKeystroke(keyCode:)` at high frequency (50 Hz) — NOT key-down/key-up hold, because CGEvent doesn't produce native key repeat from held key-down events the way a real keyboard does.

**Code:** `InputMapper.updateArrow(...)`, `KeyboardEmitter.postKeystroke(keyCode:)`

---

## The Stuck Modifier Problem

### What goes wrong

If a sticky modifier (e.g., Cmd) is held at the OS level and never released, the user's entire keyboard becomes unusable — every subsequent keypress is interpreted as Cmd+key. Typing "hello" becomes five sequential Cmd+key shortcuts. The only fix is to physically press and release the modifier key on a real keyboard.

### When it can happen

Sticky modifiers can leak if the release path is interrupted:

| Scenario | What interrupts release |
|---|---|
| Controller disconnects mid-app-switch | `controllerDidDisconnect` fires but L1 release never arrives |
| User disables VibePad via menu bar | `isEnabled` set to false, button events stop being processed |
| App terminates (quit, crash, update) | Process exits with modifiers still held at OS level |
| User switches from sticky to non-sticky action while L1 held | e.g., L1+DpadRight (sticky Cmd+Tab) then L1+B (Delete) |

### Safety nets (defense in depth)

Four independent mechanisms ensure modifiers are always cleaned up:

#### 1. L1 Release (normal path)
When L1 is released, `InputMapper.handleButton()` calls `releaseStickyModifiers()`. This is the happy path — covers the vast majority of cases.

```swift
// InputMapper.handleButton()
if button == .leftShoulder {
    isL1Held = pressed
    if !pressed {
        releaseStickyModifiers()  // Release Cmd when L1 goes up
    }
    return
}
```

#### 2. Action Transition (L1 still held)
When the user presses a non-sticky action while sticky modifiers are held (e.g., switches from app-switching to Delete), modifiers are released before the new action fires.

```swift
// InputMapper.handleButton()
if usingL1 && !heldStickyModifiers.isEmpty {
    if case .stickyKeystroke = action {
        // Same sticky family — keep modifiers held
    } else {
        releaseStickyModifiers()  // Different action — clean up first
    }
}
```

#### 3. Controller Disconnect
`GamepadManager.onDisconnect` callback fires when the controller is lost. `AppDelegate` wires this to release sticky modifiers:

```swift
// AppDelegate.applicationDidFinishLaunching()
manager.onDisconnect = { [weak mapper] in
    mapper?.releaseStickyModifiers()
}
```

#### 4. Disable Toggle
When VibePad is disabled via the menu bar, `isEnabled`'s `didSet` releases sticky modifiers:

```swift
// AppDelegate
var isEnabled = true {
    didSet {
        if !isEnabled { inputMapper?.releaseStickyModifiers() }
    }
}
```

#### 5. App Termination (nuclear option)
`applicationWillTerminate` releases ALL modifier keys unconditionally — not just tracked sticky ones. This catches edge cases where tracking state might be out of sync:

```swift
// AppDelegate
func applicationWillTerminate(_ notification: Notification) {
    emitter?.releaseAllModifiers()
}
```

`releaseAllModifiers()` iterates all four modifier key codes (Cmd, Shift, Option, Control) and sends a `.flagsChanged` release event for each, regardless of whether VibePad thinks they're held.

---

## Architecture Diagram

```
                    GamepadManager
                         │
              ┌──────────┼──────────┐
              │          │          │
         onButton   onLeftStick  onRightStick   onDisconnect
              │          │          │                 │
              ▼          ▼          ▼                 │
                   InputMapper                        │
              ┌──────────────────────┐                │
              │  activeMappings      │                │
              │  activeL1Mappings    │                │
              │  heldStickyModifiers │◄───────────────┘
              │                      │         (releaseStickyModifiers)
              └──────────┬───────────┘
                         │
                    fireAction()
                         │
                         ▼
                  KeyboardEmitter
              ┌──────────────────────┐
              │  postKeystroke()     │  ← keystroke modifiers (fire & forget)
              │  holdModifier()      │  ← sticky modifier hold (flagsChanged)
              │  releaseModifier()   │  ← sticky modifier release (flagsChanged)
              │  releaseAllModifiers │  ← nuclear cleanup on termination
              │  postScroll()       │
              │  postMouseMove()    │
              │  postMouseClick()   │
              └──────────────────────┘
                         │
                         ▼
                 CGEventPost(.cghidEventTap)
```

---

## L1 Layer Interaction

L1 (left shoulder) acts as a modifier layer — holding it switches all button mappings to the L1 layer. This is purely a VibePad concept; no OS-level modifier is involved for L1 itself.

The interaction between L1 and sticky modifiers:

1. **L1 pressed** — `isL1Held = true`, subsequent button lookups use `activeL1Mappings`
2. **L1+DpadRight** — fires `stickyKeystroke(key: "tab", stickyModifiers: ["command"])`, Cmd is held at OS level
3. **L1+DpadRight again** — Cmd already held (skipped), Tab fires again, app switcher cycles
4. **L1 released** — `releaseStickyModifiers()` sends Cmd release, app switcher commits

If the user presses a non-sticky L1 action (e.g., L1+B for Delete) while Cmd is stuck held, the action transition safety net releases Cmd before firing Delete.

---

## Modifier Key Codes

Virtual key codes used for `.flagsChanged` events:

| Modifier | Key code | CGEventFlags |
|---|---|---|
| Command (left) | `0x37` | `.maskCommand` |
| Shift (left) | `0x38` | `.maskShift` |
| Option (left) | `0x3A` | `.maskAlternate` |
| Control (left) | `0x3B` | `.maskControl` |

These are the LEFT modifier keys. macOS has separate codes for right-side modifiers (e.g., right Cmd = `0x36`), but VibePad only uses left-side codes since the distinction doesn't matter for shortcut injection.
