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
3. Record the change under `## [Unreleased]` in the repository `CHANGELOG.md`.
4. Update the root README and documentation site if the catalog changed.

**Do not bump any version for a content change.** Plugin versions
(`plugin.json` and their `marketplace.json` entries) and the catalog
`metadata.version` change only when a release is cut — see
[Releasing](#releasing). Between releases, versions stay fixed and changes
accumulate under `[Unreleased]`.

## Releasing

A release is the only time versions change:

1. Choose the plugins included in the release and their new semantic versions.
2. Update each released plugin's `plugin.json` and its `marketplace.json` entry;
   update `metadata.version` only if the catalog composition changed.
3. Move the relevant `[Unreleased]` notes into a dated version section in the
   repository `CHANGELOG.md` and update the comparison links.
4. Update the `**Version:**` header in each released plugin README.
5. Commit, tag the release, and publish.

## Validate

```powershell
pwsh ./scripts/Test-Marketplace.ps1
copilot plugin marketplace add .
copilot plugin marketplace browse shmuelie-skills
```

The validator rejects malformed manifests, missing skill paths, duplicate skill
ownership, and root-level skill directories.
