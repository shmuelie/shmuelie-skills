# Changelog — writing-level-analysis

Notable changes to the **writing-level-analysis** skill. Repository-wide and
marketplace history is in the
[repository changelog](https://github.com/shmuelie/shmuelie-skills/blob/main/CHANGELOG.md).

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

## 2026-09-11

### Fixed
- Preserved authored punctuation during corpus preparation, documented record
  separators and scorer context, and added a synthetic example distinguishing
  segmentation-driven score changes from changes in writing quality.

## 2026-08-03

### Added
- Initial skill: Flesch-Kincaid grade level and corroborating readability indices
  with per-source reporting and a combined result.

### Changed
- Reworked to operate only on user-provided or locally authored text, removing
  any dependency on private mail or organization systems.
- Combined metrics are recomputed from the full cleaned corpus rather than
  averaging per-document scores.
