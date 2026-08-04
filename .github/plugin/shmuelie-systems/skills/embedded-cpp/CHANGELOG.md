# Changelog — embedded-cpp

Notable changes to the **embedded-cpp** skill. Repository-wide and marketplace
history is in the
[repository changelog](https://github.com/shmuelie/shmuelie-skills/blob/main/CHANGELOG.md).

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

## 2026-08-02

### Added
- C++-standard-vs-libc decoupling, libstdc++ size flags
  (`--enable-clocale=generic`, `--disable-libstdcxx-verbose`), long-running-freeze
  leak diagnosis via a host valgrind harness, and MQTT QoS 0 retained for
  telemetry.

## 2026-05-07

### Added
- Old kernel / uClibc compatibility (`statx` failure, `std::filesystem`
  auto-detection, path pitfalls, CR corruption), MQTT topic ID deduplication, and
  multi-project monorepo versioning.

## 2026-03-21

### Added
- Initial skill: Buildroot external tree for cross-compilation, CMake presets,
  binary size optimization, `FetchContent`, Catch2 testing, C++20 conventions, and
  MQTT Home Assistant auto-discovery.
