# Changelog - project-proposal

Notable changes to the **project-proposal** skill. Repository-wide and
marketplace history is in the
[repository changelog](https://github.com/shmuelie/shmuelie-skills/blob/main/CHANGELOG.md).

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

## 2026-09-11

### Added

- Initial offline proposal workflow with compact and split layouts, safe
  non-overwriting scaffolding, configurable short-field counting, and
  structural/link validation.

### Changed

- Detect changed briefs, schemas, and templates on rerun; publish complete
  packages atomically and repair missing files without replacing authored
  content.
- Require declared JSON array shapes and validate reference links, heading
  fragments, rooted paths, and reparse-point traversal offline.
