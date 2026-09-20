# shmuelie-dotnet

.NET and Windows application engineering: repository setup, managed/native
interop, Roslyn generators, WinUI 3, MSIX distribution, visual assets, and
LINQPad/DuckDB data analysis.

**Version:** 1.3.0

## Install

```text
copilot plugin marketplace add shmuelie/shmuelie-skills
copilot plugin install shmuelie-dotnet@shmuelie-skills
```

Update or remove:

```text
copilot plugin update shmuelie-dotnet
copilot plugin uninstall shmuelie-dotnet
```

## Skills

### linqpad-duckdb

Pinned DuckDB.NET/native setup, LINQPad query configuration, local synthetic
Parquet/Delta fixtures, optional Azure credential chains and ABFSS addressing,
logical column mapping, and scan-cost limits.

### openapi-client-generation

Reproducible Kiota client generation with pinned inputs/tooling, preserved
specification enrichment, endpoint ownership, and fake-transport tests.
Trimming and AOT claims are qualified by the tested runtime combination.

### event-contracts

Typed diagnostic event schemas, missing-value handling, retry/activity
correlation, and field-level inspection with a synthetic EventSource contract
example and explicit ETW/EventPipe/sink boundaries.

### csharp-interop

COM and P/Invoke interop: CsWin32 setup and `[GeneratedComInterface]` COM
(build-task mode, in-memory generation), COM server/class-factory
(`DllGetClassObject`, `ComInterfaceMarshaller`), shell icon handlers
(`CreateIconFromResourceEx`), native hosting via DNNE/nethost, `LibraryImport`
marshalling, the ConPTY HPCON calling-convention bug,
`NativeLibrary.SetDllImportResolver`, Native AOT + trimming, VT escape-sequence
parsing, IPC message patterns, and plugin path security.

### dotnet-project-init

Modern .NET repository setup: `Directory.Build.props` centralized configuration,
`global.json` test-runner setup for .NET 10+, `.sln`→`.slnx` migration, mixed
C#/C++ toolset modernization, GitHub Actions CI for .NET and MSIX, project
instructions, and general versioning reminders. Detailed library packaging and
publication now belong to the independently installable `shmuelie-nuget` plugin.

### icon-assets

Application and package icon creation: MSIX visual asset sets (sizes,
targetsize/altform-unplated naming), NuGet `PackageIcon` wiring, web favicons,
Fluent and Material design guidelines, and SVG-to-PNG/ICO generation approaches.

### msix-store-submission

Microsoft Store submission for any MSIX app: Partner Center identity alignment,
signing configuration, self-contained packaging with framework-dependency
stripping, 4-part versioning, solution platform locking, a CI/CD workflow,
installer parity (file-type associations, App Paths, context menus, PATH), and
VM testing.

### roslyn-sourcegen

Roslyn incremental source generators: `IIncrementalGenerator` pipeline design,
equatable pipeline models with `EquatableArray<T>`, `ForAttributeWithMetadataName`,
testing with `CSharpGeneratorDriver`, analyzer diagnostic patterns, NuGet
packaging layout, nested-type handling, and common pitfalls.

### winui3-msix

WinUI 3 applications: data binding pitfalls (`{x:Bind}` vs `{Binding}` vs
`[Bindable]`), MSIX packaging (`EnableMsixTooling`, manifest requirements,
loose-file registration), WinAppSDK test project architecture, and dependency
injection patterns.
Includes packaging failure diagnostics for VS MSBuild, RID/restore scope,
trimming/AOT configuration, recursive bundle inputs, and older-platform payloads.

### msix-servicing

MSIX install/update deployment tasks and full-trust `ServicingComplete`
registration, with activation boundaries, idempotent migrations, foreground
recovery, and qualified loose-registration verification.

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
Build Tools, the Windows App SDK, MSIX tooling, CsWin32, or Roslyn packages.

## Changelog

Each skill has its own `CHANGELOG.md`; marketplace-wide history is in the
[repository changelog](../../../CHANGELOG.md).
