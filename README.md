# shmuelie-skills

Reusable [GitHub Copilot CLI](https://docs.github.com/en/copilot/concepts/agents/copilot-cli/about-cli-plugins)
skills distilled from real software, infrastructure, automation, and authoring
projects.

The repository supports two installation styles:

- **Aggregate plugin** — install every skill with one command.
- **Focused marketplace plugins** — install only the subject areas you use.

All skills are public-facing and live in independently versioned, self-contained
plugins under `.github/plugin/`.

## Quick start

Install the aggregate plugin directly:

```text
copilot plugin install shmuelie/shmuelie-skills
```

Verify it:

```text
copilot plugin list
```

Inside an interactive Copilot CLI session:

```text
/skills list
```

Plugins are installed per environment. Repeat installation inside WSL, SSH
hosts, containers, or other remote environments where Copilot CLI runs.

## Install focused plugins

Register this repository as a marketplace once:

```text
copilot plugin marketplace add shmuelie/shmuelie-skills
copilot plugin marketplace browse shmuelie-skills
```

Install one or more focused plugins:

```text
copilot plugin install shmuelie-copilot@shmuelie-skills
copilot plugin install shmuelie-dotnet@shmuelie-skills
```

### Plugin catalog

| Plugin | Skills | Best for |
|---|---:|---|
| [`shmuelie-copilot`](.github/plugin/shmuelie-copilot/README.md) | 5 | Copilot sessions, reports, playbooks, and plugin authoring |
| [`shmuelie-devenv`](.github/plugin/shmuelie-devenv/README.md) | 5 | PowerShell, shell, deployment, profiles, and local MCP servers |
| [`shmuelie-authoring`](.github/plugin/shmuelie-authoring/README.md) | 2 | RFC-style specifications and readability analysis |
| [`shmuelie-dotnet`](.github/plugin/shmuelie-dotnet/README.md) | 6 | .NET, C# interop, Roslyn, WinUI 3, MSIX, and application assets |
| [`shmuelie-systems`](.github/plugin/shmuelie-systems/README.md) | 3 | Embedded C++, homelab infrastructure, and AI accelerators |
| [`shmuelie-typescript`](.github/plugin/shmuelie-typescript/README.md) | 1 | Reliable TypeScript and Node.js command-line applications |

The aggregate `shmuelie-skills` plugin references all six focused skill
directories. Each skill still has exactly one focused owning plugin.

## Manage installations

```text
copilot plugin list
copilot plugin update plugin-name
copilot plugin update --all
copilot plugin uninstall plugin-name

copilot plugin marketplace list
copilot plugin marketplace update shmuelie-skills
copilot plugin marketplace remove shmuelie-skills
```

After changing a locally cloned plugin, reinstall it before testing so Copilot
CLI acquires the updated files.

## Skill catalog

### shmuelie-copilot

| Skill | What it covers |
|---|---|
| [`copilot-playbook`](.github/plugin/shmuelie-copilot/skills/copilot-playbook/SKILL.md) | Generate a teaching guide from real Copilot usage patterns and prompts |
| [`copilot-session-management`](.github/plugin/shmuelie-copilot/skills/copilot-session-management/SKILL.md) | Diagnose and safely repair sessions; manage plugins, marketplaces, and MCP configuration |
| [`copilot-session-report`](.github/plugin/shmuelie-copilot/skills/copilot-session-report/SKILL.md) | Produce a detailed narrative and tool report for one session |
| [`copilot-usage-report`](.github/plugin/shmuelie-copilot/skills/copilot-usage-report/SKILL.md) | Analyze prompting style, session shape, timing, and technical patterns |
| [`plugin-authoring`](.github/plugin/shmuelie-copilot/skills/plugin-authoring/SKILL.md) | Author single plugins and independently versioned multi-plugin marketplaces |

### shmuelie-devenv

| Skill | What it covers |
|---|---|
| [`deploy-scripts`](.github/plugin/shmuelie-devenv/skills/deploy-scripts/SKILL.md) | Build discovery, architecture selection, AppX deployment, remote Windows deployment, and ADB |
| [`local-mcp-server-development`](.github/plugin/shmuelie-devenv/skills/local-mcp-server-development/SKILL.md) | Local .NET MCP servers that automate desktop applications through COM and WinRT |
| [`powershell-profile`](.github/plugin/shmuelie-devenv/skills/powershell-profile/SKILL.md) | Profile structure, PSReadLine, prompts, worktree prediction, and terminal recovery |
| [`powershell-scripting`](.github/plugin/shmuelie-devenv/skills/powershell-scripting/SKILL.md) | Safe destructive and bulk scripts with `ShouldProcess`, `-WhatIf`, and pipeline-friendly output |
| [`shell-wsl`](.github/plugin/shmuelie-devenv/skills/shell-wsl/SKILL.md) | Reliable shell scripts, WSL behavior, SSH deployment, package management, and Cargo workflows |

### shmuelie-authoring

| Skill | What it covers |
|---|---|
| [`ietf-rfc-authoring`](.github/plugin/shmuelie-authoring/skills/ietf-rfc-authoring/SKILL.md) | RFC-style structure, BCP 14 terminology, ABNF, kramdown-rfc, and xml2rfc |
| [`writing-level-analysis`](.github/plugin/shmuelie-authoring/skills/writing-level-analysis/SKILL.md) | Flesch-Kincaid and related readability metrics for user-provided or local text |

### shmuelie-dotnet

| Skill | What it covers |
|---|---|
| [`csharp-interop`](.github/plugin/shmuelie-dotnet/skills/csharp-interop/SKILL.md) | COM, CsWin32, P/Invoke, Native AOT, native hosting, shell integration, and IPC |
| [`dotnet-project-init`](.github/plugin/shmuelie-dotnet/skills/dotnet-project-init/SKILL.md) | Repository setup, centralized build properties, solutions, test runners, CI, and packaging |
| [`icon-assets`](.github/plugin/shmuelie-dotnet/skills/icon-assets/SKILL.md) | Application, MSIX, NuGet, favicon, SVG, PNG, and ICO asset generation |
| [`msix-store-submission`](.github/plugin/shmuelie-dotnet/skills/msix-store-submission/SKILL.md) | Partner Center identity, signing, self-contained packaging, versions, and CI |
| [`roslyn-sourcegen`](.github/plugin/shmuelie-dotnet/skills/roslyn-sourcegen/SKILL.md) | Incremental generators, analyzer diagnostics, pipeline models, tests, and NuGet layout |
| [`winui3-msix`](.github/plugin/shmuelie-dotnet/skills/winui3-msix/SKILL.md) | WinUI 3 binding, packaging, loose registration, testing, and dependency injection |

### shmuelie-systems

| Skill | What it covers |
|---|---|
| [`embedded-cpp`](.github/plugin/shmuelie-systems/skills/embedded-cpp/SKILL.md) | Buildroot, cross-compilation, CMake, binary size, compatibility, testing, and MQTT |
| [`homelab-infra`](.github/plugin/shmuelie-systems/skills/homelab-infra/SKILL.md) | Proxmox, GPU passthrough, Home Assistant, Jellyfin, and ComfyUI |
| [`qualcomm-aic`](.github/plugin/shmuelie-systems/skills/qualcomm-aic/SKILL.md) | Qualcomm Cloud AI 100 SDK, QPC compilation, model detection, and inference APIs |

### shmuelie-typescript

| Skill | What it covers |
|---|---|
| [`typescript-cli`](.github/plugin/shmuelie-typescript/skills/typescript-cli/SKILL.md) | Process pools, atomic caches, rate limiting, graceful shutdown, file matching, and Windows paths |

## How skills activate

Copilot CLI uses each skill's frontmatter `description` as its discovery surface.
Descriptions include capability terms and trigger phrases so the relevant skill
is loaded automatically when a request matches.

You can also name a skill explicitly:

```text
Use the powershell-scripting skill to review this deployment script.
```

A skill supplies domain context and workflow guidance. It does not install the
external tools it documents; prerequisites remain the responsibility of the
project or environment using the skill.

## Repository structure

```text
shmuelie-skills/
├── plugin.json
├── CHANGELOG.md
├── README.md
├── docs/
│   ├── _config.yml
│   ├── index.md
│   ├── installation.md
│   ├── plugins.md
│   └── contributing.md
├── scripts/
│   └── Test-Marketplace.ps1
└── .github/
    ├── copilot-instructions.md
    ├── workflows/
    └── plugin/
        ├── marketplace.json
        └── shmuelie-*/
            ├── plugin.json
            ├── README.md
            └── skills/<skill>/SKILL.md
```

## Versioning

- Each focused plugin follows semantic versioning independently.
- A focused plugin's `plugin.json` version matches its marketplace entry.
- The root aggregate plugin is versioned independently from focused plugins.
- Marketplace `metadata.version` changes only when catalog composition or
  marketplace behavior changes.
- All notable changes are recorded in [`CHANGELOG.md`](CHANGELOG.md).

## Contributing a skill

1. Choose the focused plugin that owns the topic.
2. Create `.github/plugin/<plugin>/skills/<skill-name>/SKILL.md`.
3. Add valid YAML frontmatter with a kebab-case name and specific description.
4. Add implementation patterns, examples, failure modes, and error messages.
5. Update the owning plugin README and this catalog.
6. Bump the owning plugin manifest and matching marketplace version.
7. Bump the aggregate plugin when its installed skill content changes.
8. Update the changelog.
9. Run:

   ```powershell
   .\scripts\Test-Marketplace.ps1
   ```

Create a new focused plugin when no existing plugin is a coherent fit. Root-level
skill ownership is intentionally not supported.

## Documentation site

The static site source is under [`docs/`](docs/). Its Pages workflow remains
manual while the repository is private and can be enabled when the repository is
ready for public release.

## Source and scope

The skills come from repeated patterns encountered in personal and open-source
projects across .NET, Windows applications, TypeScript, embedded systems,
homelab infrastructure, and developer tooling.

Public skills must not include credentials, private URLs, organization-specific
systems, or dependencies unavailable to public Copilot CLI users.
