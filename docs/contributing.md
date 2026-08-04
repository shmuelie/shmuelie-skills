---
title: Contributing
---

**[Home](index.md) · [Installation](installation.md) · [Plugins](plugins.md) · [Contributing](contributing.md) · [GitHub](https://github.com/shmuelie/shmuelie-skills)**

# Contributing

A useful skill captures a repeatable technique, a non-obvious failure mode, or a
workflow that applies beyond one repository.

## Choose an owner

Every skill belongs to exactly one focused plugin. Reuse an existing plugin when
the topic fits coherently; create a new plugin only for a distinct subject area.

## Create the skill

```text
.github/plugin/<plugin>/skills/<skill-name>/SKILL.md
.github/plugin/<plugin>/skills/<skill-name>/CHANGELOG.md
```

Each skill directory contains its own `SKILL.md` and `CHANGELOG.md`.

Required frontmatter:

```markdown
---
name: example-skill
description: "Specific capability and trigger phrases. Use when asked to..."
---
```

## Content expectations

- Explain when the pattern applies and when it does not.
- Include commands, code, error messages, and concrete fixes.
- Document failure modes and tradeoffs, not only the happy path.
- Remove credentials, private endpoints, and organization-only dependencies.
- Prefer public documentation links and portable examples.

## Update release surfaces

1. Add an entry to the skill's own `CHANGELOG.md` (each skill directory has one).
2. Update the owning plugin README.
3. Bump the owning plugin's semantic version.
4. Match the version in `marketplace.json`.
5. Bump the aggregate plugin when installed skill content changes.
6. Update the root README, documentation site, and repository changelog.

## Validate

```powershell
pwsh ./scripts/Test-Marketplace.ps1
copilot plugin marketplace add .
copilot plugin marketplace browse shmuelie-skills
```

The validator rejects malformed manifests, missing skill paths, duplicate skill
ownership, and root-level skill directories.
