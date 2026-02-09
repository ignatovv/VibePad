---
name: release
description: Build, notarize, sign, and publish a release of VibePad
disable-model-invocation: false
---

Build a release-ready VibePad: notarize with Apple, sign with Sparkle EdDSA, create a GitHub Release. Optionally bump the version first.

## Arguments

The user may pass a version string (e.g. `/release 1.1`) to bump MARKETING_VERSION before building. If no version is given, use the current version from the project.

## Steps

1. **If a version argument was provided**, update MARKETING_VERSION in the VibePad target's Debug and Release build configurations in `VibePad.xcodeproj/project.pbxproj`. Also bump CURRENT_PROJECT_VERSION by 1 from its current value. Use the Edit tool — only change the two VibePad target configs (IDs `3DCDC9722F36A1750063EE37` and `3DCDC9732F36A1750063EE37`), not the test targets.

2. **Delete stale config** so testers get the first-launch onboarding experience:
```bash
rm -f ~/.vibepad/config.json
```

3. **Archive and export** (Developer ID signing, timestamps, deep-signs embedded frameworks):
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

4. **Set the app path** from the export:
```bash
APP_PATH="/tmp/VibePad-export/VibePad.app"
```

5. **Read the version from the built app** for naming:
```bash
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$APP_PATH/Contents/Info.plist")
echo "Version: $VERSION ($BUILD)"
```

6. **Verify signing** before notarizing — check deep signing, no `get-task-allow`, and Sparkle helpers:
```bash
codesign --verify --deep --strict "$APP_PATH"
codesign -d --entitlements - "$APP_PATH" 2>&1  # must NOT contain get-task-allow
codesign -dvv "$APP_PATH/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate" 2>&1 | grep Authority
```
If any check fails, stop and report to the user.

7. **Create DMG** from the notarized+stapled app (NOT zip — Finder's Archive Utility corrupts code signatures when extracting zips):
```bash
hdiutil create -volname "VibePad" -srcfolder "$APP_PATH" -ov -format UDZO "/Users/vyuignatiov/code/VibePad/VibePad-${VERSION}.dmg"
```

8. **Notarize the DMG** (DMGs can be submitted directly — no zip wrapper needed):
```bash
xcrun notarytool submit "/Users/vyuignatiov/code/VibePad/VibePad-${VERSION}.dmg" --keychain-profile "vibepad" --wait
xcrun stapler staple "/Users/vyuignatiov/code/VibePad/VibePad-${VERSION}.dmg"
```
If notarization fails, stop and report the error to the user. Use `xcrun notarytool log <submission-id> --keychain-profile "vibepad"` to get the detailed error log.

9. **Sign with Sparkle's EdDSA key**:
```bash
SPARKLE_BIN=$(ls -td /Users/vyuignatiov/Library/Developer/Xcode/DerivedData/VibePad-*/SourcePackages/artifacts/sparkle/Sparkle/bin 2>/dev/null | head -1)
"$SPARKLE_BIN/sign_update" "/Users/vyuignatiov/code/VibePad/VibePad-${VERSION}.dmg"
```
This prints `sparkle:edSignature="..."` and `length="..."` — save these values.

10. **Create git tag and GitHub Release**:
```bash
git tag v${VERSION}
git push origin v${VERSION}
gh release create v${VERSION} "/Users/vyuignatiov/code/VibePad/VibePad-${VERSION}.dmg" --title "VibePad ${VERSION}" --generate-notes
```

11. **Report to the user**:
   - Path to the signed DMG
   - The version and build number
   - The `sparkle:edSignature` and `length` values (they'll need these for the appcast)
   - The GitHub Release URL
   - Remind them to run `/appcast` next to update the auto-update feed
