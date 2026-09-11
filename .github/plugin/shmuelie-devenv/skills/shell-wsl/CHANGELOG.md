# Changelog — shell-wsl

Notable changes to the **shell-wsl** skill. Repository-wide and marketplace
history is in the
[repository changelog](https://github.com/shmuelie/shmuelie-skills/blob/main/CHANGELOG.md).

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added
- tmux server-vs-pane environment guidance: scope temporary variables to the
  created child, avoid leaking one-off values through global server state, and
  prefer fresh panes/windows for alternate toolchains.

## 2026-08-02

### Added
- One-connection `tar`-over-SSH deployment (`-ch` / symlink follow), a
  version-aware updater (`--version` vs GitHub tag with a portable semver
  comparator), and output quieting (`apt-get -qq`, keeping stderr/status lines).

## 2026-07-20

### Added
- Cargo.lock reproducibility: commit the lockfile for binaries, how unpinned
  transitive dependencies break over time, and `cargo tree -i` diagnosis.

## 2026-03-21

### Added
- Initial skill: shell script bugs (`exit` vs `return`, quoting, `mkdir -p`),
  `set -euo pipefail`, WSL systemd detection, APT troubleshooting, embedded device
  deployment, and Rust/Cargo clippy patterns.
