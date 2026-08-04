# Changelog — dotnet-project-init

Notable changes to the **dotnet-project-init** skill. Repository-wide and
marketplace history is in the
[repository changelog](https://github.com/shmuelie/shmuelie-skills/blob/main/CHANGELOG.md).

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

## 2026-08-02

### Added
- `.sln` to `.slnx` migration (`dotnet sln migrate`) and mixed C#/C++ toolset
  modernization (PlatformToolset upgrade, CppWinRT 3.0 proxy winmd verification).

## 2026-05-31

### Fixed
- Assembly version access corrected to the AOT-safe `typeof(T).Assembly` instead
  of stack-frame reflection.

## 2026-05-20

### Added
- MTP vs VSTest runner conflict warning for .NET 10+ and the
  `AssemblyInformationalVersionAttribute` access pattern.

## 2026-03-22

### Added
- Keep a Changelog and Semantic Versioning guidance.

## 2026-03-21

### Added
- Initial skill: `Directory.Build.props` centralized configuration, `global.json`
  test-runner setup, NuGet `ExcludeAssets` patterns, and GitHub Actions CI
  workflows for .NET and MSIX.
