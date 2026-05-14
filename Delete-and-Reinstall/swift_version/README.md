### Delete-and-Reinstall - The Swift Version
A native Swift CLI tool that replaces the legacy zsh + IBM Notifier script for deleting and reinstalling managed applications via Jamf Self Service.

#### Installed File Structure

```
/Library/Management/DeleteReinstall/
├── delete-reinstall    # Compiled Swift binary (root:wheel, 755)
└── apps.json           # App list configuration (root:wheel, 644)
```

Installed by `DeleteReinstall-<version>.pkg`, built with `build_package.sh`.

#### What `delete-reinstall` Does

The binary presents a single persistent window that transitions through each step:

1. **Selection** — Displays a dropdown populated from `apps.json`. The user picks an application and clicks "Delete & Reinstall".
2. **Validation** — Checks that the selected app exists in `/Applications/`. If not, the window transitions to an error state.
3. **Confirmation** — Asks the user to confirm the action before proceeding.
4. **Dock position capture** — Records the app's current dock section and slot position via `dockutil --find`, running in the logged-in user's context (`launchctl asuser`).
5. **Graceful quit** — If the app is running, sends `terminate()` via `NSRunningApplication`, waits up to 5 seconds, then falls back to `forceTerminate()`.
6. **Deletion** — Removes the app bundle from `/Applications/` using `FileManager.removeItem`. Requires root privileges.
7. **Reinstall** — Triggers the Jamf reinstall policy by running `/usr/local/bin/jamf policy -id <jamfPolicyID>`. The policy ID is read from `apps.json`. Requires root privileges.
8. **Dock restore** — Adds the app back to its original dock position via `dockutil --add`, running in the logged-in user's context.
9. **Result** — The window shows a success or error state with the corporate branding icon and a small SF Symbol status badge.

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
      "jamfPolicyID": "645",
      "dockLabel": "Slack"
    }
  ]
}
```

| Field              | Purpose                                              |
|--------------------|------------------------------------------------------|
| `displayName`      | Shown in the dropdown and dialog messages             |
| `bundleName`       | The `.app` bundle name in `/Applications/`            |
| `bundleIdentifier` | Used to detect and quit the running process           |
| `jamfPolicyID`     | The Jamf Pro policy ID that reinstalls the app        |
| `dockLabel`        | The label `dockutil` uses to find/restore dock position |

To add or remove apps, edit `apps.json` — no recompile required.

#### Deployment

1. Run `./build_package.sh` to compile and package.
2. Upload the `.pkg` to Jamf Pro (Settings > Computer Management > Packages).
3. Attach `DeleteReinstall_SelfService.sh` as the script on a Self Service policy.

**Screen Shots**<br>
![image](https://github.com/bgkf/self-service-tools/blob/4590af663f20f6cc79a8ee3773ecc3e87f2ba708/Delete-and-Reinstall/swift_version/assets/Screenshot_01.png)
<br>
![image](https://github.com/bgkf/self-service-tools/blob/4590af663f20f6cc79a8ee3773ecc3e87f2ba708/Delete-and-Reinstall/swift_version/assets/Screenshot_02.png)
<br>
![image](https://github.com/bgkf/self-service-tools/blob/4590af663f20f6cc79a8ee3773ecc3e87f2ba708/Delete-and-Reinstall/swift_version/assets/Screenshot_03.png)
<br>
![image](https://github.com/bgkf/self-service-tools/blob/4590af663f20f6cc79a8ee3773ecc3e87f2ba708/Delete-and-Reinstall/swift_version/assets/Screenshot_05.png)
<br>
![image](https://github.com/bgkf/self-service-tools/blob/4590af663f20f6cc79a8ee3773ecc3e87f2ba708/Delete-and-Reinstall/swift_version/assets/Screenshot_06.png)
<br>
![image](https://github.com/bgkf/self-service-tools/blob/4590af663f20f6cc79a8ee3773ecc3e87f2ba708/Delete-and-Reinstall/swift_version/assets/Screenshot_07.png)
<br>
![image](https://github.com/bgkf/self-service-tools/blob/4590af663f20f6cc79a8ee3773ecc3e87f2ba708/Delete-and-Reinstall/swift_version/assets/Screenshot_09.png)
<br>




