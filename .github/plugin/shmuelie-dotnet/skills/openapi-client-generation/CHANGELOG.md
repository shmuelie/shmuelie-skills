# Changelog - openapi-client-generation

Notable changes to the **openapi-client-generation** skill. Repository-wide and
marketplace history is in the
[repository changelog](https://github.com/shmuelie/shmuelie-skills/blob/main/CHANGELOG.md).

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added
- Initial guidance for reproducible .NET OpenAPI client generation, provenance,
  generated-output boundaries, base-URL ownership, fake-transport tests, and
  combination-specific trimming and Native AOT qualification.
- A pinned Kiota fixture that regenerates twice, compares output hashes, builds
  the generated client, verifies endpoint overwrite order without network
  access, and can publish/run a warning-clean trimmed RID.
