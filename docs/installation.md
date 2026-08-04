---
title: Installation
---

**[Home](index.md) · [Installation](installation.md) · [Plugins](plugins.md) · [Contributing](contributing.md) · [GitHub](https://github.com/shmuelie/shmuelie-skills)**

# Installation

Install the full catalog or only the focused plugins you need.

## Aggregate installation

The root plugin includes every skill from all focused plugins.

```text
copilot plugin install shmuelie/shmuelie-skills
```

## Focused installation

Add the marketplace once, browse it, then install the plugins you want.

```text
copilot plugin marketplace add shmuelie/shmuelie-skills
copilot plugin marketplace browse shmuelie-skills
copilot plugin install shmuelie-dotnet@shmuelie-skills
copilot plugin install shmuelie-devenv@shmuelie-skills
```

## Direct subdirectory installation

A focused plugin can also be installed without registering the marketplace.

```text
copilot plugin install shmuelie/shmuelie-skills:.github/plugin/shmuelie-dotnet
```

## Verify installation

```text
copilot plugin list
```

In an interactive session, use `/skills list` to inspect available skills.

## Update or remove

```text
copilot plugin update plugin-name
copilot plugin update --all
copilot plugin uninstall plugin-name

copilot plugin marketplace update shmuelie-skills
copilot plugin marketplace remove shmuelie-skills
```

## Environment scope

Plugin installation is local to the environment where Copilot CLI runs. Install
again in WSL, containers, SSH hosts, or remote development machines.

## Troubleshooting

- Confirm the repository and plugin subdirectory are reachable.
- Update the marketplace before installing a newly added plugin.
- Reinstall after testing changes from a local clone.
- Check that `plugin.json` paths are relative to the plugin root.
- Use `copilot plugin list` to confirm which source is installed.
