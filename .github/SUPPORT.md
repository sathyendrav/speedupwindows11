
# Support

## Getting help

Open an issue and include:

- Windows version/build (e.g., 22631.x)
- PowerShell version (`$PSVersionTable.PSVersion`)
- Whether you ran as Administrator
- The exact command you ran (profile/features and `-WhatIf`/`-Revert`)
- Any relevant output or log snippets (redact sensitive info)

## Common first steps

```powershell
# Preview actions
./Optimize-Windows11.ps1 -Profile Gaming -WhatIf

# Apply only one feature to isolate issues
./Optimize-Windows11.ps1 -Profile Work -Features VisualEffects -WhatIf

# Revert the last run
./Optimize-Windows11.ps1 -Revert
```

## What this project will not do

- Provide support for disabling Windows Defender or Windows Update.
- Provide support for bypassing organization policies (Group Policy/MDM).

