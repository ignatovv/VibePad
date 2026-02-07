# VibePad Test Playbook — Claude Code Mappings

> Test the DualSense → Claude Code mapping layer end-to-end.
> Work through each section in order. Mark pass/fail as you go.

---

## Prerequisites

1. Build and run VibePad (`⌘R` in Xcode)
2. Accessibility permission granted (System Settings → Privacy → Accessibility)
3. DualSense connected (USB or Bluetooth)
4. Terminal.app (or iTerm) open and focused
5. Optionally: a Claude Code session running for slash-command tests

---

## Known Issues to Verify First

### BUG: `typeText` drops `/` and space characters

`typeText` looks up each character via `Self.keyCodeMap[String(ch)]`.
The keyCodeMap uses named keys: `"slash": 0x2C`, `"space": 0x31`.
But `String("/")` = `"/"`, not `"slash"` — so the lookup fails and the character is silently skipped.

**Impact:** All slash commands (`/commit`, `/help`, `/compact`, `/review`) will type without the leading `/`.

**Fix needed:** Add character-to-key translation in `typeText`, e.g.:
```swift
case "/": postKeystroke(key: "slash")
case " ": postKeystroke(key: "space")
```

**Test 0 — Verify the bug exists:**
- [ ] Focus Terminal, press Menu button → expected: types `commit` + Enter (missing `/`)
- [ ] After fix: press Menu button → expected: types `/commit` + Enter

---

## Assumptions & Design Decisions

| # | Assumption | Rationale |
|---|-----------|-----------|
| A1 | Target app is **terminal** running Claude Code | Not Cursor/VS Code — mappings are CLI-first |
| A2 | L1 is a **pure modifier** — no action on tap | Doubles mapping surface without wasting a button |
| A3 | L1 layer falls through to base if no override | L1+R2 still sends Enter — no dead buttons when holding L1 |
| A4 | `typeText` sends keystrokes, not Unicode events | Works in any app, matches how a keyboard types |
| A5 | Face buttons fire on **press only**, not release | Prevents double-fire, simpler mental model |
| A6 | Left stick uses **hysteresis** (0.5 press / 0.3 release) | Prevents jitter at threshold boundary |
| A7 | Right stick scroll is **continuous** (not threshold) | Smooth scroll like a trackpad |
| A8 | Triggers (L2/R2) treated as **buttons** (>0.5 = pressed) | Analog range not useful for keyboard actions |

---

## User Stories & Mapping Rationale

### Story 1: Accept/Reject tool calls hands-free
> "Claude Code asks me to run a tool. I press ✕ to approve or ○ to reject without touching the keyboard."

| Button | Action | Why this button |
|--------|--------|-----------------|
| ✕ (A) | Types `y\n` | ✕ = confirm/accept (PlayStation convention) |
| ○ (B) | Types `n\n` | ○ = back/cancel (PlayStation convention) |

**Tests:**
- [ ] **T1** — Claude Code is waiting on tool approval. Press ✕. Tool runs.
- [ ] **T2** — Claude Code is waiting on tool approval. Press ○. Tool is rejected.
- [ ] **T3** — At a blank shell prompt, press ✕. See `y` typed then command executes (harmless).

---

### Story 2: Interrupt a runaway command
> "Claude Code is running something that's taking too long. I press □ to kill it."

| Button | Action | Why this button |
|--------|--------|-----------------|
| □ (X) | Ctrl+C | □ = action button, Ctrl+C = universal interrupt |

**Tests:**
- [ ] **T4** — Run `sleep 999` in terminal. Press □. Process is killed, prompt returns.
- [ ] **T5** — Claude Code is generating output. Press □. Generation stops.

---

### Story 3: Paste from clipboard
> "I copied a command or prompt. I press △ to paste it into the terminal."

| Button | Action | Why this button |
|--------|--------|-----------------|
| △ (Y) | ⌘V | △ = top button, "put something in" |

**Tests:**
- [ ] **T6** — Copy `echo hello` to clipboard. Focus terminal. Press △. Text is pasted.

---

### Story 4: Navigate command history
> "I want to recall a previous command without typing it again."

| Button | Action | Why this button |
|--------|--------|-----------------|
| D-pad Up | Up arrow | Direct mapping, natural |
| D-pad Down | Down arrow | Direct mapping, natural |

**Tests:**
- [ ] **T7** — Run a few commands. Press D-pad Up repeatedly. Previous commands cycle.
- [ ] **T8** — Press D-pad Down to go forward in history.

---

### Story 5: Switch terminal tabs
> "I have multiple terminal tabs. I use D-pad left/right to switch."

| Button | Action | Why this button |
|--------|--------|-----------------|
| D-pad Left | ⌘⇧[ | Standard macOS prev-tab |
| D-pad Right | ⌘⇧] | Standard macOS next-tab |

**Tests:**
- [ ] **T9** — Open 2+ terminal tabs. Press D-pad Right. Moves to next tab.
- [ ] **T10** — Press D-pad Left. Moves to previous tab.

---

### Story 6: Shell autocomplete
> "I'm typing a path or command and press R1 to autocomplete."

| Button | Action | Why this button |
|--------|--------|-----------------|
| R1 | Tab | R1 = right shoulder = easy reach, Tab = autocomplete |

**Tests:**
- [ ] **T11** — Type `cd ~/Docu` then press R1. Shell completes to `Documents/`.

---

### Story 7: Submit / Enter
> "I finished typing a command. I press R2 to submit."

| Button | Action | Why this button |
|--------|--------|-----------------|
| R2 | Enter | Trigger = "pull to fire", natural submit gesture |

**Tests:**
- [ ] **T12** — Type `echo test` then press R2. Command executes.

---

### Story 8: Shell power moves
> "Quick access to reverse search and clear screen."

| Button | Action | Why this button |
|--------|--------|-----------------|
| L3 (left stick click) | Ctrl+R | Reverse search = "search through" the stick |
| R3 (right stick click) | Ctrl+L | Clear screen = "wipe" the stick |

**Tests:**
- [ ] **T13** — Press L3. Reverse search prompt `(reverse-i-search)` appears.
- [ ] **T14** — Press R3. Terminal screen clears.

---

### Story 9: Fire slash commands
> "I press Menu to commit, Options for help. No typing needed."

| Button | Action | Why this button |
|--------|--------|-----------------|
| Menu | Types `/commit\n` | Menu = "main action" = ship it |
| Options | Types `/help\n` | Options = "what can I do?" |

**Tests (after typeText bug is fixed):**
- [ ] **T15** — In Claude Code session, press Menu. `/commit` is typed and submitted.
- [ ] **T16** — In Claude Code session, press Options. `/help` is typed and submitted.

---

### Story 10: L1 modifier layer — extended commands
> "I hold L1 to access a second layer of actions on face buttons."

| Combo | Action | Why |
|-------|--------|-----|
| L1 + ✕ | Types `/compact\n` | Compact context when it's getting long |
| L1 + ○ | ⌘Z (Undo) | ○ = cancel → undo last action |
| L1 + □ | Ctrl+D (EOF) | □ = stop → close/exit |
| L1 + △ | Types `/review\n` | △ = inspect → review changes |

**Tests (after typeText bug is fixed):**
- [ ] **T17** — Hold L1, press ✕. Types `/compact` + Enter.
- [ ] **T18** — Hold L1, press ○. Sends ⌘Z (undo in a text editor).
- [ ] **T19** — Hold L1, press □. Sends Ctrl+D (exits a shell or sends EOF).
- [ ] **T20** — Hold L1, press △. Types `/review` + Enter.

---

### Story 11: L1 is transparent for unmapped buttons
> "Holding L1 doesn't break buttons that don't have an L1 override."

**Tests:**
- [ ] **T21** — Hold L1, press R2. Still sends Enter (falls through to base layer).
- [ ] **T22** — Hold L1, press D-pad Up. Still sends Up arrow.

---

### Story 12: L1 doesn't fire anything by itself
> "Tapping L1 alone does nothing — it's purely a modifier."

**Tests:**
- [ ] **T23** — Tap L1 (press and release quickly). Nothing is typed or sent.

---

### Story 13: Left stick as arrow keys
> "I tilt the left stick to move through menus, history, or selections."

**Tests:**
- [ ] **T24** — Tilt left stick up. Up arrow fires. Works in command history.
- [ ] **T25** — Tilt left stick down. Down arrow fires.
- [ ] **T26** — Tilt left stick left. Left arrow fires (cursor moves left in typed text).
- [ ] **T27** — Tilt left stick right. Right arrow fires.
- [ ] **T28** — Return stick to center. Key stops repeating (key-up fires).
- [ ] **T29** — Gently tilt stick (below 0.5). No arrow fires (deadzone works).

---

### Story 14: Right stick for scrolling
> "I tilt the right stick to scroll through terminal output or code."

**Tests:**
- [ ] **T30** — Run `ls -la /usr` or similar long output. Tilt right stick up. Output scrolls up.
- [ ] **T31** — Tilt right stick down. Output scrolls down.
- [ ] **T32** — Scrolling is smooth/continuous (not jerky steps).

---

### Story 15: Voice trigger (future placeholder)
> "L2 fires Option+Space, which will eventually trigger voice input."

| Button | Action | Why |
|--------|--------|-----|
| L2 | Option+Space | Placeholder for macOS dictation / future Whisper integration |

**Tests:**
- [ ] **T33** — Press L2. If macOS dictation is enabled, it activates. Otherwise just verify Option+Space fires (Spotlight may open — that's fine for now).

---

## Ergonomics Check

After running all tests, evaluate the overall feel:

- [ ] **E1** — Can you approve/reject 5 tool calls in a row without fumbling?
- [ ] **E2** — Does the L1 layer feel natural? Is it easy to hold L1 and press face buttons?
- [ ] **E3** — Is R2 for Enter comfortable for repeated use?
- [ ] **E4** — Do the sticks feel responsive? Any noticeable lag?
- [ ] **E5** — Any buttons that feel "wrong" — mapping doesn't match your intuition?
- [ ] **E6** — Any actions missing that you keep wanting to do?

---

## Results Summary

| Section | Pass | Fail | Skip | Notes |
|---------|------|------|------|-------|
| Bug verification (T0) | | | | |
| Face buttons (T1–T6) | | | | |
| D-pad (T7–T10) | | | | |
| Shoulders/triggers (T11–T12) | | | | |
| Stick buttons (T13–T14) | | | | |
| Slash commands (T15–T16) | | | | |
| L1 layer (T17–T22) | | | | |
| L1 modifier (T23) | | | | |
| Left stick (T24–T29) | | | | |
| Right stick (T30–T32) | | | | |
| Voice placeholder (T33) | | | | |
| Ergonomics (E1–E6) | | | | |
