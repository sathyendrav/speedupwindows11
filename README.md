# speedupwindows11

PowerShell script to apply a (safe-ish) set of Windows 11 performance and quality-of-life tweaks with per-device profiles, optional interactivity, and an audit/revert trail.

Main entry point: `Optimize-Windows11.ps1`

## Quick start

```powershell
# Preview changes (recommended)
./Optimize-Windows11.ps1 -Profile Gaming -WhatIf

# Interactive mode
./Optimize-Windows11.ps1 -Interactive

# One-click wrapper (same options, easier entry point)
./Run-Optimize.ps1 -Profile Gaming -WhatIf
```

## Optimize.ps1 (simple script)

This repo also includes `Optimize.ps1`, a small “one shot” script that applies a handful of common tweaks.

What it does:

- Attempts to create a System Restore Point via `Checkpoint-Computer`
- Duplicates the “Ultimate Performance” power plan GUID
- Sets a telemetry policy value (`AllowTelemetry=0`)
- Enables Windows Game Mode
- Hides taskbar Widgets and Chat

Safety notes:

- `Optimize.ps1` does **not** support `-WhatIf` and does **not** capture per-feature state for `-Revert`.
- Some settings (especially policy keys under `HKLM:\SOFTWARE\Policies\...`) may be managed by your organization/MDM and may be overwritten.
- Restore point creation can fail if System Protection is disabled.

Run it (Administrator):

```powershell
./Optimize.ps1
```

## Documentation

See `.github/README.md` for full details, including the “Contextual Optimizations” section.
