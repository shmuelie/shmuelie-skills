# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Fixed
- **shmuelie-authoring:** preserved authored punctuation in readability corpora,
  with explicit separators, scorer context, sample sizes and a synthetic
  demonstration of preprocessing-driven grade changes.

## [2.4.0] - 2026-09-11

The aggregate release includes `shmuelie-devenv` 1.3.0 and `shmuelie-dotnet`
1.1.0. Other focused plugin versions and catalog metadata are unchanged.

### Added
- **shmuelie-devenv:** new `windows-self-hosted-runner` skill for clean-image
  bootstrap, service identity, compatible toolchains, scoped SDK installs,
  short-lived credentials, readiness evidence, and resource-owned recovery.
- **shmuelie-dotnet:** new `msix-servicing` skill covering deployment hooks,
  registered full-trust servicing, activation boundaries, idempotent migrations,
  and qualified update-task verification with foreground recovery.
- **shmuelie-devenv:** new `azure-pipelines-powershell` skill covering evaluation
  phases, safe value binding, explicit publication gates, project-owned package
  versions, and small no-network transformation examples.
- **shmuelie-dotnet:** added scoped MSIX packaging and bundling diagnostics for
  build-engine selection, RID/restore scope, trimming/AOT properties, native
  tool discovery, duplicate bundle payloads, and older-platform extensions.

## [2.3.0] - 2026-09-11

The aggregate release includes `shmuelie-devenv` 1.2.0. Other focused plugin
versions and catalog metadata are unchanged.

### Added
- **shmuelie-devenv:** added control-safe filesystem directory reporting and
  origin-scoped popup exclusion from shared status/cache access without stale
  parent-state restoration.
- **shmuelie-devenv:** added lifetime-qualified cache identity and atomic
  snapshot guidance with a disposable, coordinated multi-process lab and
  explicit failure, abandonment, and delivery-acknowledgment boundaries.
- **shmuelie-devenv:** added ownership-preserving configuration maintenance
  guidance with relative-link inspection, isolated writer probes, preserved
  backups, explicit drift-conflict review, and broken-link recovery.
- **shmuelie-devenv:** documented executable, shell-shim, launcher, and child
  environment boundaries, including fresh toolchain shells and scoped tmux
  environment forwarding.

### Fixed
- **shmuelie-devenv:** replaced per-startup completion-cache version probes with
  no-spawn application discovery and metadata-based freshness checks, including
  cache age limits, missing tools, and safe regeneration.

## [2.2.0] - 2026-09-10

The aggregate release includes `shmuelie-copilot` 1.2.0 and
`shmuelie-devenv` 1.1.0. Other focused plugin versions are unchanged.

### Added
- **shmuelie-copilot:** expanded session-repair guidance with request/result
  pairing, session-relative ordering, cross-reference integrity, and fictional
  fixtures for truncated or inconsistent history.
- **shmuelie-copilot:** added bounded, notification-aware delegated-work
  supervision to playbook guidance, including milestone expectations and safe
  responses to blockers, drift, and unavailable live progress.
- **shmuelie-devenv:** new `powershell-gallery-publishing` skill — tag-triggered
  GitHub Actions publishing to the PowerShell Gallery (`<Module>-vX.Y.Z` tags with a
  tag-vs-manifest version check, glob-scoped API keys behind a named environment),
  cutting a release, the "GitHub fires no tag workflows when more than three tags are
  pushed at once" gotcha, and first-come module-name reservation.

### Fixed
- Updated the documentation catalog to include `powershell-gallery-publishing`,
  with six devenv skills and 23 skills overall.
- **shmuelie-copilot:** distinguished chronological session reports from derived
  final-state PR descriptions, with a synthetic example preserving delivered
  behavior, relevant evidence, risks, limitations, and future work.
- **shmuelie-copilot:** aligned the scan-learnings prompt with release-based
  versioning, preserving existing versions during content scans and requiring
  per-skill and repository `[Unreleased]` notes, owning-plugin README updates,
  and marketplace validation.

## [2.1.0] - 2026-08-09

### Added
- copilot-session-management: Windows desktop notification diagnostics (native
  toast AUMID `GitHub.Copilot.CLI`, focus-gated firing, unregistered-AUMID silent
  drop, missing-toast checklist).
- plugin-authoring: Hooks (lifecycle plugins) section — plugin loader drops
  `plugin.json` `hooks`; `copilot-hooks.json` loads only via Agency `--plugin-dir`
  or in-repo `.github/hooks/`; Copilot CLI has no completion event.

## [2.0.0] - 2026-08-05

First public release and multi-plugin restructure. The aggregate
`shmuelie-skills` plugin moves to 2.0.0 (the notification plugin was removed)
and the six focused plugins debut at 1.0.0.

### Added
- New `shmuelie-copilot`, `shmuelie-devenv`, `shmuelie-authoring`,
  `shmuelie-dotnet`, `shmuelie-systems`, and `shmuelie-typescript` focused plugins.
- Copilot session reporting, usage analysis, playbook, session-management, and
  plugin-authoring skills; PowerShell profile, local MCP server, RFC-authoring,
  and writing-level skills.
- Per-skill `CHANGELOG.md` in every skill directory, seeded from repository
  history and required by marketplace validation.
- A Markdown documentation site under `docs/` with a Jekyll build, plus a
  marketplace validation script that also verifies every on-disk plugin has a
  marketplace entry and that the aggregate plugin's skills equal the union of the
  focused plugins' skills.

### Changed
- Restructured into a multi-plugin marketplace: every skill now lives in a
  self-contained focused plugin, and the aggregate plugin loads only focused
  skill directories (no root `skills/`).
- Removed all references to private orchestration tooling; plugin authoring and
  session management use native Copilot CLI marketplace commands, and
  writing-level analysis operates only on user-provided or local text.
- Each focused plugin README documents its own skills and features in full; the
  root README is a concise index.
- Documentation authored in Markdown; the Pages workflow builds with Jekyll.

### Removed
- Removed the notification plugin, whose plugin-level hook injection depended on
  tooling unavailable to public Copilot CLI users.
- Removed personal-infrastructure host names from `copilot-instructions.md` and
  the historical changelog provenance notes.

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
- Source: a Rust build-failure session and a packaged VS Code MSIX session

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
- Expanded the known SSH hosts used for session sweeps
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
- Updated homelab-infra skill with learnings from Proxmox, Jellyfin, and ComfyUI remote sessions

## [1.4.0] - 2026-03-22

### Added
- New **qualcomm-aic** skill: Qualcomm Cloud AI 100 NPU development — SDK management,
  GLIBCXX RUNPATH conflict, ONNX→QPC compilation, SD model type detection via safetensors
  keys, LoRA auto-activation control, job ETA, and SD WebUI API patterns
- Source: Qualcomm Cloud AI 100 development sessions

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

[Unreleased]: https://github.com/shmuelie/shmuelie-skills/compare/v2.4.0...HEAD
[2.4.0]: https://github.com/shmuelie/shmuelie-skills/compare/v2.3.0...v2.4.0
[2.3.0]: https://github.com/shmuelie/shmuelie-skills/compare/v2.2.0...v2.3.0
[2.2.0]: https://github.com/shmuelie/shmuelie-skills/compare/v2.1.0...v2.2.0
[2.1.0]: https://github.com/shmuelie/shmuelie-skills/compare/v2.0.0...v2.1.0
[2.0.0]: https://github.com/shmuelie/shmuelie-skills/releases/tag/v2.0.0
