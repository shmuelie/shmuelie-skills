# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

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

[Unreleased]: https://github.com/shmuelie/shmuelie-skills/compare/v1.10.0...HEAD
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
