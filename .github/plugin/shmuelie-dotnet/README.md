# shmuelie-dotnet

.NET and Windows application engineering skills spanning repository setup,
managed/native interop, Roslyn generators, WinUI 3, MSIX distribution, and visual
assets.

**Version:** 0.1.1

**Catalog:** [`shmuelie-skills`](../../../README.md)

**Changelog:** [`CHANGELOG.md`](../../../CHANGELOG.md)

## Install

```text
copilot plugin marketplace add shmuelie/shmuelie-skills
copilot plugin install shmuelie-dotnet@shmuelie-skills
```

```text
copilot plugin update shmuelie-dotnet
copilot plugin uninstall shmuelie-dotnet
```

## When to install

Use this plugin for modern .NET repositories and Windows desktop applications,
especially when code crosses managed/native boundaries or ships as MSIX.

## Skills

| Skill | Use it for |
|---|---|
| [`csharp-interop`](skills/csharp-interop/SKILL.md) | COM interfaces and servers, P/Invoke source generation, native hosting, Native AOT, shell extensions, and IPC |
| [`dotnet-project-init`](skills/dotnet-project-init/SKILL.md) | Central build configuration, solution migration, test runners, CI, packaging, and versioning |
| [`icon-assets`](skills/icon-assets/SKILL.md) | Generate complete MSIX, NuGet, web, PNG, SVG, and ICO asset sets |
| [`msix-store-submission`](skills/msix-store-submission/SKILL.md) | Align Partner Center identity, packaging, signing, versioning, and submission CI |
| [`roslyn-sourcegen`](skills/roslyn-sourcegen/SKILL.md) | Build and test incremental generators and analyzers with stable equatable pipelines |
| [`winui3-msix`](skills/winui3-msix/SKILL.md) | Resolve binding, packaging, loose-registration, testing, and dependency-injection issues |

## Example requests

```text
Set up this repository with Directory.Build.props and a .slnx solution.
Generate a COM interface with CsWin32 and GeneratedComInterface.
Fix this incremental generator so caching works correctly.
Package this WinUI 3 application as a self-contained MSIX.
Create every required visual asset for this application.
Prepare this package for Microsoft Store submission.
```

## Requirements

Requirements vary by skill and may include a current .NET SDK, Visual Studio
Build Tools, Windows App SDK, MSIX tooling, CsWin32, or Roslyn packages.
