# Changelog — csharp-interop

Notable changes to the **csharp-interop** skill. Repository-wide and marketplace
history is in the
[repository changelog](https://github.com/shmuelie/shmuelie-skills/blob/main/CHANGELOG.md).

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

## 2026-08-02

### Added
- CsWin32 `[GeneratedComInterface]` support and build-task mode, in-memory
  generation, COM server / class-factory patterns (`DllGetClassObject`,
  `ComInterfaceMarshaller`), shell icon handlers (`CreateIconFromResourceEx`),
  and a native hosting section (DNNE / nethost).

## 2026-03-21

### Added
- Initial skill: CsWin32 and `LibraryImport` marshalling, ConPTY HPCON calling
  convention bug, `NativeLibrary.SetDllImportResolver`, Native AOT + trimming, VT
  escape-sequence parsing, IPC message patterns, and plugin path security.
