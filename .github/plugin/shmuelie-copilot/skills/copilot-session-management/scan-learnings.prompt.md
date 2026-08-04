---
description: >-
  Scan recent Copilot sessions and PowerShell command history for new
  domain knowledge and patterns, then update or create skills with the
  learnings. Bumps plugin version and updates changelog.
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
     `.github/plugin/<plugin>/skills/<name>/SKILL.md` with YAML frontmatter
   - Include code examples, gotchas, and specific error messages

6. **Bump versions**:
   - Find the owning plugin under `.github/plugin/<plugin>/skills/<name>`
   - Increment that plugin's `plugin.json` version
   - Match its entry in `.github/plugin/marketplace.json`
   - If the aggregate root plugin loads the skill, increment root `plugin.json`
     and the `shmuelie-skills` marketplace entry
   - Update skill-level version in frontmatter if changed

7. **Update documentation**:
   - Add a changelog entry in root `CHANGELOG.md`
   - Update the owning plugin's `README.md` and root `README.md` if a skill was added
   - Update `.github/copilot-instructions.md` when marketplace maintenance rules change

8. **Commit** with a descriptive message listing which skills were updated and what was added.
