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

Copy or symlink individual skill directories into your Copilot CLI user extensions directory, or clone this repo and symlink the entire root:

```powershell
# Individual skill
New-Item -ItemType SymbolicLink `
  -Path "$env:USERPROFILE\.copilot\extensions\winui3-msix" `
  -Target "$PWD\winui3-msix"

# All skills at once
Get-ChildItem -Directory -Exclude '.git','.github' | ForEach-Object {
    New-Item -ItemType SymbolicLink `
      -Path "$env:USERPROFILE\.copilot\extensions\$($_.Name)" `
      -Target $_.FullName
}
```

After installing, restart Copilot CLI or run `/clear` to reload extensions.

## Adding a New Skill

1. Create a directory named after the skill
2. Add `extension.mjs` inside it (only `.mjs` files are supported)
3. Use `@github/copilot-sdk/extension` — it's auto-resolved, no install needed
4. Reload with `/clear` or restart the CLI

## Sources

Learnings extracted from 84+ Copilot CLI sessions (63 Windows + 21 WSL) plus VS Code Copilot Chat sessions across 22+ repositories including:
windows-tmux, modern-meeter, modern-proxy, matroska-full-support, windows-ha-app,
Shmuelie.WinRTServer, Shmuelie.JsonView, Shmuelie.Jellyfin, deviantart-helpers,
android-notification-forwarder, easy-shul-api, mfi-custom-code, mfi-env,
SDK.UBNT.v5.3.3, WSL-Hello-sudo, ha-config, and more.
