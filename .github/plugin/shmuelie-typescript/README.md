# shmuelie-typescript

TypeScript and Node.js command-line application engineering focused on runtime
correctness, concurrency, caching, rate limits, shutdown, and filesystem scale.

**Version:** 0.1.1

**Catalog:** [`shmuelie-skills`](../../../README.md)

**Changelog:** [`CHANGELOG.md`](../../../CHANGELOG.md)

## Install

```text
copilot plugin marketplace add shmuelie/shmuelie-skills
copilot plugin install shmuelie-typescript@shmuelie-skills
```

```text
copilot plugin update shmuelie-typescript
copilot plugin uninstall shmuelie-typescript
```

## Skill

| Skill | Use it for |
|---|---|
| [`typescript-cli`](skills/typescript-cli/SKILL.md) | Process pools, atomic versioned caches, adaptive rate limiting, graceful shutdown, file matching, API drift, and Windows paths |

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

Use a maintained Node.js release and the package manager already selected by the
project. The skill avoids requiring a specific CLI framework.
