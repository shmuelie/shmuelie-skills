# Changelog — deploy-scripts

Notable changes to the **deploy-scripts** skill. Repository-wide and
marketplace history is in the
[repository changelog](https://github.com/shmuelie/shmuelie-skills/blob/main/CHANGELOG.md).

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

## 2026-03-21

### Added
- Initial skill: `Deploy.ps1` patterns — MSBuild auto-detection via `vswhere`,
  architecture detection, AppX loose-file layout assembly,
  `Add-AppxPackage -Register`, `WinAppDeployCmd` remote deployment, and ADB for
  Android.
