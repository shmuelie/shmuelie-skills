# Copilot Instructions for shmuelie-skills

## Project Overview

This is a Copilot CLI plugin that packages domain knowledge as reusable skills in `skills/*/SKILL.md` files. The plugin is installed via `copilot plugin install shmuelie/shmuelie-skills`.

## Scanning for New Learnings

When asked to scan for new learnings or update skills, follow this process:

### Step 1: Query Copilot CLI session stores

Use the `sql` tool with `database: "session_store"` to search for sessions since the last sweep:
- `search_index` for technical patterns, conventions, and bug fixes
- `checkpoints` for detailed technical knowledge
- `sessions` and `turns` for conversation content

Also check WSL session stores — copy `$HOME/.copilot/session-store.db` from each WSL distro to a temp file via `wsl`, then query with Python/sqlite3.

### Step 2: Scan VS Code chat sessions (JSONL and JSON)

Check `%APPDATA%/Code/User/workspaceStorage/*/chatSessions/` for `.jsonl` and `.json` files larger than 200 bytes.

**JSONL format** (incremental updates):
- **Line kind=0**: Initial session state (contains `v.requests`, `v.customTitle`)
- **Line kind=1**: Incremental updates keyed by JSON array paths (`k` field):
  - `["customTitle"]` → session title (string `v`)
  - `["inputState", "inputText"]` → user message (string `v`)
- **Line kind=2**: Array splice/insert — response parts pushed to `["requests", N, "response"]`:
  - Items with `"kind": "thinking"` contain reasoning text
  - Items with `"kind": "textEditGroup"` are file edits
  - Items without a `kind` but with a string `value` are markdown response text

**JSON format** (older sessions): Parse as a single `json.load()`. Often have empty requests.

### Step 3: Scan VS Code state.vscdb for CLI sessions run through VS Code

Check `%APPDATA%/Code/User/workspaceStorage/*/state.vscdb` — SQLite database with `ItemTable`.

Query `chat.ChatSessionStore.index` for `{"entries": {sessionId: {title, ...}}}`.
This reveals Copilot CLI sessions that ran inside VS Code's integrated terminal.

When `copilotcli.session.metadata.json` (in `%APPDATA%/Code/User/globalStorage/github.copilot-chat/copilotCli/`)
shows `"writtenToDisc": true` and a `workspaceFolder` path, the session content is on the **remote machine**.

### Step 4: Check remote SSH hosts for session data

For each SSH host in `~/.ssh/config`, check for session data:

```bash
ssh <host> 'for d in ~/.copilot/session-state/*/; do
  if [ -f "$d/workspace.yaml" ]; then
    cat "$d/workspace.yaml"
    if [ -f "$d/plan.md" ]; then echo "--- PLAN ---"; cat "$d/plan.md"; fi
    echo "================================================================"
  fi
done'
```

Key files per session:
- `workspace.yaml` — session metadata (cwd, repo, branch, summary)
- `plan.md` — implementation plan (often contains the richest technical learnings)
- `events.jsonl` — full conversation event stream

Known SSH hosts with Copilot sessions: Qualcomm-Cloud-AI, PVE-Z8, Jellyfin, ComfyUI, Vod2Pod, Home-Assistant, Shmuelis-MBP.

### Step 5: Compare against existing skills

Review the `skills/` directory to identify:
- New patterns not yet covered by any skill
- Updates or corrections to existing skill content
- Entirely new topic areas that warrant a new skill

### Step 6: Update or create SKILL.md files

Each SKILL.md has:
```markdown
---
name: skill-name
description: Brief description
---

Context instructions.

# Domain Knowledge
...
```

### Step 7: Bump the version

The root `plugin.json` is the aggregate direct-install plugin. Its version must
match the `shmuelie-skills` entry in `.github/plugin/marketplace.json`.

Each focused `.github/plugin/shmuelie-*/plugin.json` is versioned independently
and must match its own marketplace entry:
- PATCH for minor content updates to existing skills
- MINOR for new skills or significant content additions

Only bump `marketplace.json`'s `metadata.version` when the catalog composition
changes, such as adding or removing a focused plugin.

### Step 8: Update CHANGELOG.md

Following Keep a Changelog format:
- Add entries under `[Unreleased]` or a new version section
- Move `[Unreleased]` entries to the new version on release
- Update comparison links at the bottom

### Step 9: Update README.md if needed

Update if:
- A new skill was added (update the Skills table and Project Structure)
- Source repos changed

### Step 10: Commit and push

With a descriptive message.

## Conventions

- Skills are markdown files at `skills/<name>/SKILL.md`
- Each plugin manifest version must match its marketplace entry; focused plugin versions are independent
- Follow Semantic Versioning for all version bumps
- Follow Keep a Changelog for CHANGELOG.md
- Skill descriptions should be specific and actionable, not vague
- Include code examples, gotchas, and bug patterns — not just general advice
