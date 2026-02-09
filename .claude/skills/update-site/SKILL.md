---
name: update-site
description: Update the VibePad website with new DMG and appcast entry
disable-model-invocation: false
---

Update the VibePad website: upload the new DMG for the download button and add an appcast entry for Sparkle auto-updates.

## Gathering info

Ask the user for any values not provided as arguments or inferrable from context:

1. **Version** (e.g. `1.1`) — the `sparkle:shortVersionString`
2. **Build number** (e.g. `2`) — the `sparkle:version`
3. **EdDSA signature** — the `sparkle:edSignature="..."` value from `sign_update`
4. **File length** in bytes — the `length="..."` value from `sign_update`

If the user just ran `/release`, these values should be available in the conversation context — use them without asking again.

## Steps

1. **Read the current appcast**:
   Read `/Users/vyuignatiov/code/vibepad-site/appcast.xml`.

2. **Add a new `<item>` entry** inside `<channel>`, as the first item (newest first). Use this format:
```xml
    <item>
      <title>Version {VERSION}</title>
      <pubDate>{RFC 2822 date, e.g. "Sat, 08 Feb 2026 12:00:00 -0800"}</pubDate>
      <sparkle:version>{BUILD_NUMBER}</sparkle:version>
      <sparkle:shortVersionString>{VERSION}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <enclosure
        url="https://vibepad.now/assets/VibePad.dmg"
        type="application/x-apple-diskimage"
        sparkle:edSignature="{ED_SIGNATURE}"
        length="{FILE_LENGTH}"
      />
    </item>
```
   Use the current date/time for `<pubDate>`. Insert the new item before any existing items.

3. **Copy the DMG** to the website assets (stable filename for the download button):
```bash
cp "/Users/vyuignatiov/code/VibePad/VibePad-${VERSION}.dmg" "/Users/vyuignatiov/code/vibepad-site/assets/VibePad.dmg"
```

4. **Commit and push** the vibepad-site repo (auto-deploys on push):
```bash
cd ~/code/vibepad-site && git add appcast.xml assets/VibePad.dmg && git commit -m "Update to VibePad ${VERSION}" && git push
```

5. **Report to the user**:
   - Show the updated appcast entry
   - Remind them to verify at `https://vibepad.now/appcast.xml`
