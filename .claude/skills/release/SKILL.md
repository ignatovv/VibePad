---
name: release
description: Build a signed release archive of VibePad, zip it, and sign with Sparkle EdDSA
disable-model-invocation: false
---

Build a release-ready VibePad .zip signed with Sparkle's EdDSA key. Optionally bump the version first.

## Arguments

The user may pass a version string (e.g. `/release 1.1`) to bump MARKETING_VERSION before building. If no version is given, use the current version from the project.

## Steps

1. **If a version argument was provided**, update MARKETING_VERSION in the VibePad target's Debug and Release build configurations in `VibePad.xcodeproj/project.pbxproj`. Also bump CURRENT_PROJECT_VERSION by 1 from its current value. Use the Edit tool — only change the two VibePad target configs (IDs `3DCDC9722F36A1750063EE37` and `3DCDC9732F36A1750063EE37`), not the test targets.

2. **Clean build the release archive**:
```bash
xcodebuild -scheme VibePad -destination 'platform=macOS' -configuration Release clean build 2>&1 | tail -10
```

3. **Locate the built .app**:
```bash
APP_PATH=$(ls -td /Users/vyuignatiov/Library/Developer/Xcode/DerivedData/VibePad-*/Build/Products/Release/VibePad.app 2>/dev/null | head -1)
echo "$APP_PATH"
```

4. **Read the version from the built app** for naming:
```bash
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$APP_PATH/Contents/Info.plist")
echo "Version: $VERSION ($BUILD)"
```

5. **Create a zip** in the project root:
```bash
cd "$(dirname "$APP_PATH")" && zip -r -y "/Users/vyuignatiov/code/VibePad/VibePad-${VERSION}.zip" VibePad.app
```

6. **Sign with Sparkle's EdDSA key**:
```bash
SPARKLE_BIN=$(ls -td /Users/vyuignatiov/Library/Developer/Xcode/DerivedData/VibePad-*/SourcePackages/artifacts/sparkle/Sparkle/bin 2>/dev/null | head -1)
"$SPARKLE_BIN/sign_update" "/Users/vyuignatiov/code/VibePad/VibePad-${VERSION}.zip"
```
This prints `sparkle:edSignature="..."` and `length="..."` — save these values.

7. **Report to the user**:
   - Path to the signed zip
   - The version and build number
   - The `sparkle:edSignature` and `length` values (they'll need these for the appcast)
   - Remind them to run `/appcast` next to update the appcast, and to upload the zip to GitHub Releases
