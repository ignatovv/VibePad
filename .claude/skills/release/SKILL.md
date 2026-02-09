---
name: release
description: Build, notarize, sign, and publish a release of VibePad
disable-model-invocation: false
---

Build a release-ready VibePad: notarize with Apple, sign with Sparkle EdDSA, create a GitHub Release. Optionally bump the version first.

## Arguments

The user may pass a version string (e.g. `/release 1.1`) to bump MARKETING_VERSION before building. If no version is given, use the current version from the project.

## Steps

1. **Check terminal permissions** — DMG creation requires your terminal to have two macOS permissions. Ask the user to confirm they've granted both before proceeding:
   - **Automation → Finder**: System Settings → Privacy & Security → Automation → [your terminal app] → enable Finder
   - **Full Disk Access**: System Settings → Privacy & Security → Full Disk Access → enable [your terminal app]

   Use AskUserQuestion to ask: "Before we start, please make sure your terminal has these permissions enabled in System Settings → Privacy & Security: (1) Automation → Finder, (2) Full Disk Access. Are both enabled?" — do NOT proceed until the user confirms.

2. **If a version argument was provided**, update MARKETING_VERSION in the VibePad target's Debug and Release build configurations in `VibePad.xcodeproj/project.pbxproj`. Also bump CURRENT_PROJECT_VERSION by 1 from its current value. Use the Edit tool — only change the two VibePad target configs (IDs `3DCDC9722F36A1750063EE37` and `3DCDC9732F36A1750063EE37`), not the test targets.

3. **Delete stale config** so testers get the first-launch onboarding experience:
```bash
rm -f ~/.vibepad/config.json
```

4. **Archive and export** (Developer ID signing, timestamps, deep-signs embedded frameworks):
```bash
# Archive
xcodebuild archive -scheme VibePad -destination 'platform=macOS' \
  -archivePath /tmp/VibePad.xcarchive 2>&1 | tail -5

# Export with Developer ID signing
xcodebuild -exportArchive \
  -archivePath /tmp/VibePad.xcarchive \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath /tmp/VibePad-export 2>&1 | tail -5
```

5. **Set the app path** from the export:
```bash
APP_PATH="/tmp/VibePad-export/VibePad.app"
```

6. **Read the version from the built app** for naming:
```bash
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$APP_PATH/Contents/Info.plist")
echo "Version: $VERSION ($BUILD)"
```

7. **Verify signing** before notarizing — check deep signing, no `get-task-allow`, and Sparkle helpers:
```bash
codesign --verify --deep --strict "$APP_PATH"
codesign -d --entitlements - "$APP_PATH" 2>&1  # must NOT contain get-task-allow
codesign -dvv "$APP_PATH/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate" 2>&1 | grep Authority
```
If any check fails, stop and report to the user.

8. **Create pretty DMG** with branded background and Applications drop link (NOT zip — Finder's Archive Utility corrupts code signatures when extracting zips):
```bash
STAGING="/tmp/VibePad-dmg-staging"
rm -rf "$STAGING" && mkdir -p "$STAGING"
cp -R "$APP_PATH" "$STAGING/"
chflags -R nouchg "$STAGING/"          # unlock files (Sonoma+ uchg bug)

create-dmg \
  --volname "VibePad" \
  --volicon "$APP_PATH/Contents/Resources/AppIcon.icns" \
  --background "/Users/vyuignatiov/code/VibePad/dmg-resources/background@2x.png" \
  --window-pos 200 120 \
  --window-size 660 400 \
  --icon-size 128 \
  --text-size 14 \
  --icon "VibePad.app" 180 220 \
  --hide-extension "VibePad.app" \
  --app-drop-link 480 220 \
  "/Users/vyuignatiov/code/VibePad/VibePad-${VERSION}.dmg" \
  "$STAGING/"
```

9. **Notarize the DMG** (DMGs can be submitted directly — no zip wrapper needed):
```bash
xcrun notarytool submit "/Users/vyuignatiov/code/VibePad/VibePad-${VERSION}.dmg" --keychain-profile "vibepad" --wait
xcrun stapler staple "/Users/vyuignatiov/code/VibePad/VibePad-${VERSION}.dmg"
```
If notarization fails, stop and report the error to the user. Use `xcrun notarytool log <submission-id> --keychain-profile "vibepad"` to get the detailed error log.

10. **Sign with Sparkle's EdDSA key**:
```bash
SPARKLE_BIN=$(ls -td /Users/vyuignatiov/Library/Developer/Xcode/DerivedData/VibePad-*/SourcePackages/artifacts/sparkle/Sparkle/bin 2>/dev/null | head -1)
"$SPARKLE_BIN/sign_update" "/Users/vyuignatiov/code/VibePad/VibePad-${VERSION}.dmg"
```
This prints `sparkle:edSignature="..."` and `length="..."` — save these values.

11. **Create git tag and GitHub Release**:
```bash
git tag v${VERSION}
git push origin v${VERSION}
gh release create v${VERSION} "/Users/vyuignatiov/code/VibePad/VibePad-${VERSION}.dmg" --title "VibePad ${VERSION}" --generate-notes
```

12. **Report to the user and revoke permissions**:
   - Path to the signed DMG
   - The version and build number
   - The `sparkle:edSignature` and `length` values (they'll need these for the appcast)
   - The GitHub Release URL
   - Remind them to run `/appcast` next to update the auto-update feed
   - **Security reminder**: Ask the user to revoke the temporary permissions they granted in step 1: go to System Settings → Privacy & Security and disable **Automation → Finder** and **Full Disk Access** for their terminal app. These are only needed during the release process and should not stay enabled.
