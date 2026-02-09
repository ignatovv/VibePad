---
name: appcast
description: Add a new version entry to the Sparkle appcast.xml for VibePad updates
disable-model-invocation: false
---

Add a new release entry to the appcast.xml at `~/code/vibepad-site/appcast.xml`.

## Gathering info

Ask the user for any values not provided as arguments or inferrable from context:

1. **Version** (e.g. `1.1`) — the `sparkle:shortVersionString`
2. **Build number** (e.g. `2`) — the `sparkle:version`
3. **Download URL** — `https://github.com/ignatovv/VibePad/releases/download/v{VERSION}/VibePad-{VERSION}.zip`
4. **EdDSA signature** — the `sparkle:edSignature="..."` value from `sign_update`
5. **File length** in bytes — the `length="..."` value from `sign_update`

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
        url="https://github.com/ignatovv/VibePad/releases/download/v{VERSION}/VibePad-{VERSION}.zip"
        type="application/octet-stream"
        sparkle:edSignature="{ED_SIGNATURE}"
        length="{FILE_LENGTH}"
      />
    </item>
```
   Use the current date/time for `<pubDate>`. Insert the new item before any existing items.

3. **Deploy the site**:
```bash
cd ~/code/vibepad-site && wrangler deploy
```

4. **Report to the user**:
   - Show the updated appcast entry
   - Confirm the deploy succeeded
   - Remind them to verify at `https://vibepad.now/appcast.xml`
