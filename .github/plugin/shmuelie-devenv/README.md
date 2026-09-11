# shmuelie-devenv

Developer-environment engineering: safe PowerShell automation, reliable shell
and WSL workflows, deployment scripts, interactive profiles, local .NET MCP
servers, and read-only threat-model file analysis.

**Version:** 1.4.0

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

### azure-pipelines-powershell

Azure Pipelines expression phases, safe PowerShell value binding, explicit
publication gates, and project-owned package versions, with pure no-network
transformation examples.

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
Completion-cache guidance avoids per-startup version probes by checking the
resolved executable, cache timestamps, and a configurable maximum age.
Launch guidance distinguishes shell resolution, native executables, shims,
child-process lifetime, and fresh toolchain environments.
Managed-configuration guidance preserves link ownership and backups, isolates
writer probes, and stops for explicit review of configuration drift.
Shared-cache guidance separates freshness, owner lifetime, atomic snapshot
publication, and acknowledged delivery, with a disposable coordination lab.
Terminal reporting rejects unsafe payloads and distinguishes popup descendants
from ordinary owners before any shared cache or status access.

### powershell-scripting

Idiomatic PowerShell for destructive and bulk scripts: `SupportsShouldProcess` +
`ConfirmImpact`, native `-WhatIf`/`-Confirm` instead of custom `-Execute` or
typed-`yes` gates, per-operation `$PSCmdlet.ShouldProcess`, anti-patterns to
replace, and preview-then-apply verification.

### powershell-gallery-publishing

Publish PowerShell modules to the PowerShell Gallery from a tag-triggered GitHub
Actions workflow: `<Module>-vX.Y.Z` release tags with a tag-vs-manifest version
check, glob-scoped API keys behind a named environment, cutting a release, the
"no tag workflows when more than three tags are pushed at once" gotcha, and
first-come module-name reservation.

### shell-wsl

Reliable shell scripting and WSL: `exit` vs `return`, quoting, `mkdir -p`,
`set -euo pipefail`, WSL systemd detection, APT troubleshooting, one-connection
`tar`-over-SSH deployment, version-aware updaters, output quieting, embedded
device deployment, Cargo.lock reproducibility, and Rust/Cargo clippy patterns.
Includes tmux server, session, and child-process environment boundaries.

### threat-model-files

Read-only `.tm7` serialization and namespace inspection, nested properties,
diagram-scoped relationships, STRIDE/triage reporting, and explicit unknowns.
Includes a reduced synthetic fixture and a profile-gated parsing example.

### windows-self-hosted-runner

Clean-image Windows runner bootstrap, workload-compatible toolchains, actual
service identity, job-scoped SDK permissions, readiness evidence, short-lived
credentials, and created-resource-only recovery.

## Example requests

```text
Make this PowerShell cleanup script support -WhatIf correctly.
Why does my PSReadLine predictor freeze typing?
Create a deployment script that discovers MSBuild automatically.
Fix this shell script so set -e does not terminate the caller.
Build a local MCP server for a Windows desktop application.
Set up a GitHub Actions workflow to publish my module to the PowerShell Gallery.
```

## Platform notes

- PowerShell and profile guidance targets PowerShell 7.
- Shell guidance applies to Linux, macOS, WSL, and remote Unix-like targets.
- COM/WinRT MCP servers require Windows and a suitable .NET SDK.
- Deployment commands depend on the target platform's SDK and device tools.

## Changelog

Each skill has its own `CHANGELOG.md`; marketplace-wide history is in the
[repository changelog](../../../CHANGELOG.md).
