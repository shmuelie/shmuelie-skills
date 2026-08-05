# shmuelie-devenv

Developer-environment engineering: safe PowerShell automation, reliable shell
and WSL workflows, deployment scripts, interactive profiles, and local .NET MCP
servers.

**Version:** 1.0.0

## Install

```text
copilot plugin marketplace add shmuelie/shmuelie-skills
copilot plugin install shmuelie-devenv@shmuelie-skills
```

Update or remove:

```text
copilot plugin update shmuelie-devenv
copilot plugin uninstall shmuelie-devenv
```

## Skills

### deploy-scripts

`Deploy.ps1` patterns: MSBuild auto-detection via `vswhere`, architecture
detection, AppX loose-file layout assembly, `Add-AppxPackage -Register`,
`WinAppDeployCmd` remote deployment, and ADB for Android.

### local-mcp-server-development

Build local MCP servers in .NET that drive desktop applications via COM/WinRT:
STA dispatching, tool gating, ProgID probing, single-file publish for stdio
transport, and checking for an existing server before authoring a new one.

### powershell-profile

PowerShell profile engineering: profile architecture, PSReadLine configuration,
prompt customization, argument completers, PSReadLine predictors (and gating
expensive ones), versioned side-by-side module deployment, and terminal-mode
recovery after a crashed TUI.

### powershell-scripting

Idiomatic PowerShell for destructive and bulk scripts: `SupportsShouldProcess` +
`ConfirmImpact`, native `-WhatIf`/`-Confirm` instead of custom `-Execute` or
typed-`yes` gates, per-operation `$PSCmdlet.ShouldProcess`, anti-patterns to
replace, and preview-then-apply verification.

### shell-wsl

Reliable shell scripting and WSL: `exit` vs `return`, quoting, `mkdir -p`,
`set -euo pipefail`, WSL systemd detection, APT troubleshooting, one-connection
`tar`-over-SSH deployment, version-aware updaters, output quieting, embedded
device deployment, Cargo.lock reproducibility, and Rust/Cargo clippy patterns.

## Example requests

```text
Make this PowerShell cleanup script support -WhatIf correctly.
Why does my PSReadLine predictor freeze typing?
Create a deployment script that discovers MSBuild automatically.
Fix this shell script so set -e does not terminate the caller.
Build a local MCP server for a Windows desktop application.
```

## Platform notes

- PowerShell and profile guidance targets PowerShell 7.
- Shell guidance applies to Linux, macOS, WSL, and remote Unix-like targets.
- COM/WinRT MCP servers require Windows and a suitable .NET SDK.
- Deployment commands depend on the target platform's SDK and device tools.

## Changelog

Each skill has its own `CHANGELOG.md`; marketplace-wide history is in the
[repository changelog](../../../CHANGELOG.md).
