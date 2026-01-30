
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

# Apply with a restore point (recommended)
./Optimize-Windows11.ps1 -Profile Work -CreateRestorePoint
```

## Safety: restore points

Before making registry/service changes, consider creating a System Restore Point.

This script supports `-CreateRestorePoint` (best-effort). It may fail if System Protection is disabled; the script logs a warning and continues.

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
- Consider `-CreateRestorePoint` before applying changes.
- Some changes require restarting Explorer, signing out, or rebooting to fully apply.
- If you are unsure about a change, select only the feature you want instead of applying a whole profile.

Note: `SystemSnapshot` is included in profile defaults to capture before/after context in the run folder. It only records information (no system setting changes).

## Hardware/OEM performance tools (important)

On many high-performance laptops/desktops, OEM utilities can impact performance more than OS tweaks:

- Lenovo: Lenovo Vantage / Legion Toolkit
- ASUS: Armoury Crate
- Dell/Alienware: Dell Command / Alienware Command Center
- MSI: MSI Center
- HP: Omen Gaming Hub

These tools often control:

- MUX / GPU mode
- Thermal/fan profiles
- PL1/PL2 limits
- Vendor power plans and driver tuning

If you’re chasing gaming performance, validate OEM settings first (and make sure BIOS/chipset/GPU drivers are up to date).

### Lenovo Legion quick checklist

If you’re using a Lenovo Legion (or similar gaming laptop), these items usually have a bigger impact than Windows UI tweaks:

- **GPU mode / MUX**: Prefer **dGPU-only** (MUX on) for maximum FPS; use Hybrid only when you need battery life.
- **Thermal profile**: Set an appropriate performance mode (Balanced/Performance) and ensure fans aren’t constrained.
- **Power adapter**: Many Legion models throttle heavily on battery; benchmark while plugged in.
- **Windows power mode**: Keep Windows set to Best performance when gaming.
- **Driver/firmware order** (rule of thumb): BIOS/UEFI → chipset/platform drivers → GPU driver → OEM utility updates.
- **Overlays**: Disable unneeded overlays/recording (Xbox Game Bar/Game DVR, vendor overlays) if you see stutter.

Tip: Make one change at a time and compare FPS/frametime to avoid chasing placebo.

## Contextual Optimizations

Depending on your use case, consider these targeted settings. (Most of these are Windows/OEM settings and are not changed by this script.)

### Gaming & High Performance

- **VBS / Memory Integrity (security trade-off):** Disabling Virtualization-Based Security features (like “Memory integrity” under Windows Security → Device security → Core isolation) can improve performance on some systems, but it reduces protection against certain attacks. Only change this if you understand and accept the security impact.
- **Game Mode:** Enable Windows Game Mode to prioritize resources for the active game.
- **Hardware-accelerated GPU scheduling:** If supported, enabling it (Settings → System → Display → Graphics → Default graphics settings) can improve smoothness in some scenarios.

### Laptop (for example: Lenovo Legion)

- **Dynamic Refresh Rate (DRR):** If your panel supports it, set refresh rate to “Dynamic” to reduce power usage during static work while still allowing higher refresh during motion.
- **Power plans:** “Ultimate Performance” is helpful when plugged in; this project’s Gaming profile attempts to select it. You can also duplicate it manually:

```powershell
powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61
```

- **Hibernate vs Modern Standby:** If you see battery drain while sleeping in transit, enabling Hibernate can help:

```powershell
powercfg /hibernate on
```

### Work / Development PC

- **Indexer optimization:** If you keep Windows Search enabled, consider excluding large dependency trees (for example: `node_modules`, build outputs, package caches) from indexing.
- **Focus / Focus Assist:** Scheduling Focus times can reduce notification-related background activity during work blocks.

### Server (headless / home lab)

- **Processor scheduling:** Consider setting processor scheduling to prioritize “Background services” (System Properties → Advanced → Performance → Advanced) for server-style workloads.
- **Visuals:** Use “Adjust for best performance” to strip UI effects if the machine is used locally with a GUI.

## Automation (one-click runner)

If you don’t want to remember commands, use the included wrapper:

```powershell
# Preview
./Run-Optimize.ps1 -Profile Gaming -WhatIf

# Apply Gaming defaults with a restore point
./Run-Optimize.ps1 -Profile Gaming -CreateRestorePoint

# Revert the last run
./Run-Optimize.ps1 -Revert
```

## License

Licensed under the GNU General Public License v3.0 (GPL-3.0). See `.github/LICENSE`.