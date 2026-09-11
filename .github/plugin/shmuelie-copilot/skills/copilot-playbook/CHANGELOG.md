# Changelog — copilot-playbook

Notable changes to the **copilot-playbook** skill. Repository-wide and
marketplace history is in the
[repository changelog](https://github.com/shmuelie/shmuelie-skills/blob/main/CHANGELOG.md).

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

## 2026-09-10

### Changed
- Added reusable guidance for teaching delegated-work supervision in playbooks:
  bound the objective and scope up front, ask for milestone updates with
  blockers and next steps, rely on supported notifications instead of tight
  polling, and show safe responses to success, drift, blockers, and missing
  live progress.

## 2026-08-03

### Added
- Initial skill: generate a teaching guide for effective Copilot CLI workflows,
  mining session history for verbatim example prompts per behavioral pattern.

### Changed
- Uses public Copilot CLI commands (`copilot plugin list`,
  `copilot plugin marketplace list`) and portable MCP examples instead of any
  private plugin, profile, or tooling references.
