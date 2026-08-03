# shmuelie-skills

A [GitHub Copilot CLI plugin](https://docs.github.com/en/copilot/concepts/agents/copilot-cli/about-cli-plugins) packaging domain knowledge learned from real-world projects as reusable skills.

## Installation

From a terminal:

```bash
copilot plugin install shmuelie/shmuelie-skills
```

Or from inside a Copilot CLI session:

```
/plugin install shmuelie/shmuelie-skills
```

Verify the plugin loaded:

```
/plugin list
```

Check available skills:

```
/skills list
```

## Focused plugins

The repository is also an Agency marketplace. Install only the areas you need:

| Plugin | Description |
|---|---|
| `shmuelie-copilot` | Copilot CLI sessions, reports, playbooks, and plugin authoring |
| `shmuelie-devenv` | PowerShell profile and local MCP server engineering |
| `shmuelie-authoring` | RFC-style documents and readability analysis |
| `shmuelie-notifications` | Windows attention-notification hooks |

```text
agency plugin install "market:shmuelie-copilot@https://github.com/shmuelie/shmuelie-skills" --engine copilot
```

> **Note:** Plugins are installed per-environment. If you use Copilot CLI in WSL, SSH, or remote sessions, you'll need to install the plugin in each environment separately.

## Skills

| Skill | Description |
|-------|-------------|
| **winui3-msix** | WinUI 3 data binding pitfalls (`{x:Bind}` vs `{Binding}` vs `[Bindable]`), MSIX packaging (`EnableMsixTooling`, manifest requirements, loose-file registration), WinAppSDK test project architecture, and DI patterns |
| **csharp-interop** | CsWin32 setup and `[GeneratedComInterface]` COM (build-task mode, in-memory generation), COM server/class-factory (`DllGetClassObject`, `ComInterfaceMarshaller`), shell icon handlers (`CreateIconFromResourceEx`), native hosting via DNNE/nethost, `LibraryImport` marshalling, ConPTY HPCON calling convention bug, `NativeLibrary.SetDllImportResolver`, Native AOT + trimming, VT escape sequence parsing, IPC message patterns, and plugin path security |
| **dotnet-project-init** | `Directory.Build.props` centralized config, `global.json` test runner setup for .NET 10+, `.sln`→`.slnx` migration, mixed C#/C++ toolset modernization (v143→v145, CppWinRT 3.0), NuGet `ExcludeAssets` patterns, GitHub Actions CI workflows for .NET and MSIX, `copilot-instructions.md` templates, [Keep a Changelog](https://keepachangelog.com/) format, and [Semantic Versioning](https://semver.org/) |
| **deploy-scripts** | `Deploy.ps1` patterns — MSBuild auto-detection via `vswhere`, architecture detection, AppX loose-file layout assembly, `Add-AppxPackage -Register`, `WinAppDeployCmd` remote deployment, and ADB for Android |
| **typescript-cli** | Process pool management, atomic cache writes (`.tmp` + rename), cache versioning with migration, adaptive rate limiting, SIGINT graceful shutdown, multi-tier file matching, Windows `MAX_PATH` handling, and `??` vs `\|\|` pitfalls |
| **embedded-cpp** | Buildroot external tree for MIPS cross-compilation, CMake presets, binary size optimization (`-fno-rtti`, `-fno-unwind-tables`, UPX, libstdc++ `--enable-clocale=generic`/`--disable-libstdcxx-verbose`), C++-standard-vs-libc decoupling, long-run leak diagnosis with a host valgrind harness, `FetchContent`, Catch2 testing, C++20 conventions, and MQTT HA auto-discovery (QoS 0 retained) |
| **shell-wsl** | Shell script bugs (`exit` vs `return`, variable quoting, `mkdir -p`), `set -euo pipefail`, WSL systemd detection, `TERM=xterm-256color` for progress indicators, APT troubleshooting, one-connection `tar`-over-SSH deployment, version-aware updaters (`--version` vs GitHub tags), output quieting (`apt-get -qq`), embedded device deployment (`cfgmtd`, symlink config), and Rust/Cargo clippy patterns |
| **powershell-scripting** | Idiomatic PowerShell for destructive/bulk scripts — `SupportsShouldProcess` + `ConfirmImpact`, native `-WhatIf`/`-Confirm` instead of custom `-Execute`/typed-`yes` gates, per-operation `$PSCmdlet.ShouldProcess`, and preview-then-apply verification |
| **homelab-infra** | Proxmox NVIDIA GPU passthrough to LXC containers (driver matching, `lxc.cgroup2`, `pct push/exec`, `proxmox-boot-tool refresh`), Home Assistant dashboard YAML and Proxmox entity naming, Jellyfin plugin provider architecture, and ComfyUI custom node development |
| **qualcomm-aic** | Qualcomm Cloud AI 100 NPU — SDK installation and upgrades, GLIBCXX RUNPATH conflict fix, ONNX→QPC compilation pipeline, SD model type detection (safetensors keys vs file size), LoRA auto-activation control, job ETA, and SD WebUI compatible API |
| **roslyn-sourcegen** | Roslyn incremental source generators (`IIncrementalGenerator`), equatable pipeline models with `EquatableArray<T>`, `ForAttributeWithMetadataName`, testing with `CSharpGeneratorDriver`, analyzer diagnostic patterns, NuGet packaging layout, nested type handling, and common pitfalls |
| **icon-assets** | Application and NuGet package icon creation — MSIX visual asset sets (sizes, naming, altform-unplated), NuGet `PackageIcon` wiring, favicons, Fluent/Material design style guidelines, and SVG-to-PNG/ICO generation approaches |
| **msix-store-submission** | Microsoft Store submission for any MSIX app — Partner Center identity alignment, signing config, self-contained packaging with framework dependency stripping, 4-part versioning, solution platform locking, and CI/CD workflow |
| **copilot-playbook** | Generate a teaching guide for effective Copilot CLI workflows from real session history |
| **copilot-session-management** | Diagnose, repair, merge, and manage Copilot CLI sessions and plugins |
| **copilot-session-report** | Generate a detailed report for a Copilot CLI session |
| **copilot-usage-report** | Analyze prompting and usage patterns across Copilot CLI sessions |
| **plugin-authoring** | Author Copilot CLI and Agency plugins and marketplaces |
| **powershell-profile** | PowerShell profile, PSReadLine, prompt, and worktree-prediction engineering |
| **local-mcp-server-development** | Build local .NET MCP servers for desktop application automation |
| **ietf-rfc-authoring** | Produce RFC-style specifications with kramdown-rfc |
| **writing-level-analysis** | Measure Flesch-Kincaid and related readability metrics |

## Project Structure

```
shmuelie-skills/
├── plugin.json                        # Plugin manifest
├── CHANGELOG.md                       # Version history
├── .github/
│   ├── copilot-instructions.md        # Guides skill sweep process
│   └── plugin/
│       ├── marketplace.json            # Multi-plugin marketplace definition
│       └── shmuelie-*/                 # Focused self-contained plugins
├── skills/
│   ├── winui3-msix/SKILL.md
│   ├── csharp-interop/SKILL.md
│   ├── dotnet-project-init/SKILL.md
│   ├── deploy-scripts/SKILL.md
│   ├── typescript-cli/SKILL.md
│   ├── embedded-cpp/SKILL.md
│   ├── shell-wsl/SKILL.md
│   ├── powershell-scripting/SKILL.md
│   ├── homelab-infra/SKILL.md
│   ├── qualcomm-aic/SKILL.md
│   ├── roslyn-sourcegen/SKILL.md
│   ├── icon-assets/SKILL.md
│   └── msix-store-submission/SKILL.md
└── README.md
```

## Updating Skills from New Sessions

Skills are extracted from Copilot CLI and VS Code chat sessions. To sweep for new learnings periodically, open a Copilot CLI session in this repo and run:

```
Scan for new learnings from recent sessions and update skills
```

Copilot will query the session store for sessions since the last sweep, extract new patterns, update existing `SKILL.md` files or create new ones, bump the version, and update the changelog.

A `.github/copilot-instructions.md` file is included to guide this process automatically.

## Adding a New Skill

1. Create `skills/<skill-name>/SKILL.md` with YAML frontmatter and markdown body:

   ```markdown
   ---
   name: my-skill
   description: Brief description of what this skill covers
   ---

   Context instructions for when this skill is active.

   # Domain Knowledge

   ## Topic One
   - Key fact or pattern
   - Another important detail
   ```

2. Reinstall the plugin to pick up changes:

   ```bash
   copilot plugin install ./shmuelie-skills
   ```

## Sources

Learnings extracted from 84+ [Copilot CLI](https://docs.github.com/en/copilot/concepts/agents/about-copilot-cli) sessions and [VS Code Copilot Chat](https://docs.github.com/en/copilot/using-github-copilot/copilot-chat/using-github-copilot-chat-in-your-ide) sessions across 22+ repositories including:

- **C# / WinUI 3**: [windows-tmux](https://github.com/shmuelie/windows-tmux), [modern-meeter](https://github.com/shmuelie/modern-meeter), [modern-proxy](https://github.com/shmuelie/modern-proxy), [matroska-full-support](https://github.com/shmuelie/matroska-full-support), [Shmuelie.WinRTServer](https://github.com/shmuelie/Shmuelie.WinRTServer), [Shmuelie.JsonView](https://github.com/shmuelie/Shmuelie.JsonView), [Shmuelie.Jellyfin](https://github.com/shmuelie/Shmuelie.Jellyfin)
- **TypeScript / Node**: [deviantart-helpers](https://github.com/shmuelie/deviantart-helpers), [kemono-helpers](https://github.com/shmuelie/kemono-helpers), [easy-shul-api](https://github.com/shmuelie/easy-shul-api), [shmuelie.englard.net](https://github.com/shmuelie/shmuelie.englard.net), [user-scripts](https://github.com/shmuelie/user-scripts)
- **Embedded / IoT**: [mfi-custom-code](https://github.com/shmuelie/mfi-custom-code), [mfi-env](https://github.com/shmuelie/mfi-env), SDK.UBNT.v5.3.3
- **Mobile**: [android-notification-forwarder](https://github.com/shmuelie/android-notification-forwarder)
- **Homelab**: [ha-config](https://github.com/shmuelie/ha-config), Proxmox PVE-Z8, Jellyfin, ComfyUI
- **AI / ML**: [aic-server](https://github.com/shmuelie/aic-server) (Qualcomm Cloud AI 100)
- **Other**: [WSL-Hello-sudo](https://github.com/nullpo-head/WSL-Hello-sudo), [jellyfin-youtube-metadata-plugin](https://github.com/shmuelie/jellyfin-youtube-metadata-plugin)
