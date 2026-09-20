# shmuelie-github

GitHub and repository management, from initial issue triage to approved changes
and releases. These skills guide an agent; they are not an automation service
or a replacement for code review.

**Version:** 1.0.0

## Install

Install the focused plugin:

```text
copilot plugin marketplace add shmuelie/shmuelie-skills
copilot plugin install shmuelie-github@shmuelie-skills
```

The aggregate plugin also includes these skills. For local evaluation, pass
`--plugin-dir` with this directory to a separate Copilot CLI session.

## Skills

| Skill | Responsibility |
| --- | --- |
| [github-issue-triage](skills/github-issue-triage/SKILL.md) | Classify issues and apply routine labels/comments |
| [prepare-issue](skills/prepare-issue/SKILL.md) | Research and resolve design questions before implementation |
| [github-pull-requests](skills/github-pull-requests/SKILL.md) | Create/update PRs, coordinate reviews, and perform authorized merges |
| [github-repository-management](skills/github-repository-management/SKILL.md) | Review and apply label/milestone administration plans |
| [github-releases](skills/github-releases/SKILL.md) | Verify tags, stage assets, and publish authorized releases |

## Boundaries

Use `gh` with an explicit repository and the intended authenticated account.
Routine issue labels/comments can be applied during requested triage. Bulk
administration requires an approved target/action plan. Issue closure, scope
consolidation, design decisions, PR merge/closure, and release publication need
explicit authority. A request to prepare an issue is not permission to implement it.

Each skill contains scenario prompts and expected/forbidden actions for
credential-free review. A walkthrough assesses instruction coverage, not
deterministic enforcement or a successful live GitHub operation. Package-feed
publishing belongs to the package ecosystem, not this plugin.

## Requirements and history

GitHub CLI and repository-appropriate read/write access are needed for live use.
No private tooling or other focused plugin is required. Each skill has its own
changelog; see the [repository changelog](../../../CHANGELOG.md) for catalog changes.
