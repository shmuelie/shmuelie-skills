# Canonical library fixture

`src/Fixture.Library` supplies checked integer addition; `tests` tests the source
project; `consumer` consumes the exact packed version through NuGet instead of a
project reference. No application or network service is required.

Run `Test-Fixture.ps1 -ScratchRoot <existing-directory>` from PowerShell 7.4+
with .NET SDK 10.0.401 available. The test runner is the SDK-scaffolded MSTest
4.0.2 project; no `global.json` MTP override is used.

The harness copies sources to a unique scratch child, creates a local fictional
Git repository, and restores into a fresh package cache. It never contacts that
Git remote. The consumer restores exclusively from the newly packed local feed.
Framework/test dependencies may require public NuGet access.

`New-ReleasePlan.ps1` and `Release.Common.ps1` belong to the sibling
`nuget-release` skill; there is only one copy of those helpers. `-WhatIf` checks
the resulting package hashes but must not call any publication transport.

This fixture is not a production package identity, release, or AOT certification.
