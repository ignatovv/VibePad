---
name: reboot
description: Kill, rebuild, and relaunch VibePad for testing
disable-model-invocation: false
---

Reboot VibePad: kill the running app, rebuild from source, and launch the new build.

1. Kill any running VibePad process:
```bash
killall VibePad 2>/dev/null || true
```

2. Build:
```bash
xcodebuild -scheme VibePad -destination 'platform=macOS' build 2>&1 | tail -5
```

3. Launch the freshly built app (use the most recently modified .app if multiple exist):
```bash
open $(ls -td /Users/vyuignatiov/Library/Developer/Xcode/DerivedData/VibePad-*/Build/Products/Debug/VibePad.app 2>/dev/null | head -1)
```

4. Report whether the build succeeded or failed to the user.
