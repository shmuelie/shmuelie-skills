# Changelog — powershell-scripting

Notable changes to the **powershell-scripting** skill. Repository-wide and
marketplace history is in the
[repository changelog](https://github.com/shmuelie/shmuelie-skills/blob/main/CHANGELOG.md).

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

## 2026-08-02

### Added
- Initial skill: idiomatic PowerShell for destructive and bulk scripts —
  `SupportsShouldProcess` + `ConfirmImpact`, native `-WhatIf`/`-Confirm` instead of
  custom `-Execute`/typed-`yes` gates, per-operation `$PSCmdlet.ShouldProcess`,
  anti-patterns to replace, and preview-then-apply verification.
