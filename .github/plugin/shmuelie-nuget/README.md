# shmuelie-nuget

Create, package, validate, and release .NET libraries. Includes four skills,
copyable GitHub Actions workflows, and one deliberately non-publishing example.

**Version:** 1.0.0

## Install

Install the focused plugin:

```text
copilot plugin marketplace add shmuelie/shmuelie-skills
copilot plugin install shmuelie-nuget@shmuelie-skills
```

The root aggregate includes the same skills. No GitHub-management plugin,
private tooling, scaffolding CLI, or template package is required.

## Skills

| Skill | Use it for |
| --- | --- |
| [dotnet-library-projects](skills/dotnet-library-projects/SKILL.md) | API/framework choices, library/test/consumer structure |
| [nuget-package-authoring](skills/nuget-package-authoring/SKILL.md) | Package metadata, assets, dependency exposure, symbols |
| [dotnet-library-ci](skills/dotnet-library-ci/SKILL.md) | Credential-free CI and clean package consumption |
| [nuget-release](skills/nuget-release/SKILL.md) | SemVer/changelog, tag validation, trusted publishing, recovery |

General .NET application setup remains in `shmuelie-dotnet`; PowerShell Gallery
and Azure Pipelines guidance remain in `shmuelie-devenv`.

## Example and validation

Requires PowerShell 7.4+, Git, and .NET SDK 10.0.401. Dependency restore requires
NuGet connectivity; publishing tests do not use credentials or contact feeds.

```powershell
pwsh -NoProfile -File .\skills\nuget-release\examples\Test-Release.ps1 -ScratchRoot $env:TEMP
pwsh -NoProfile -File .\skills\dotnet-library-projects\examples\Test-Fixture.ps1 -ScratchRoot $env:TEMP
```

The fixture creates a unique child under the existing scratch root. It tests,
packs, inspects, consumes from a local feed with an isolated package cache, and
exercises `-WhatIf` without invoking publication. Failures retain that child for
diagnosis; success removes only the child unless `-KeepArtifacts` is used.
The Linux equivalent can use `/tmp` as its scratch root.

Workflows under `templates/` are inert here. Copy and configure them deliberately
in a consuming repository following the release skill. The fixture package ID
is rejected by the live publication entry point.

Local and fake-transport validation does not prove NuGet permissions, indexing,
symbol ingestion, GitHub environment protection, or live release publication.
Those require a separately authorized integration run. Each skill has its own
changelog; see the [repository changelog](../../../CHANGELOG.md).
