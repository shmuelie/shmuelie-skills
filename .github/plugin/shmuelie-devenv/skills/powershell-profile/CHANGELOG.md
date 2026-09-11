# Changelog — powershell-profile

Notable changes to the **powershell-profile** skill. Repository-wide and
marketplace history is in the
[repository changelog](https://github.com/shmuelie/shmuelie-skills/blob/main/CHANGELOG.md).

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added
- Validated Windows Terminal directory reporting and origin-scoped popup
  suppression before shared cache/status reads or writes, with control-safe
  payload fixtures and lifetime-qualified owner identities.
- Lifetime-qualified shared cache identities, lock-scoped read/compare/write,
  and atomic snapshot publication guidance, with a disposable lab covering
  restart, PID reuse, concurrent writers, timeout, abandonment, and cleanup.
- Ownership-preserving configuration guidance covering link/relative-target
  inspection, isolated writer probes, non-overwriting backups, explicit drift
  review, and broken-link recovery without discarding unresolved settings.
- Launch-boundary guidance distinguishing shell command resolution, native
  process creation, command shims, launcher/child exit behavior, and isolated
  toolchain environments.

### Fixed
- Replaced per-startup CLI version probes for completion-cache validation with
  application discovery, executable/cache timestamps, and a configurable maximum
  age. Added missing-tool, generator-failure, source-identity, and safe-cache
  guidance plus explicit cache-hit and cache-miss expectations.

## 2026-08-03

### Added
- Initial skill: PowerShell profile architecture, PSReadLine configuration, prompt
  customization, argument completers and PSReadLine predictors, versioned
  side-by-side module deployment, and terminal-mode recovery.

### Changed
- Generalized to public tooling: removed internal build-environment,
  orchestration-CLI, and private cmdlet references in favor of portable examples.
