# shmuelie-typescript

TypeScript and Node.js command-line application engineering focused on runtime
correctness under concurrency, failure, and filesystem scale.

**Version:** 0.1.0

## Install

```text
copilot plugin marketplace add shmuelie/shmuelie-skills
copilot plugin install shmuelie-typescript@shmuelie-skills
```

Update or remove:

```text
copilot plugin update shmuelie-typescript
copilot plugin uninstall shmuelie-typescript
```

## Skills

### typescript-cli

Reliable TypeScript CLI patterns: process pool management, atomic cache writes
(`.tmp` + rename), cache versioning with migration, adaptive rate limiting,
SIGINT graceful shutdown, multi-tier file matching, Windows `MAX_PATH` handling,
`??` vs `||` pitfalls, and HTTP API client patterns (forced gzip decompression,
Swagger/OpenAPI response drift, cookie-based auth, multi-key filename indexing).

## Example requests

```text
Add a bounded worker pool to this TypeScript CLI.
Make this cache write atomic and add schema migration.
Implement adaptive retry behavior for API rate limits.
Handle SIGINT without losing completed work.
Fix this filename matcher for large Windows directory trees.
Explain why ?? and || behave differently in this configuration parser.
```

## Requirements

Use a maintained Node.js release and the package manager the project already
uses. The skill avoids requiring a specific CLI framework.

## Changelog

Each skill has its own `CHANGELOG.md`; marketplace-wide history is in the
[repository changelog](../../../CHANGELOG.md).
