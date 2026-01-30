
# Security Policy

## Reporting a vulnerability

If you believe you’ve found a security issue (for example: privilege escalation, unsafe download/execute behavior, credential exposure, or unsafe file permissions), please **do not** open a public issue with exploit details.

Instead:

1. Prepare a short report including:
	- What you found
	- Steps to reproduce
	- Expected vs actual behavior
	- Any relevant logs (redact personal/system details)

2. Contact the maintainer privately via the repository’s security contact mechanism (GitHub “Report a vulnerability”), or open an issue with **minimal** detail and request a private channel.

## Supported versions

This project only supports the latest version on the default branch.

## Scope

Security reports should focus on:

- Script execution safety
- Registry/service modification safety
- Backup/revert integrity
- Any networking/download behavior (if added in the future)

