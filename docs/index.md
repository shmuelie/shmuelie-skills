---
title: Shmuelie Copilot Skills
---

**[Home](index.md) · [Installation](installation.md) · [Plugins](plugins.md) · [Contributing](contributing.md) · [GitHub](https://github.com/shmuelie/shmuelie-skills)**

Reusable [GitHub Copilot CLI](https://docs.github.com/en/copilot/concepts/agents/copilot-cli/about-cli-plugins)
skills distilled from real software, infrastructure, automation, and authoring
projects.

The marketplace supports two installation styles:

- **Aggregate plugin** — install every skill with one command.
- **Focused plugins** — install only the subject areas you use.

## Quick start

```text
copilot plugin install shmuelie/shmuelie-skills
```

Then, inside an interactive session:

```text
/skills list
```

See the [installation guide](installation.md) for focused plugins, updates, and
troubleshooting.

## Marketplace at a glance

| Plugins | Skills | Aggregate installs |
|---:|---:|---:|
| 8 | 41 | 1 |

## Focused plugins

| Plugin | Skills | Best for |
|---|---:|---|
| [`shmuelie-nuget`](plugins.md#shmuelie-nuget) | 4 | Library projects, NuGet authoring, CI, and releases |
| [`shmuelie-github`](plugins.md#shmuelie-github) | 5 | Issue/PR workflows, design readiness, repository administration, and releases |
| [`shmuelie-copilot`](plugins.md#shmuelie-copilot) | 5 | Copilot sessions, reports, playbooks, and plugin authoring |
| [`shmuelie-devenv`](plugins.md#shmuelie-devenv) | 9 | PowerShell, shell, deployment, CI, local MCP servers, and threat-model files |
| [`shmuelie-authoring`](plugins.md#shmuelie-authoring) | 4 | RFC-style specifications, readability, project proposals, and artwork |
| [`shmuelie-dotnet`](plugins.md#shmuelie-dotnet) | 10 | .NET, API clients, interop, diagnostics, DuckDB, WinUI 3, MSIX, and assets |
| [`shmuelie-systems`](plugins.md#shmuelie-systems) | 3 | Embedded C++, homelab infrastructure, and AI accelerators |
| [`shmuelie-typescript`](plugins.md#shmuelie-typescript) | 1 | Reliable TypeScript and Node.js command-line applications |

The aggregate `shmuelie-skills` plugin references all eight focused skill
directories. Each skill has exactly one focused owning plugin.

## How skills activate

Copilot CLI uses each skill's frontmatter `description` as its discovery
surface, so the relevant skill loads automatically when a request matches. You
can also name a skill explicitly:

```text
Use the powershell-scripting skill to review this deployment script.
```

A skill supplies domain context and workflow guidance. It does not install the
external tools it documents.

## Public by design

The marketplace excludes credentials, private endpoints, organization-only
systems, and tooling unavailable to public Copilot CLI users. See the
[contribution guide](contributing.md) to add a skill.
