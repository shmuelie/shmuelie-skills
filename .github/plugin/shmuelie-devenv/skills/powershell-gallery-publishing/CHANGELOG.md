# Changelog — powershell-gallery-publishing

Notable changes to the **powershell-gallery-publishing** skill. Repository-wide and
marketplace history is in the
[repository changelog](https://github.com/shmuelie/shmuelie-skills/blob/main/CHANGELOG.md).

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

## 2026-09-10

### Added
- Initial skill: publishing PowerShell modules to the PowerShell Gallery from a
  tag-triggered GitHub Actions workflow — `<Module>-vX.Y.Z` release tags, verifying the
  tag version matches the manifest `ModuleVersion`, API keys scoped with a glob pattern and
  gated behind a named environment, cutting a release (promote `[Unreleased]`, tag, push),
  the gotcha that GitHub fires no tag workflow events when more than three tags are pushed at
  once, and first-come module-name reservation.
