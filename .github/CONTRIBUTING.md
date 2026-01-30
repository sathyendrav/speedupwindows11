
# Contributing

Thanks for helping improve this project.

## Ground rules

- Safety first: no changes that disable Windows Defender or Windows Update.
- Prefer reversible changes: every state-changing feature should capture prior state so `-Revert` can restore it.
- Keep changes minimal and well-scoped.

## How to propose changes

1. Open an issue describing:
 - Windows version/build
	- PowerShell version
	- What you ran (profile/features)
	- Expected vs actual behavior
	- Any errors/log snippets (remove sensitive info)

2. If you’re submitting a PR:
	- Describe the intent and user impact.
	- Include before/after examples of `-WhatIf` output when relevant.
	- Add or update documentation in `.github/README.md` when behavior changes.

## Development and testing

Recommended checks before submitting:

```powershell
# Syntax-only parse (no execution)
$path = Join-Path (Get-Location) 'Optimize-Windows11.ps1'
$t = $null; $e = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$t, [ref]$e)
$e

# PSScriptAnalyzer (if installed)
Invoke-ScriptAnalyzer -Path $path -Severity Warning,Error

# Dry run (safe)
./Optimize-Windows11.ps1 -Profile Gaming -WhatIf
```

## Style

- Use `Set-StrictMode -Version Latest` compatible patterns.
- Prefer `ShouldProcess` for state-changing operations.
- Keep feature names and behavior consistent across profiles.

