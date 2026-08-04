# shmuelie-devenv

Developer-environment skills for safe PowerShell automation, shell and WSL
workflows, deployment scripts, interactive profiles, and local .NET MCP servers.

**Version:** 0.3.1

**Catalog:** [`shmuelie-skills`](../../../README.md)

**Changelog:** [`CHANGELOG.md`](../../../CHANGELOG.md)

## Install

```text
copilot plugin marketplace add shmuelie/shmuelie-skills
copilot plugin install shmuelie-devenv@shmuelie-skills
```

```text
copilot plugin update shmuelie-devenv
copilot plugin uninstall shmuelie-devenv
```

## When to install

Use this plugin for workstation automation, terminal behavior, deployment
tooling, cross-platform shell scripts, and local integrations that expose desktop
applications to Copilot through MCP.

## Skills

| Skill | Use it for |
|---|---|
| [`deploy-scripts`](skills/deploy-scripts/SKILL.md) | Discover build tools, assemble deployable layouts, and deploy to Windows or Android targets |
| [`local-mcp-server-development`](skills/local-mcp-server-development/SKILL.md) | Build stdio MCP servers in .NET that safely automate COM or WinRT applications |
| [`powershell-profile`](skills/powershell-profile/SKILL.md) | Structure profiles, configure PSReadLine, build prompts, cache completions, and recover terminal modes |
| [`powershell-scripting`](skills/powershell-scripting/SKILL.md) | Design safe destructive or bulk cmdlets with `ShouldProcess`, useful output, and predictable errors |
| [`shell-wsl`](skills/shell-wsl/SKILL.md) | Write reliable shell scripts and troubleshoot WSL, SSH deployment, package management, and Cargo |

## Example requests

```text
Make this PowerShell cleanup script support -WhatIf correctly.
Why does my PSReadLine predictor freeze typing?
Create a deployment script that discovers MSBuild automatically.
Fix this shell script so set -e does not terminate the caller.
Build a local MCP server for a Windows desktop application.
```

## Platform notes

- PowerShell and Windows profile guidance primarily targets PowerShell 7.
- Shell guidance applies to Linux, macOS, WSL, and remote Unix-like targets.
- COM/WinRT MCP servers require Windows and a suitable .NET SDK.
- Deployment commands depend on the target platform's SDK and device tools.
