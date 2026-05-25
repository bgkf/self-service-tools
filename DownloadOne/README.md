# DownloadOne

A native Swift macOS app that replaces the legacy bash + IBM Notifier script for downloading a single Script or Extension Attribute from Jamf Dev directly to `/Users/Shared/`.

I test in a development instance of Jamf Pro and us this tool to download files in the [git4jamfpro](https://github.com/bgkf/git4jamfpro) format.

## Installed File Structure

```
/Library/Management/DownloadOne/
└── DownloadOne    # Compiled Swift binary (root:wheel, 755)
```

Installed by `DownloadOne-<version>.pkg`, built with `build_package.sh`.

## What `DownloadOne` Does

The binary presents a single persistent window that transitions through each step:

1. **Input** — Displays a form with a segmented picker (Script / Extension Attribute) and a text field for the numeric Jamf item ID. The "Download" button is disabled until the ID field is non-empty. A "Quit" button is always available.
2. **Authenticating** — Shows a spinner with the status message "Authenticating with Jamf Dev…" while the OAuth2 client credentials token request is in flight.
3. **Downloading** — Shows a spinner with "Downloading [Script | Extension Attribute] \<id\>…" while the API request runs.
4. **Writing** — Shows a spinner with "Writing files to /Users/Shared/\<name\>/…" while the XML record and script file are written to disk.
5. **Result** — Shows a success or error state with the branding icon, an SF Symbol badge (checkmark or exclamation triangle), the resolved item name, and the output path. An "Open in Finder" button reveals the output directory. A "Done" button quits the app.

## UI Design

- **Single persistent window** — one window transitions between states instead of multiple popups.
- **Branding icon** — loaded from the Self Service branding image at `~/Library/Application Support/com.jamfsoftware.selfservice.mac/Documents/Images/brandingimage.png`, falling back to an SF Symbol (`square.and.arrow.down`).
- **SF Symbol badge overlay** — a small badge positioned over the branding icon corner: animated `arrow.down.circle` while working, green `checkmark.circle.fill` on success, yellow `exclamationmark.triangle.fill` on error.
- **Fixed window size** — 480 × 320 pt, non-resizable.

## Runtime Context

- Runs as **root** via Jamf Self Service (needed to `chown` downloaded files).
- UI displays in the logged-in user's GUI session (inherited from Self Service).
- The logged-in user is detected with `SCDynamicStoreCopyConsoleUser`.
- `chown` is performed via `FileManager.setAttributes` after writing files.

## Credential Handling

Jamf OAuth2 credentials (`client_id` and `client_secret`) are passed in via Jamf script parameters 4 and 5, exactly as in the original script. The binary reads them from `CommandLine.arguments`:

```
DownloadOne <param1> <param2> <param3> <client_id> <client_secret>
```

- `CommandLine.arguments[4]` → `clientId`
- `CommandLine.arguments[5]` → `clientSecret`

No credentials are stored on disk.

## Configuration

No configuration file is needed. The item type (Script or Extension Attribute) and numeric ID are selected at runtime through the UI.

| Parameter       | Source                         | Purpose                                       |
|-----------------|--------------------------------|-----------------------------------------------|
| `client_id`     | Jamf script parameter `$4`     | OAuth2 client ID for Jamf Dev API             |
| `client_secret` | Jamf script parameter `$5`     | OAuth2 client secret for Jamf Dev API         |
| Item type       | UI segmented picker            | Determines API endpoint (script vs. EA)       |
| Item ID         | UI text field                  | Numeric Jamf Pro ID of the item to download   |

## Deployment

1. Run `./build_package.sh` to compile (`swift build -c release`) and package.
2. Upload the `.pkg` to Jamf Pro (Settings > Computer Management > Packages).
3. Attach the package + a Self Service policy script that passes `$4`/`$5` to the binary.
