# Changelog — copilot-session-management

Notable changes to the **copilot-session-management** skill. Repository-wide and
marketplace history is in the
[repository changelog](https://github.com/shmuelie/shmuelie-skills/blob/main/CHANGELOG.md).

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added
- Expanded safe session repair guidance with request/result pairing, session-
  relative event ordering, minimal in-place edits, cross-reference validation,
  and fictional repair fixtures for truncated results, equal timestamps,
  interleaved sessions, and dangling references.

### Fixed
- Aligned the scan-learnings prompt with release-based versioning: content scans
  preserve existing plugin and catalog versions, record per-skill and repository
  changes under `[Unreleased]`, update the owning plugin README, and run
  marketplace validation without adding skill-level version frontmatter.

## 2026-08-09

### Added
- Windows desktop notification diagnostics: the built-in native toast under
  AUMID `GitHub.Copilot.CLI`, focus-gated (DECSET 1004) firing, and a checklist
  for missing toasts (unregistered AUMID silently drops banners, global/app
  toggles, `COPILOT_DISABLE_DESKTOP_NOTIFICATIONS`, testing via Windows
  PowerShell 5.1).

## 2026-08-03

### Added
- Initial skill: Copilot CLI session state, safe repair workflow, resume
  troubleshooting, plugin and marketplace management, and MCP configuration.

### Changed
- Rewritten around native public Copilot CLI commands
  (`copilot plugin ...`, `copilot plugin marketplace ...`), removing any private
  orchestration tooling, profiles, or built-in MCP references.
