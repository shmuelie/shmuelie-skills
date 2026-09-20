# Changelog - nuget-package-authoring

Following [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

## 2026-09-20

### Added
- Package content, dependency exposure, metadata, symbols, and clean-consumption guidance.
- Reusable policy-driven package inspector wired into CI and release templates,
  with valid-archive and missing/mismatched-content regression cases.
- Verify Source Link mappings cover non-embedded documents and reject undeclared
  native/runtime/build layouts regardless of filename extension.
