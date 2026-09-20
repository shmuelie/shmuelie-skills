---
title: Plugins
---

**[Home](index.md) · [Installation](installation.md) · [Plugins](plugins.md) · [Contributing](contributing.md) · [GitHub](https://github.com/shmuelie/shmuelie-skills)**

# Plugins

Each skill belongs to one focused plugin. The aggregate root plugin loads all
seven directories without duplicating skill ownership.

## shmuelie-nuget

Create, package, validate, and release .NET libraries. **4 skills.**

| Skill | Use it for |
| --- | --- |
| [dotnet-library-projects](https://github.com/shmuelie/shmuelie-skills/blob/main/.github/plugin/shmuelie-nuget/skills/dotnet-library-projects/SKILL.md) | Library/API/framework decisions and a canonical example |
| [nuget-package-authoring](https://github.com/shmuelie/shmuelie-skills/blob/main/.github/plugin/shmuelie-nuget/skills/nuget-package-authoring/SKILL.md) | Package metadata, assets, dependencies, Source Link, and symbols |
| [dotnet-library-ci](https://github.com/shmuelie/shmuelie-skills/blob/main/.github/plugin/shmuelie-nuget/skills/dotnet-library-ci/SKILL.md) | Read-only CI and isolated packed-library consumption |
| [nuget-release](https://github.com/shmuelie/shmuelie-skills/blob/main/.github/plugin/shmuelie-nuget/skills/nuget-release/SKILL.md) | SemVer/changelog, trusted publishing, release assets, and recovery |

## shmuelie-copilot

Operate and understand Copilot CLI itself. **5 skills.**

| Skill | Use it for |
|---|---|
| [copilot-playbook](https://github.com/shmuelie/shmuelie-skills/blob/main/.github/plugin/shmuelie-copilot/skills/copilot-playbook/SKILL.md) | Teach effective workflows from real prompts |
| [copilot-session-management](https://github.com/shmuelie/shmuelie-skills/blob/main/.github/plugin/shmuelie-copilot/skills/copilot-session-management/SKILL.md) | Repair sessions and manage plugins |
| [copilot-session-report](https://github.com/shmuelie/shmuelie-skills/blob/main/.github/plugin/shmuelie-copilot/skills/copilot-session-report/SKILL.md) | Document one completed session |
| [copilot-usage-report](https://github.com/shmuelie/shmuelie-skills/blob/main/.github/plugin/shmuelie-copilot/skills/copilot-usage-report/SKILL.md) | Analyze usage patterns |
| [plugin-authoring](https://github.com/shmuelie/shmuelie-skills/blob/main/.github/plugin/shmuelie-copilot/skills/plugin-authoring/SKILL.md) | Publish plugins and marketplaces |

## shmuelie-devenv

Build reliable developer shells, profiles, deployment scripts, and local
integrations and inspect threat-model files read-only. **9 skills.**

| Skill | Use it for |
|---|---|
| [deploy-scripts](https://github.com/shmuelie/shmuelie-skills/blob/main/.github/plugin/shmuelie-devenv/skills/deploy-scripts/SKILL.md) | Build discovery and multi-platform deployment |
| [azure-pipelines-powershell](https://github.com/shmuelie/shmuelie-skills/blob/main/.github/plugin/shmuelie-devenv/skills/azure-pipelines-powershell/SKILL.md) | Pipeline expression timing, PowerShell value binding, versioning, and publication gates |
| [local-mcp-server-development](https://github.com/shmuelie/shmuelie-skills/blob/main/.github/plugin/shmuelie-devenv/skills/local-mcp-server-development/SKILL.md) | Local .NET MCP servers for desktop automation |
| [powershell-gallery-publishing](https://github.com/shmuelie/shmuelie-skills/blob/main/.github/plugin/shmuelie-devenv/skills/powershell-gallery-publishing/SKILL.md) | Tag-triggered PowerShell Gallery publishing and module releases |
| [powershell-profile](https://github.com/shmuelie/shmuelie-skills/blob/main/.github/plugin/shmuelie-devenv/skills/powershell-profile/SKILL.md) | Profiles, PSReadLine, prompts, and terminal recovery |
| [powershell-scripting](https://github.com/shmuelie/shmuelie-skills/blob/main/.github/plugin/shmuelie-devenv/skills/powershell-scripting/SKILL.md) | Safe destructive and bulk cmdlets |
| [shell-wsl](https://github.com/shmuelie/shmuelie-skills/blob/main/.github/plugin/shmuelie-devenv/skills/shell-wsl/SKILL.md) | Reliable shell scripts, WSL, SSH deployment, and Cargo |
| [windows-self-hosted-runner](https://github.com/shmuelie/shmuelie-skills/blob/main/.github/plugin/shmuelie-devenv/skills/windows-self-hosted-runner/SKILL.md) | Clean Windows runner bootstrap, service identity, SDK access, and readiness |
| [threat-model-files](https://github.com/shmuelie/shmuelie-skills/blob/main/.github/plugin/shmuelie-devenv/skills/threat-model-files/SKILL.md) | Read-only tm7 dictionaries, diagrams, threat triage, and unresolved references |

## shmuelie-authoring

Produce specifications and proposals, measure readability, and create project artwork. **4 skills.**

| Skill | Use it for |
|---|---|
| [ietf-rfc-authoring](https://github.com/shmuelie/shmuelie-skills/blob/main/.github/plugin/shmuelie-authoring/skills/ietf-rfc-authoring/SKILL.md) | RFC-style specifications with kramdown-rfc |
| [writing-level-analysis](https://github.com/shmuelie/shmuelie-skills/blob/main/.github/plugin/shmuelie-authoring/skills/writing-level-analysis/SKILL.md) | Readability metrics for user-provided text |
| [project-header-artwork](https://github.com/shmuelie/shmuelie-skills/blob/main/.github/plugin/shmuelie-authoring/skills/project-header-artwork/SKILL.md) | Provider-neutral banners, source preservation, and honest fallback states |
| [project-proposal](https://github.com/shmuelie/shmuelie-skills/blob/main/.github/plugin/shmuelie-authoring/skills/project-proposal/SKILL.md) | Safe offline compact/split proposal packages with structural validation |

## shmuelie-dotnet

Develop, package, and diagnose modern .NET and Windows applications, and analyze
data with LINQPad/DuckDB. **10 skills.**

| Skill | Use it for |
|---|---|
| [csharp-interop](https://github.com/shmuelie/shmuelie-skills/blob/main/.github/plugin/shmuelie-dotnet/skills/csharp-interop/SKILL.md) | COM, P/Invoke, Native AOT, and native hosting |
| [linqpad-duckdb](https://github.com/shmuelie/shmuelie-skills/blob/main/.github/plugin/shmuelie-dotnet/skills/linqpad-duckdb/SKILL.md) | Synthetic Parquet/Delta queries, optional Azure credentials, logical schemas, and scan costs |
| [event-contracts](https://github.com/shmuelie/shmuelie-skills/blob/main/.github/plugin/shmuelie-dotnet/skills/event-contracts/SKILL.md) | Typed diagnostic fields, retry/activity correlation, and decoded-event inspection |
| [openapi-client-generation](https://github.com/shmuelie/shmuelie-skills/blob/main/.github/plugin/shmuelie-dotnet/skills/openapi-client-generation/SKILL.md) | Reproducible HTTP clients, endpoint ownership, and fake-transport validation |
| [dotnet-project-init](https://github.com/shmuelie/shmuelie-skills/blob/main/.github/plugin/shmuelie-dotnet/skills/dotnet-project-init/SKILL.md) | General repository, solution, application, test, and CI setup |
| [icon-assets](https://github.com/shmuelie/shmuelie-skills/blob/main/.github/plugin/shmuelie-dotnet/skills/icon-assets/SKILL.md) | Application, MSIX, NuGet, and web icon assets |
| [msix-store-submission](https://github.com/shmuelie/shmuelie-skills/blob/main/.github/plugin/shmuelie-dotnet/skills/msix-store-submission/SKILL.md) | MSIX packaging and Microsoft Store submission |
| [msix-servicing](https://github.com/shmuelie/shmuelie-skills/blob/main/.github/plugin/shmuelie-dotnet/skills/msix-servicing/SKILL.md) | Deployment hooks, full-trust servicing, migrations, and update probes |
| [roslyn-sourcegen](https://github.com/shmuelie/shmuelie-skills/blob/main/.github/plugin/shmuelie-dotnet/skills/roslyn-sourcegen/SKILL.md) | Incremental generators and analyzers |
| [winui3-msix](https://github.com/shmuelie/shmuelie-skills/blob/main/.github/plugin/shmuelie-dotnet/skills/winui3-msix/SKILL.md) | WinUI 3 binding, packaging, testing, and DI |

## shmuelie-systems

Work across embedded Linux, self-hosted infrastructure, and accelerator
hardware. **3 skills.**

| Skill | Use it for |
|---|---|
| [embedded-cpp](https://github.com/shmuelie/shmuelie-skills/blob/main/.github/plugin/shmuelie-systems/skills/embedded-cpp/SKILL.md) | Buildroot, cross-compilation, size, and testing |
| [homelab-infra](https://github.com/shmuelie/shmuelie-skills/blob/main/.github/plugin/shmuelie-systems/skills/homelab-infra/SKILL.md) | Proxmox, GPU passthrough, Home Assistant, Jellyfin |
| [qualcomm-aic](https://github.com/shmuelie/shmuelie-skills/blob/main/.github/plugin/shmuelie-systems/skills/qualcomm-aic/SKILL.md) | Qualcomm Cloud AI 100 SDK and inference |

## shmuelie-typescript

Build TypeScript CLIs that remain correct under concurrency, failure, and
filesystem scale. **1 skill.**

| Skill | Use it for |
|---|---|
| [typescript-cli](https://github.com/shmuelie/shmuelie-skills/blob/main/.github/plugin/shmuelie-typescript/skills/typescript-cli/SKILL.md) | Process pools, caches, rate limits, and shutdown |
