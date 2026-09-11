# Changelog — linqpad-duckdb

Notable changes to the **linqpad-duckdb** skill. Repository-wide and
marketplace history is in the
[repository changelog](https://github.com/shmuelie/shmuelie-skills/blob/main/CHANGELOG.md).

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

## 2026-09-11

### Added

- Initial LINQPad and DuckDB.NET workflow for synthetic Parquet/Delta analysis,
  optional Azure credential-chain access, Delta column mapping, scan-cost
  caveats, and layered failure reporting.
- A pinned no-cloud .NET fixture that verifies physical Parquet selection and
  conditionally exercises a real local Delta extension read.
