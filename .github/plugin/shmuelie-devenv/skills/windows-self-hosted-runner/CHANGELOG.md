# Changelog - windows-self-hosted-runner

Notable changes to the **windows-self-hosted-runner** skill. Repository-wide and
marketplace history is in the
[repository changelog](https://github.com/shmuelie/shmuelie-skills/blob/main/CHANGELOG.md).

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added
- Initial skill for bootstrapping a Windows self-hosted GitHub Actions runner on
  a clean released VM image, selecting workload-compatible SDK and native tools,
  discovering and validating the actual service identity, handling
  service-account SDK permission failures, separating lifecycle readiness
  stages, protecting short-lived registration credentials, and performing
  created-resource-only rollback.
