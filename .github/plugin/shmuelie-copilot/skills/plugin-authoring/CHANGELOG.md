# Changelog — plugin-authoring

Notable changes to the **plugin-authoring** skill. Repository-wide and
marketplace history is in the
[repository changelog](https://github.com/shmuelie/shmuelie-skills/blob/main/CHANGELOG.md).

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added
- Hooks (lifecycle plugins) section: the plugin loader drops `plugin.json`
  `hooks`; file-based `copilot-hooks.json` loads only via Agency `--plugin-dir`
  or in-repo `.github/hooks/`; `${PLUGIN_ROOT}`; Copilot CLI has no completion
  event (only `errorOccurred`); fire-and-forget launcher rules.

## 2026-08-03

### Added
- Initial skill: author single plugins and independently versioned multi-plugin
  marketplaces for the public GitHub Copilot CLI, including manifests, skill
  conventions, in-repository discovery, versioning, and a validation checklist.

### Changed
- Rewritten around native public Copilot CLI marketplace commands, dropping any
  private orchestration tooling and per-engine internal conventions.
