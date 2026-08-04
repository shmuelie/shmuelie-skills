# shmuelie-copilot

Copilot CLI meta-tooling: understand and operate the agent itself — analyze
sessions, generate reports and playbooks, repair session state, and publish your
own plugins.

**Version:** 0.2.1

## Install

```text
copilot plugin marketplace add shmuelie/shmuelie-skills
copilot plugin install shmuelie-copilot@shmuelie-skills
```

Update or remove:

```text
copilot plugin update shmuelie-copilot
copilot plugin uninstall shmuelie-copilot
```

## Skills

### copilot-playbook

Generate a teaching guide for how you drive the agent — plan→implement, commit
granularity, ask-before-act, terse corrections, PR lifecycle, and verification —
with copyable real prompts mined from session history. It is the narrative
sibling of `copilot-usage-report`: lessons and style rather than metrics.

### copilot-session-management

Diagnose and safely repair Copilot CLI sessions and manage local state:

- Session layout under `~/.copilot/session-state/<id>/` (`workspace.yaml`,
  `events.jsonl`, `plan.md`, checkpoints, rewind snapshots).
- A back-up-first repair workflow and resume-failure troubleshooting.
- Plugin, marketplace, and MCP management with native `copilot plugin ...` and
  `copilot plugin marketplace ...` commands.

### copilot-session-report

Produce a detailed per-session report covering the problem statement, solution
approach, tools and skills used, files modified with line counts, testing
results, key learnings, a tool assessment, and pending work — suitable for PR
descriptions and knowledge sharing.

### copilot-usage-report

Analyze session history across multiple dimensions: session shape, hour/day
timing patterns, prompting style, model and file-type fingerprint, and
behavioral patterns, rendered as tables and charts.

### plugin-authoring

Author single plugins and independently versioned multi-plugin marketplaces for
the public GitHub Copilot CLI: `plugin.json` and `marketplace.json` structure,
self-contained plugin sources, `SKILL.md` and prompt-template conventions,
in-repository discovery, versioning, and a validation checklist.

## Example requests

```text
Generate a report for this Copilot session.
Analyze how I have been using Copilot CLI over the last month.
Create a playbook that teaches my prompting style.
Diagnose why this session no longer resumes.
Package these skills as a Copilot CLI marketplace.
```

## Requirements

- GitHub Copilot CLI.
- Session history for the reporting and playbook skills.
- Optional local MCP configuration for tool inventory.

Reporting skills analyze only session history and files available in the current
environment; review generated reports before sharing, as session text may
contain repository paths and prompts.

## Changelog

Each skill has its own `CHANGELOG.md`; marketplace-wide history is in the
[repository changelog](../../../CHANGELOG.md).
