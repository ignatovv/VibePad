# PadCrafter JSON Export

Generate a PadCrafter-compatible JSON file from VibePad's current button mappings for use at padcrafter.com.

## Instructions

1. **Read the current mappings** from `VibePad/InputMapper.swift`. Extract:
   - `defaultDescriptions` — base layer button descriptions
   - `l1Descriptions` — L1 layer button descriptions
   - Any buttons in `defaultMappings` or `l1Mappings` that lack descriptions (use the code comment as a fallback)

2. **Map VibePad button names to PadCrafter keys** using this table:

   | GamepadButton (VibePad)   | PadCrafter key     |
   |---------------------------|--------------------|
   | buttonA                   | aButton            |
   | buttonB                   | bButton            |
   | buttonX                   | xButton            |
   | buttonY                   | yButton            |
   | dpadUp                    | dpadUp             |
   | dpadDown                  | dpadDown           |
   | dpadLeft                  | dpadLeft           |
   | dpadRight                 | dpadRight          |
   | leftShoulder              | leftBumper         |
   | rightShoulder             | rightBumper        |
   | leftTrigger               | leftTrigger        |
   | rightTrigger              | rightTrigger       |
   | leftThumbstickButton      | leftStickClick     |
   | rightThumbstickButton     | rightStickClick    |
   | buttonMenu                | startButton        |
   | buttonOptions             | backButton         |

3. **Build two templates** in a single PadCrafter JSON:

   **Template 1 — "VibePad":**
   - Populate every PadCrafter key. Use the description from `defaultDescriptions` if present, otherwise `""`.
   - Force `leftBumper` = `"Layer Modifier (L1)"` (L1 is the layer toggle, not a regular mapping).
   - Set `leftStick` = `"Arrow Keys"` and `rightStick` = `"Scroll"` (these are PadCrafter-specific fields for the analog sticks, separate from the click buttons).

   **Template 2 — "L1 Layer (Hold L1)":**
   - Only include buttons that have entries in `l1Descriptions` (or `l1Mappings`).
   - All other buttons should be `""`.
   - Set `rightStick` = `"Prev/Next App"` (L1+right stick does Prev/Next App, matching D-pad behavior).

4. **Output format** — the JSON structure must be exactly:
   ```json
   {
     "PadCrafter": {
       "": [
         {
           "templatename": "VibePad",
           "buttons": {
             "leftTrigger": "...",
             "rightTrigger": "...",
             "leftBumper": "Layer Modifier (L1)",
             "rightBumper": "...",
             "aButton": "...",
             "bButton": "...",
             "xButton": "...",
             "yButton": "...",
             "dpadUp": "...",
             "dpadDown": "...",
             "dpadLeft": "...",
             "dpadRight": "...",
             "leftStickClick": "...",
             "rightStickClick": "...",
             "startButton": "...",
             "backButton": "...",
             "leftStick": "Arrow Keys",
             "rightStick": "Scroll"
           }
         },
         {
           "templatename": "L1 Layer (Hold L1)",
           "buttons": {
             "leftTrigger": "",
             "rightTrigger": "",
             "leftBumper": "",
             "rightBumper": "",
             "aButton": "",
             "bButton": "...",
             "xButton": "",
             "yButton": "",
             "dpadUp": "",
             "dpadDown": "",
             "dpadLeft": "",
             "dpadRight": "",
             "leftStickClick": "",
             "rightStickClick": "",
             "startButton": "",
             "backButton": "",
             "leftStick": "",
             "rightStick": "Prev/Next App"
           }
         }
       ]
     }
   }
   ```

5. **Write the JSON** to the scratchpad directory and **display the full JSON** in the response so the user can copy-paste it.

6. **Build the padcrafter.com URL:**
   1. Collect all PadCrafter button keys from the templates built in step 3 (e.g. `aButton`, `bButton`, `leftStick`, etc.).
   2. For each button key, gather its value across all templates into an ordered list (template 1 first, then template 2).
   3. Trim trailing empty strings from the list (e.g. `["Accept", ""]` → `["Accept"]`; `["", "Delete"]` stays as-is).
   4. If ALL values are empty after trimming, skip the button entirely (don't include it as a query param).
   5. Join the remaining values with `|` (e.g. `Accept` or `Cancel|Delete`).
   6. Start with `templates=VibePad|L1 Layer (Hold L1)`.
   7. Append each non-empty button as `&key=value`.
   8. URL-encode each param value: spaces → `+`, `|` → `%7C`, parentheses and other special chars → `%XX` as needed. Use standard percent-encoding.
   9. Final URL: `https://www.padcrafter.com/index.php?templates=...&aButton=...&bButton=...`
   10. Display the URL in the response so the user can click it to open their layout directly on padcrafter.com.
