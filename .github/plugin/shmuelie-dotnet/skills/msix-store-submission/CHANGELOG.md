# Changelog — msix-store-submission

Notable changes to the **msix-store-submission** skill. Repository-wide and
marketplace history is in the
[repository changelog](https://github.com/shmuelie/shmuelie-skills/blob/main/CHANGELOG.md).

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

## 2026-07-20

### Added
- Installer parity section (file-type associations, App Paths, context menus, PATH
  via execution aliases when migrating from Inno Setup/MSI) and a VM testing
  section (signing, `-AllowUnsigned`, Developer Mode).

## 2026-05-10

### Added
- Initial skill: Microsoft Store submission for any MSIX app — Partner Center
  identity alignment, signing configuration, self-contained packaging with
  framework-dependency stripping, 4-part versioning, solution platform locking,
  and a CI/CD workflow.
