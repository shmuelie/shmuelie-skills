# shmuelie-copilot

Copilot CLI workflow skills for understanding sessions, measuring usage,
documenting work, teaching effective prompting patterns, and publishing plugins.

**Version:** 0.2.1

**Catalog:** [`shmuelie-skills`](../../../README.md)

**Changelog:** [`CHANGELOG.md`](../../../CHANGELOG.md)

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

## When to install

Install this plugin when you regularly use Copilot CLI and want repeatable
workflows around session recovery, reporting, self-analysis, or plugin
distribution. It is useful to both plugin consumers and marketplace authors.

## Skills

| Skill | Use it for |
|---|---|
| [`copilot-playbook`](skills/copilot-playbook/SKILL.md) | Turn real sessions into a teaching guide with reusable prompting patterns |
| [`copilot-session-management`](skills/copilot-session-management/SKILL.md) | Diagnose resume failures, repair local session files, and manage public plugins and MCP configuration |
| [`copilot-session-report`](skills/copilot-session-report/SKILL.md) | Produce a structured report covering intent, tools, files, testing, learnings, and pending work |
| [`copilot-usage-report`](skills/copilot-usage-report/SKILL.md) | Measure session shape, timing, prompting style, models, and technical patterns |
| [`plugin-authoring`](skills/plugin-authoring/SKILL.md) | Create single plugins or independently versioned public marketplaces |

## Example requests

```text
Generate a report for this Copilot session.
Analyze how I have been using Copilot CLI over the last month.
Create a playbook that teaches my prompting style.
Diagnose why this session no longer resumes.
Package these skills as a Copilot CLI marketplace.
```

## Data and privacy

Reporting skills analyze only session history and files available in the current
environment. Review generated reports before sharing them because session text
may contain repository paths, prompts, or project-specific details.

## Requirements

- GitHub Copilot CLI
- Session history for reporting and playbook generation
- Optional local MCP configuration for tool inventory
