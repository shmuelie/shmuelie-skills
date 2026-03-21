# shmuelie-skills

Custom [Copilot CLI](https://docs.github.com/en/copilot/github-copilot-in-the-cli) skills (extensions) encoding domain knowledge from real-world projects.

## Skills Catalog

| Skill | Description |
|-------|-------------|
| **winui3-msix** | WinUI 3 binding gotchas, MSIX packaging, WinAppSDK test architecture |
| **csharp-interop** | CsWin32, LibraryImport, ConPTY, Native AOT, runtime marshalling |
| **dotnet-project-init** | .NET project scaffolding, Directory.Build.props, CI workflows |
| **deploy-scripts** | Deploy.ps1 patterns for MSIX loose-file, remote, and mobile deployment |
| **typescript-cli** | Process pools, atomic caching, rate limiting, graceful shutdown |
| **embedded-cpp** | Buildroot cross-compilation, CMake presets, binary size optimization, Catch2 |
| **shell-wsl** | Shell script patterns, WSL quirks, embedded device deployment, Rust/Cargo |
| **homelab-infra** | Proxmox GPU passthrough, LXC containers, HA dashboards, Jellyfin plugins, ComfyUI nodes |

## Installation

```bash
# From GitHub
copilot plugin install shmuelie/shmuelie-skills

# From a local clone
copilot plugin install ./shmuelie-skills
```

After installing, verify with:
```bash
copilot plugin list
```

And in an interactive session, check skills loaded with `/skills list`.

## Adding a New Skill

1. Create a directory under `skills/` named after the skill
2. Add `SKILL.md` inside it with YAML frontmatter (`name`, `description`) and markdown content
3. Reinstall: `copilot plugin install ./shmuelie-skills`

## Sources

Learnings extracted from 84+ Copilot CLI sessions (63 Windows + 21 WSL) plus VS Code Copilot Chat sessions across 22+ repositories including:
windows-tmux, modern-meeter, modern-proxy, matroska-full-support, windows-ha-app,
Shmuelie.WinRTServer, Shmuelie.JsonView, Shmuelie.Jellyfin, deviantart-helpers,
android-notification-forwarder, easy-shul-api, mfi-custom-code, mfi-env,
SDK.UBNT.v5.3.3, WSL-Hello-sudo, ha-config, and more.
