# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed
- Rewrote the documentation site in Markdown (`docs/*.md` + `_config.yml`) and
  switched the Pages workflow to a Jekyll build.
- Simplified the root and per-plugin READMEs to point at the documentation site.
- Updated marketplace validation to require Markdown docs and reject HTML.

## [1.15.1] - 2026-08-03

### Changed
- Expanded the root README into a complete installation, plugin-selection,
  skill-catalog, maintenance, versioning, and contribution guide.
- Expanded every focused plugin README with requirements, example requests,
  lifecycle commands, and linked skill documentation.
- Expanded the static documentation site into installation, plugin catalog,
  and contribution pages with responsive navigation and styling.
- Bumped focused plugin patch versions for their shipped documentation updates.

## [1.15.0] - 2026-08-03

### Added
- New `shmuelie-dotnet`, `shmuelie-systems`, and `shmuelie-typescript` focused plugins.

### Changed
- Moved every formerly root-owned skill into a self-contained focused plugin.
- Expanded `shmuelie-devenv` with deployment, PowerShell scripting, and shell/WSL skills.
- Updated the aggregate plugin to load only focused plugin skill directories.
- Updated focused-plugin documentation and marketplace metadata to 2.2.0.

### Removed
- Removed the root `skills/` ownership model.

## [1.14.0] - 2026-08-03

### Changed
- Removed all references to private orchestration tooling from public skills,
  manifests, and installation instructions.
- Rewrote plugin authoring and session management around native Copilot CLI
  commands and public marketplace workflows.
- Reworked writing-level analysis to operate only on user-provided or locally
  authored text.
- Updated focused plugins to version 0.2.0 and marketplace metadata to 2.1.0.

### Removed
- Removed the notification plugin because its plugin-level hook injection
  depended on tooling unavailable to public Copilot CLI users.

## [1.13.0] - 2026-08-03

### Added
- Focused `shmuelie-copilot`, `shmuelie-devenv`, and `shmuelie-authoring` plugins.
- Copilot session reporting, usage analysis, playbook, session-management, and
  plugin-authoring skills.
- PowerShell profile, local MCP server, RFC-authoring, and writing-level skills.
- Static GitHub Pages catalog and validation workflow.
- Public-only plugin guidance using native Copilot CLI marketplace commands.

### Changed
- The root `shmuelie-skills` plugin remains the aggregate direct-install option
  and now loads the focused plugins' skills.
- Marketplace metadata moved to version 2.0.0 for the multi-plugin catalog.
- Removed internal-only tooling and dependencies from the public marketplace.

## [1.12.0] - 2026-08-02

### Added
- New **powershell-scripting** skill: idiomatic PowerShell for destructive/bulk scripts —
  `SupportsShouldProcess` + `ConfirmImpact`, native `-WhatIf`/`-Confirm` instead of custom
  `-Execute`/typed-`yes` gates, per-operation `$PSCmdlet.ShouldProcess`, anti-patterns to
  replace, and preview-then-apply verification
- csharp-interop: CsWin32 `[GeneratedComInterface]` support (v0.3.298+), `CsWin32RunAsBuildTask`,
  in-memory generation (write helper against expected API and let the compiler confirm),
  COM server/class-factory (`DllGetClassObject`, friendly `IClassFactory` `out nint`,
  `ComInterfaceMarshaller`), shell icon handlers (`CreateIconFromResourceEx`, ICONDIR, MSIX
  multi-PNG best-fit), and a Native Hosting (DNNE / nethost) section (nethost from
  `Microsoft.NETCore.App.Host.win-<rid>`, `DNNE_API_OVERRIDE=`, `dnne_abort` via
  `/alternatename`, `%(ResolvedAppHostPack.PackageDirectory)`)
- dotnet-project-init: `.sln`→`.slnx` migration (`dotnet sln migrate`) and mixed C#/C++
  toolset modernization (PlatformToolset v143→v145, CppWinRT 3.0 proxy winmd verification)
- embedded-cpp: C++-standard-vs-libc decoupling, libstdc++ size flags
  (`--enable-clocale=generic`, `--disable-libstdcxx-verbose`), flaky GCC ICE under parallel
  builds, UPX-too-slow caveat, long-running-freeze leak diagnosis via host valgrind harness
  + `/proc` polling, release-only-what-links discipline, and MQTT QoS 0 retained for telemetry
- shell-wsl: one-connection `tar`-over-SSH deployment (`-ch`/symlink follow), version-aware
  updater (`--version` vs GitHub tag + portable semver comparator), and output quieting
  (`apt-get -qq` over `apt`, keep stderr/status lines)
- Source: Shmuelie.WinRTServer v3 redesign, mfi-custom-code Buildroot/MIPS/deploy sessions,
  reusable .NET COM/DNNE interop techniques, and a PowerShell worktree-migration script

## [1.11.0] - 2026-07-20

### Added
- shell-wsl skill: Cargo.lock reproducibility section — commit lockfile for binaries,
  unpinned transitive deps break over time (cookie/time incompatibility example),
  fixes via pin/constrain/drop-feature, Docker COPY gotcha, `cargo tree -i` diagnosis
- msix-store-submission skill: installer parity section (file-type associations, App Paths,
  context menus, PATH via execution aliases when migrating from Inno Setup/MSI) and
  VM testing section (signing, -AllowUnsigned, Developer Mode, Insider CLSID)
- Source: Vod2Pod Rust build failure session + Packaged VS Code MSIX session

## [1.10.2] - 2026-05-31

### Fixed
- Assembly version access pattern in dotnet-project-init: corrected to use AOT-safe
  `typeof(T).Assembly` instead of `Assembly.GetExecutingAssembly()` (stack-frame
  reflection is not Native AOT compatible)

## [1.10.1] - 2026-05-20

### Changed
- Updated dotnet-project-init skill:
  - Added MTP vs VSTest runner conflict warning for .NET 10+ (`xunit.runner.visualstudio`
    is a VSTest adapter and conflicts with `global.json` MTP config)
  - Added assembly version access pattern (`AssemblyInformationalVersionAttribute`)
- Source: windows-tmux versioning session

## [1.10.0] - 2026-05-10

### Added
- New **msix-store-submission** skill: Microsoft Store submission for any MSIX app —
  Partner Center identity alignment (Name, Publisher CN, PhoneProductId), signing config
  (AppxPackageSigningEnabled=false, GenerateTemporaryStoreCertificate), self-contained
  packaging with framework PackageDependency stripping MSBuild target, 4-part version
  requirements, solution platform locking, CI/CD workflow with MSBuild, and submission checklist
- Source: modern-meeter Store submission commits + copilot-instructions.md

## [1.9.0] - 2026-05-10

### Added
- New **icon-assets** skill: application and NuGet package icon creation — MSIX visual
  asset sets (all required sizes, targetsize/altform-unplated naming), NuGet PackageIcon
  csproj wiring, web favicons, platform-appropriate design style guidelines (Fluent for
  Windows, Material for Android), SVG source convention, and generation tool options
  (ImageMagick, Inkscape CLI, icotool, design tools, AI generation)
- Source: modern-meeter, windows-tmux, modern-proxy, matroska-full-support, WinRTServer,
  app-routing, shmuelie.englard.net asset patterns + Microsoft design guidelines

## [1.8.0] - 2026-05-07

### Added
- Old kernel / uClibc compatibility section to embedded-cpp skill:
  - `statx` syscall failure on pre-4.11 kernels (`UCLIBC_USE_TIME64` fix)
  - `std::filesystem` auto-detection causing `CLI11_HAS_FILESYSTEM` issues
  - Relative vs absolute path pitfalls on embedded devices
  - Carriage return corruption from Windows-edited scripts
- MQTT topic ID deduplication patterns (connector/device/name triple-duplication fix)
- Multi-project monorepo versioning (per-project CHANGELOGs, `project/vX.Y.Z` tag pattern)
- Source: 14 WSL mfi-custom-code sessions, 3 cloud sessions (modern-meeter, easy-shul, tehillim)

## [1.7.2] - 2026-03-28

### Fixed
- plugin.json description now mentions all skill areas (added Roslyn, Qualcomm AIC)
- plugin.json keywords now include `qualcomm`, `aic100`, `stable-diffusion`
- README sources now includes kemono-helpers repo

## [1.7.1] - 2026-03-26

### Changed
- Added Shmuelis-MBP to known SSH hosts for session sweeps
- Scanned 2 Mac sessions (macOS build server setup) — learnings noted but too
  niche for a standalone skill; will consolidate if more macOS/CI sessions emerge

## [1.7.0] - 2026-03-25

### Added
- HTTP API client patterns to typescript-cli skill: DDoS-Guard bypass (`Accept: text/css`),
  forced gzip decompression, Swagger/OpenAPI response drift, cookie-based auth,
  and multi-key filename indexing for O(1) matching
- Source: kemono-helpers session (11 turns)

## [1.6.0] - 2026-03-24

### Added
- New **roslyn-sourcegen** skill: Roslyn incremental source generators — IIncrementalGenerator
  pipeline design, equatable models with EquatableArray\<T\>, ForAttributeWithMetadataName,
  testing with CSharpGeneratorDriver, analyzer diagnostic patterns, NuGet packaging layout,
  nested type handling, and common pitfalls (parameter modifiers, async return types)
- Source: 4 sessions covering WSDL source generator, COM interface versioning generator,
  OneFuzz MSBuild-to-generator conversion, and telemetry event generator

## [1.5.1] - 2026-03-22

### Changed
- Restructured copilot-instructions sweep process into 10 explicit steps
- VS Code session scanning (steps 2-4) now clearly separated: JSONL/JSON files,
  state.vscdb CLI sessions, and SSH remote host extraction with known hosts list

## [1.5.0] - 2026-03-22

### Added
- ComfyUI WebSocket integration patterns (AsyncAPI, per-channel streaming, progress relay)
- Proxmox administration patterns (system update scripts, container troubleshooting, drive health, backup optimization)
- Jellyfin server administration (hardware acceleration setup, media troubleshooting)
- Expanded VS Code session discovery in copilot-instructions (4 format types, remote host extraction)

### Changed
- Updated homelab-infra skill with learnings from 8 PVE-Z8, 6 Jellyfin, and 2 ComfyUI remote sessions

## [1.4.0] - 2026-03-22

### Added
- New **qualcomm-aic** skill: Qualcomm Cloud AI 100 NPU development — SDK management,
  GLIBCXX RUNPATH conflict, ONNX→QPC compilation, SD model type detection via safetensors
  keys, LoRA auto-activation control, job ETA, and SD WebUI API patterns
- Source: 9 aic-server sessions from Qualcomm-Cloud-AI SSH host

## [1.3.1] - 2026-03-22

### Changed
- Expanded copilot-instructions with detailed VS Code chat JSONL parsing guide for skill sweeps

## [1.3.0] - 2026-03-22

### Added
- `.github/copilot-instructions.md` to guide periodic skill sweeps
- "Updating Skills from New Sessions" section in README

## [1.2.0] - 2026-03-22

### Added
- CHANGELOG.md following Keep a Changelog format
- CHANGELOG.md to project structure in README

## [1.1.0] - 2026-03-22

### Added
- Keep a Changelog and Semantic Versioning guidance to the `dotnet-project-init` skill
- CHANGELOG.md

## [1.0.0] - 2026-03-21

### Added
- Initial plugin release with 8 skills:
  - **winui3-msix** — WinUI 3 binding, MSIX packaging, WinAppSDK test architecture
  - **csharp-interop** — CsWin32, LibraryImport, ConPTY, Native AOT patterns
  - **dotnet-project-init** — Directory.Build.props, CI workflows, project scaffolding
  - **deploy-scripts** — MSIX loose-file, WinAppDeployCmd, ADB deployment
  - **typescript-cli** — Process pools, atomic caching, rate limiting, shutdown
  - **embedded-cpp** — Buildroot cross-compilation, CMake, binary size optimization, Catch2
  - **shell-wsl** — Shell script patterns, WSL quirks, embedded device deployment, Rust/Cargo
  - **homelab-infra** — Proxmox GPU passthrough, HA dashboards, Jellyfin plugins, ComfyUI nodes
- `plugin.json` manifest for `copilot plugin install`
- `.github/plugin/marketplace.json` for marketplace discovery

[Unreleased]: https://github.com/shmuelie/shmuelie-skills/compare/v1.15.1...HEAD
[1.15.1]: https://github.com/shmuelie/shmuelie-skills/compare/v1.15.0...v1.15.1
[1.15.0]: https://github.com/shmuelie/shmuelie-skills/compare/v1.14.0...v1.15.0
[1.14.0]: https://github.com/shmuelie/shmuelie-skills/compare/v1.13.0...v1.14.0
[1.13.0]: https://github.com/shmuelie/shmuelie-skills/compare/v1.12.0...v1.13.0
[1.12.0]: https://github.com/shmuelie/shmuelie-skills/compare/v1.11.0...v1.12.0
[1.11.0]: https://github.com/shmuelie/shmuelie-skills/compare/v1.10.2...v1.11.0
[1.10.2]: https://github.com/shmuelie/shmuelie-skills/compare/v1.10.1...v1.10.2
[1.10.1]: https://github.com/shmuelie/shmuelie-skills/compare/v1.10.0...v1.10.1
[1.10.0]: https://github.com/shmuelie/shmuelie-skills/compare/v1.9.0...v1.10.0
[1.9.0]: https://github.com/shmuelie/shmuelie-skills/compare/v1.8.0...v1.9.0
[1.8.0]: https://github.com/shmuelie/shmuelie-skills/compare/v1.7.2...v1.8.0
[1.7.2]: https://github.com/shmuelie/shmuelie-skills/compare/v1.7.1...v1.7.2
[1.7.1]: https://github.com/shmuelie/shmuelie-skills/compare/v1.7.0...v1.7.1
[1.7.0]: https://github.com/shmuelie/shmuelie-skills/compare/v1.6.0...v1.7.0
[1.6.0]: https://github.com/shmuelie/shmuelie-skills/compare/v1.5.1...v1.6.0
[1.5.1]:https://github.com/shmuelie/shmuelie-skills/compare/v1.5.0...v1.5.1
[1.5.0]: https://github.com/shmuelie/shmuelie-skills/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/shmuelie/shmuelie-skills/compare/v1.3.1...v1.4.0
[1.3.1]: https://github.com/shmuelie/shmuelie-skills/compare/v1.3.0...v1.3.1
[1.3.0]: https://github.com/shmuelie/shmuelie-skills/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/shmuelie/shmuelie-skills/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/shmuelie/shmuelie-skills/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/shmuelie/shmuelie-skills/releases/tag/v1.0.0
