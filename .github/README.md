
# speedupwindows11

`speedupwindows11` is a PowerShell script that applies a (safe-ish) set of Windows 11 performance and quality-of-life tweaks with per-device profiles, optional interactivity, and an audit/revert trail.

The main entry point is `Optimize-Windows11.ps1`.

## What it does

- Provides profiles: **Laptop**, **Work**, **Gaming**.
- Lets you apply specific **features** (taskbar toggles, visual effects, Game DVR, power plan, search indexing, etc.).
- Supports `-WhatIf` (dry run) via `SupportsShouldProcess`.
- Captures per-run state to a timestamped backup folder and supports `-Revert`.

Guard rails:

- Does **not** disable Windows Defender.
- Does **not** disable Windows Update.

## Requirements

- Windows 11 (build 22000+ recommended)
- Run from an **elevated** PowerShell session (Administrator)
- PowerShell 5.1+ (Windows PowerShell) or PowerShell 7+ (tested behavior may vary by host)

## Quick start

1. Open PowerShell as Administrator
2. From the repo folder:

```powershell
# Show planned actions only
./Optimize-Windows11.ps1 -Profile Gaming -WhatIf

# Interactive mode (prompts for profile/features)
./Optimize-Windows11.ps1 -Interactive
```

## Features

Supported `-Features` values:

- `Widgets`
- `Chat`
- `CopilotButton`
- `VisualEffects`
- `GameDVR`
- `PowerPlan`
- `SearchIndexing`
- `StartupAppsReport`
- `SystemSnapshot`
- `DeliveryOptimization`
- `FastStartup`
- `QuietMode`

## Backups and revert

By default, backups/logs are written under `C:\OptimizeBackup` in a per-run folder, for example:

`C:\OptimizeBackup\2026-01-30_153012\`

Revert the most recent run:

```powershell
./Optimize-Windows11.ps1 -Revert
```

Revert a specific run:

```powershell
./Optimize-Windows11.ps1 -Revert -BackupPath 'C:\OptimizeBackup\2026-01-30_153012'
```

## Safety notes

- Prefer running with `-WhatIf` first.
- Some changes require restarting Explorer, signing out, or rebooting to fully apply.
- If you are unsure about a change, select only the feature you want instead of applying a whole profile.

## License

Licensed under the GNU General Public License v3.0 (GPL-3.0). See `.github/LICENSE`.