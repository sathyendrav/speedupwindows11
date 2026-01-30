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

## Documentation

See `.github/README.md` for full details.
