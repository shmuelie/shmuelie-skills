---
description: >-
  Scan recent Copilot sessions and PowerShell command history for new
  domain knowledge and patterns, then update or create skills with the
  learnings. Records changes under Unreleased without changing versions.
---

# Scan for New Learnings

Scan my recent Copilot sessions and PowerShell history for new patterns, gotchas, and domain knowledge that should be captured in skills.

## Steps

1. **Query session history** — use `session_store` SQL to find sessions from the last 7-14 days across all repos. Focus on sessions with summaries, file edits, and multiple turns.

2. **Query PowerShell history** — read `(Get-PSReadLineOption).HistorySavePath` for the last 500-1000 commands. Look for:
   - Frequently repeated command patterns (group and sort by count)
   - `cd $varname` patterns revealing common navigation paths
   - Build/deploy commands (`dotnet build`, `dotnet run`, `msbuild`, package-manager commands)
   - Error recovery patterns (commands repeated with different flags)
   - Tool-specific invocations that show non-obvious usage

3. **Identify learnings** — look for:
   - Bug patterns and fixes (especially "CRITICAL" gotchas)
   - New tool/API usage patterns with non-obvious configuration
   - Workflow optimizations (performance, automation, shortcuts)
   - Error messages and their resolutions
   - Architecture decisions and rationale
   - Recurring command sequences that should be documented

4. **Compare against existing skills** — read
   `.github/plugin/*/skills/*/SKILL.md` to check if the learning is already
   captured. Skip duplicates and identify the focused owning plugin.

5. **Update or create skills** — for each new learning:
   - If it fits an existing skill, add a new section or bullet points
   - If it's a new domain, choose or create a focused plugin, then create
     `.github/plugin/<plugin>/skills/<name>/SKILL.md` with `name` and
     `description` in YAML frontmatter; do not add a skill-level `version` field
   - Include code examples, gotchas, and specific error messages

6. **Keep versions unchanged** — a content scan is not a release:
   - Leave existing focused and aggregate `plugin.json` versions unchanged,
     along with their `.github/plugin/marketplace.json` entry versions and the
     catalog `metadata.version`
   - Leave README `**Version:**` headers unchanged
   - Reserve version bumps, dated release sections, tags, and publication for a
     separate, deliberate release following the repository's
     [release process](https://github.com/shmuelie/shmuelie-skills/blob/main/docs/contributing.md#releasing)

7. **Record unreleased changes and update documentation**:
   - Add an entry under `## [Unreleased]` in each changed skill's own
     `.github/plugin/<plugin>/skills/<name>/CHANGELOG.md`; create this changelog
     for a new skill
   - Add a catalog-level entry under `## [Unreleased]` in root `CHANGELOG.md`
   - Update the owning plugin's `README.md` to describe the changed guidance
   - Update root `README.md` and the documentation site only if the catalog
     changed, such as when adding a skill or focused plugin
   - Update `.github/copilot-instructions.md` when marketplace maintenance rules change

8. **Validate** — run `pwsh ./scripts/Test-Marketplace.ps1` and review the diff.
   Confirm that existing plugin and catalog versions are unchanged, every changed
   skill has an unreleased changelog entry, and any new skill has exactly one
   focused owner with the required manifest and catalog wiring.

9. **Commit** with a descriptive message listing which skills were updated and what was added.

## Content-only example

Adding a cache-invalidation gotcha to an existing skill updates its `SKILL.md`,
its `CHANGELOG.md`, the owning plugin's `README.md`, and root `CHANGELOG.md`.
Both changelog entries go under `[Unreleased]`. Existing manifest versions,
marketplace versions, and README version headers stay unchanged; no skill-level
version field is added. Because the catalog did not change, root `README.md` and
the documentation site do not need updates.
