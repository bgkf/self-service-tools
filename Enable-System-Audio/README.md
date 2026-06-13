## Self Service Tool to Enable System Audio for Notion

### Overview

A compiled Swift binary deployed via Jamf Self Service that temporarily elevates the current user to admin, deep-links directly to the Screen Recording privacy pane in System Settings, displays a floating overlay window with step-by-step instructions for enabling System Audio Recording Only for Notion, and automatically reverts the user to standard after a 2-minute countdown.

---

### Architecture

```
NotionAudioEnabler/
├── NotionAudioEnabler.swift        # Main entry point
├── ElevationManager.swift          # Admin promotion/demotion via dseditgroup
├── SystemSettingsLauncher.swift    # Deep link to Screen Recording pane
├── OverlayWindowController.swift   # Floating instruction window + countdown
├── TimerManager.swift              # 2-minute revert timer with early exit logic
└── Info.plist                      # Bundle metadata
```

Elevation is done by calling a **privileged helper** or a **pre-staged sudoers rule** that allows the specific binary to call `dseditgroup` without a password prompt.

**Screen Shots**<br>
![image](https://github.com/bgkf/self-service-tools/blob/8db13f33b009bad6080dc17d56f29bdb383fb576/Enable-System-Audio/assets/settings.png)
<br>
![image](https://github.com/bgkf/self-service-tools/blob/8db13f33b009bad6080dc17d56f29bdb383fb576/Enable-System-Audio/assets/tool.png)
