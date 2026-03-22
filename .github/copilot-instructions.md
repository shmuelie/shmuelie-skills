# Copilot Instructions for shmuelie-skills

## Project Overview

This is a Copilot CLI plugin that packages domain knowledge as reusable skills in `skills/*/SKILL.md` files. The plugin is installed via `copilot plugin install shmuelie/shmuelie-skills`.

## Scanning for New Learnings

When asked to scan for new learnings or update skills, follow this process:

1. **Query the session store** for sessions created after the last known sweep date. Use the `sql` tool with `database: "session_store"` to search:
   - `search_index` for technical patterns, conventions, and bug fixes
   - `checkpoints` for detailed technical knowledge
   - `sessions` and `turns` for conversation content
   - Also check WSL session stores at `$HOME/.copilot/session-store.db` — copy to a temp file via `wsl` then query with Python/sqlite3
   - Also check VS Code Copilot Chat sessions (see below)

### VS Code Chat Session Extraction

VS Code stores Copilot Chat history in multiple locations and formats:

#### Format 1: JSONL files (`chatSessions/*.jsonl`)
Located at `%APPDATA%/Code/User/workspaceStorage/*/chatSessions/*.jsonl`.

Each `.jsonl` file uses an incremental format:
- **Line kind=0**: Initial session state (contains `v.requests`, `v.customTitle`)
- **Line kind=1**: Incremental updates keyed by JSON array paths (`k` field):
  - `["customTitle"]` → session title (string `v`)
  - `["inputState", "inputText"]` → user message (string `v`)
- **Line kind=2**: Array splice/insert — response parts pushed to `["requests", N, "response"]`:
  - Items with `"kind": "thinking"` contain reasoning text
  - Items with `"kind": "textEditGroup"` are file edits
  - Items without a `kind` but with a string `value` are markdown response text

#### Format 2: JSON files (`chatSessions/*.json`)
Same directory but plain JSON (not JSONL). These are older-format sessions:
```json
{ "version": ..., "requests": [...], "sessionId": "..." }
```
Often have `"requests": []` (empty/abandoned). Parse as a single `json.load()`.

#### Format 3: VS Code state.vscdb (Copilot CLI sessions via VS Code)
Located at `%APPDATA%/Code/User/workspaceStorage/*/state.vscdb` — SQLite database with `ItemTable`.

Key entries:
- `chat.ChatSessionStore.index` → `{"entries": {sessionId: {title, lastMessageDate, ...}}}` — session index with titles
- `GitHub.copilot-chat` → contains `github.copilot.cli.requestMap` (tool invocation metadata) and
  `github.copilot.cli.workspaceSessionFile` (pointer to session data)
- `agentSessions.model.cache` → list of session metadata with titles and timestamps

**Important**: When `copilotcli.session.metadata.json` shows `"writtenToDisc": true` and a `workspaceFolder` path,
the actual session content is stored on the **remote machine** at `~/.copilot/session-state/<session-id>/`.
Read `events.jsonl`, `workspace.yaml`, and `plan.md` from the remote host via SSH.

#### Format 4: Remote host session state
For SSH-remote VS Code sessions, data lives on the remote machine:
```
~/.copilot/session-state/<session-id>/
├── events.jsonl           # Full conversation event stream
├── workspace.yaml         # Session metadata (cwd, repo, branch, summary)
├── plan.md                # Implementation plan (if any)
└── vscode.metadata.json   # VS Code integration metadata
```
Access via SSH: `ssh <host> "cat ~/.copilot/session-state/<id>/workspace.yaml"`
The `workspace.yaml` file contains the session summary and working directory.
The `plan.md` file often contains the richest technical learnings.

#### Discovery strategy
1. List all `workspaceStorage/*/chatSessions/` directories
2. For each, check both `.jsonl` and `.json` files (skip <200 bytes)
3. Check `state.vscdb` for CLI sessions run through VS Code
4. Cross-reference `copilotcli.session.metadata.json` for remote sessions
5. SSH to remote hosts to read `workspace.yaml` and `plan.md` from session directories

To find new sessions, check file modification times against the last sweep date. Parse with Python:

```python
import json, os
from datetime import datetime

ws_storage = os.path.expandvars(r"%APPDATA%\Code\User\workspaceStorage")
cutoff_ts = datetime(2026, 3, 22).timestamp()  # last sweep date

for ws_dir in os.listdir(ws_storage):
    chat_dir = os.path.join(ws_storage, ws_dir, "chatSessions")
    if not os.path.isdir(chat_dir):
        continue
    for fname in os.listdir(chat_dir):
        fp = os.path.join(chat_dir, fname)
        if os.path.getmtime(fp) <= cutoff_ts or os.path.getsize(fp) < 200:
            continue
        # Read workspace folder from workspace.json
        ws_json = os.path.join(ws_storage, ws_dir, "workspace.json")
        # Parse JSONL: extract titles, user messages, thinking, response text
        with open(fp, "r", encoding="utf-8", errors="replace") as fh:
            for line in fh:
                obj = json.loads(line.strip())
                k = obj.get("k", "")
                v = obj.get("v")
                # k=["customTitle"] → title
                # k=["inputState","inputText"] → user question
                # kind=2 with v=list → response parts
```

2. **Compare against existing skills** in the `skills/` directory to identify:
   - New patterns not yet covered by any skill
   - Updates or corrections to existing skill content
   - Entirely new topic areas that warrant a new skill

3. **Update or create SKILL.md files** with the new knowledge. Each SKILL.md has:
   ```markdown
   ---
   name: skill-name
   description: Brief description
   ---

   Context instructions.

   # Domain Knowledge
   ...
   ```

4. **Bump the version** in both `plugin.json` and `.github/plugin/marketplace.json` following SemVer:
   - PATCH for minor content updates to existing skills
   - MINOR for new skills or significant content additions

5. **Update CHANGELOG.md** following Keep a Changelog format:
   - Add entries under `[Unreleased]` or a new version section
   - Move `[Unreleased]` entries to the new version on release
   - Update comparison links at the bottom

6. **Update README.md** if:
   - A new skill was added (update the Skills table and Project Structure)
   - Source repos changed

7. **Commit and push** with a descriptive message.

## Conventions

- Skills are markdown files at `skills/<name>/SKILL.md`
- Version is tracked in `plugin.json` and `.github/plugin/marketplace.json` — both must stay in sync
- Follow Semantic Versioning for all version bumps
- Follow Keep a Changelog for CHANGELOG.md
- Skill descriptions should be specific and actionable, not vague
- Include code examples, gotchas, and bug patterns — not just general advice
