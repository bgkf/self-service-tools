### Delete-and-Reinstall - The Swift Version

A native Swift CLI tool that replaces the legacy zsh + IBM Notifier script for deleting and reinstalling managed applications via Jamf Self Service.

#### Installed File Structure

```
/Library/Management/DeleteReinstall/
├── delete-reinstall    # Compiled Swift binary (root:wheel, 755)
└── apps.json           # App list configuration (root:wheel, 644)
```

Installed by `DeleteReinstall-<version>.pkg`, built with `build_package.sh`.

##### What `delete-reinstall` Does

The binary presents a single persistent window that transitions through each step:

1. **Selection** — Displays a 3-column icon grid showing only apps that are currently installed. Each cell shows the app's real icon (resolved via `NSWorkspace`) and name. The "Delete & Reinstall" button is disabled until an app is selected.
2. **Confirmation** — Asks the user to confirm the action before proceeding. The branding icon shows a warning badge.
3. **Working** — The window displays a spinner and live status messages ("Quitting...", "Deleting...", "Reinstalling...") while the operation runs. No buttons are shown.
4. **Dock position capture** — Records the app's current dock section and slot position via `dockutil --find`, running in the logged-in user's context (`launchctl asuser`).
5. **Graceful quit** — If the app is running, sends `terminate()` via `NSRunningApplication`, waits up to 5 seconds, then falls back to `forceTerminate()`.
6. **Deletion** — Removes the app bundle from `/Applications/` using `FileManager.removeItem`. Requires root privileges.
7. **Reinstall** — Triggers the Jamf reinstall policy by running `/usr/local/bin/jamf policy -id <jamfPolicyID>`. The policy ID is read from `apps.json`. Requires root privileges.
8. **Dock restore** — Adds the app back to its original dock position via `dockutil --add`, running in the logged-in user's context.
9. **Result** — The window shows a success or error state with the corporate branding icon and a small SF Symbol status badge.

## UI Design

- **Single persistent window** — one window transitions between states instead of multiple popups.
- **Branding icon** — always visible in the top-left corner, with a small SF Symbol badge overlay for status (warning triangle, checkmark, spinner).
- **Icon grid** — app icons load asynchronously from `NSWorkspace.urlForApplication(withBundleIdentifier:)`, falling back to `/Applications/<bundleName>`, then to a generic SF Symbol.
- **Installed-only filtering** — the grid only shows apps that exist in `/Applications/` at launch time.

#### Runtime Context

- Runs as **root** via Jamf Self Service (needed for app deletion and `jamf policy`).
- UI displays in the logged-in user's GUI session (inherited from Self Service).
- User-context commands (dockutil) are executed via `launchctl asuser <uid> sudo -u <username>`.
- The logged-in user is detected with `SCDynamicStoreCopyConsoleUser`.

#### Configuration

`apps.json` defines the available applications:

```json
{
  "apps": [
    {
      "displayName": "Slack",
      "bundleName": "Slack.app",
      "bundleIdentifier": "com.tinyspeck.slackmacgap",
      "bundleId": "com.tinyspeck.slackmacgap",
      "jamfPolicyID": "645",
      "dockLabel": "Slack"
    }
  ]
}
```

| Field              | Purpose                                              |
|--------------------|------------------------------------------------------|
| `displayName`      | Shown in the icon grid and dialog messages            |
| `bundleName`       | The `.app` bundle name in `/Applications/`            |
| `bundleIdentifier` | Used to detect and quit the running process           |
| `bundleId`         | Used to resolve the app icon via `NSWorkspace`        |
| `jamfPolicyID`     | The Jamf Pro policy ID that reinstalls the app        |
| `dockLabel`        | The label `dockutil` uses to find/restore dock position |

To add or remove apps, edit `apps.json` — no recompile required.

#### Deployment

1. Run `./build_package.sh` to compile and package.
2. Upload the `.pkg` to Jamf Pro (Settings > Computer Management > Packages).
3. Attach `DeleteReinstall_SelfService.sh` as the script on a Self Service policy.


**Screen Shots**<br>
![image](https://github.com/bgkf/self-service-tools/blob/edeee594c20e582ad1a84cb2c80de0f7ec9be1ac/Delete-and-Reinstall/swift_version/assets/Screenshot_01.png)
<br>
![image](https://github.com/bgkf/self-service-tools/blob/edeee594c20e582ad1a84cb2c80de0f7ec9be1ac/Delete-and-Reinstall/swift_version/assets/Screenshot_02.png)
<br>
![image](https://github.com/bgkf/self-service-tools/blob/edeee594c20e582ad1a84cb2c80de0f7ec9be1ac/Delete-and-Reinstall/swift_version/assets/Screenshot_03.png)
<br>
![image](https://github.com/bgkf/self-service-tools/blob/edeee594c20e582ad1a84cb2c80de0f7ec9be1ac/Delete-and-Reinstall/swift_version/assets/Screenshot_04.png)
<br>
![image](https://github.com/bgkf/self-service-tools/blob/edeee594c20e582ad1a84cb2c80de0f7ec9be1ac/Delete-and-Reinstall/swift_version/assets/Screenshot_05.png)
