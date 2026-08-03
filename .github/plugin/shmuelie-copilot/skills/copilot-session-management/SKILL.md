---
name: copilot-session-management
description: "Copilot CLI session diagnostics, repair, merge, compaction, plugin/marketplace/MCP management, deny-tool rules"
version: 1.6.0
---

# Copilot CLI Session Management

## Session Structure

Sessions live under `~/.copilot/session-state/<session-id>/`:

- `workspace.yaml` — metadata (id, cwd, git_root, repository, host_type, branch, name, summary, updated_at, created_at, summary_count, mc_task_id, mc_session_id)
- `events.jsonl` — conversation history, one JSON event per line
- `checkpoints/index.md` — checkpoint table linking to snapshot files
- `rewind-snapshots/index.json` — rewind history with backup diffs
- `plan.md` — session plan/notes
- `files/`, `research/` — session artifacts
- `session.db` — SQLite database managed by the CLI runtime (do NOT copy/merge — let the CLI recreate it)

### workspace.yaml: `name` vs `summary`

The CLI transitioned from `summary` to `name` for the session display field. Sessions may have:
- Only `summary` (older sessions)
- Only `name` (newer sessions)
- Both `name` and `summary`
- Neither (very old or empty sessions)

The `name` field can use YAML block scalars (`|-`, `>-`):
```yaml
name: |-
  Create a plan to:
  1. Audit logging
  2. Add DCAT logging
```

`Get-CopilotSession` parses both fields and exposes `Name` and `Summary` (both populated from `name ?? summary`). When replacing the field (merge, rename), handle block scalar removal by skipping subsequent indented lines.

## events.jsonl Event Types

### Conversation Events
- `user.message` — user input
- `assistant.message` — model response, may contain `data.toolRequests[].toolCallId`
- `assistant.turn_start` — marks the beginning of an assistant turn
- `assistant.turn_end` — marks the end of an assistant turn
- `system.message` — system prompt or context injection
- `system.notification` — runtime notification (e.g., background task completion)

### Tool Events
- `tool.execution_start` — tool began executing, has `data.toolCallId`
- `tool.execution_complete` — tool finished, has `data.toolCallId` with result
- `tool.user_requested` — user explicitly requested a tool execution

### Subagent Events
- `subagent.started` — background/explore agent launched, has `data.toolCallId` and `data.agentName`
- `subagent.completed` — agent finished, has `data.toolCallId`, `data.model`, `data.totalToolCalls`, `data.durationMs`

### Hook Events
- `hook.start` / `hook.end` — lifecycle hooks (e.g., pre/post tool execution)

### Session Lifecycle Events
- `session.start` — first event, contains `data.sessionId`
- `session.resume` — session was resumed from a previous run
- `session.shutdown` — session ended normally
- `session.error` — runtime error occurred
- `session.warning` — runtime warning
- `session.mode_changed` — agent mode changed (e.g., plan ↔ act)
- `session.model_change` — model was switched
- `session.plan_changed` — plan.md was updated
- `session.workspace_file_changed` — a session file was modified
- `session.context_changed` — context window contents changed
- `session.compaction_start` / `session.compaction_complete` — automatic context compaction
- `session.truncation` — context was truncated
- `abort` — user cancelled the current turn

### Critical: tool_use/tool_result Pairing

Every `tool_use` block in an `assistant.message` MUST have a corresponding `tool_result` in the next messages. Violations cause API errors:

```
CAPIError: 400 messages.2.content.3: unexpected `tool_use_id` found in `tool_result` blocks
```

## Common Corruption Patterns

### Orphaned Tool Events (Race Condition)

`tool.execution_complete`/`execution_start` events appear BEFORE their `assistant.message` due to logger race conditions. Fix: relocate them after their corresponding request.

### Missing Tool Completions

`tool_use` blocks with no matching `tool_result` anywhere in the file. Fix: synthesize a dummy completion event.

### Oversized Sessions

Sessions that accumulate many tasks without checkpointing grow too large (10+ MB events.jsonl). The API truncates mid-conversation, splitting tool pairs. Fix: compact by keeping only the last N conversations.

### Malformed Synthetic Events

Previous repair attempts may inject events with `"model": "unknown"` or empty `id` fields. These crash the loader. Fix: remove events with empty/invalid id fields.

## Repair Cmdlet (`Repair-CopilotSessionEvents`)

Accepts `-EventLines` (array), `-Path` (directory), `-Id`, or pipeline input from `Get-CopilotSession`. Creates `.bak` backup unless `-NoBackup` specified.

Repair steps:
1. Relocate orphaned tool events after their `assistant.message`
2. Synthesize missing `tool_result` for unpaired `tool_use` blocks
3. Remove `session.error` events
4. Validate final tool_use/tool_result pairing

## Merge Cmdlet (`Merge-CopilotSession`)

- **CRITICAL**: Concatenate sessions chronologically, do NOT globally sort events by timestamp. Global sorting breaks intra-session tool_use/tool_result pairs that share timestamps.
- Repair each source session's events before concatenating.
- Run repair on the final merged session to fix cross-session issues.
- Keep only the first `session.start` event, rewrite its `sessionId`.
- Strip lifecycle events from source sessions: `session.shutdown`, `session.resume`, `session.error`, `session.warning`, `session.compaction_start`, `session.compaction_complete`, `session.truncation`, `session.context_changed`, `abort`.
- Replace `name:` field in workspace.yaml (handles YAML block scalars with indented continuation lines). Also update `summary:` if present.
- Case-insensitive CWD comparison for non-case-sensitive file systems.
- Filter `(no summary)` from merged session names.
- Do NOT copy `session.db` — it contains session-specific data and the CLI recreates it.

## Session Compaction

For oversized sessions (>5 MB events.jsonl):
1. Back up the original events.jsonl
2. Keep only the `session.start` event and the last N user/assistant exchanges
3. Verify 0 orphaned tool events in the trimmed result
4. Clean up rewind-snapshots that reference deleted events
5. **CRITICAL**: Do NOT re-serialize JSON events — preserve raw lines byte-for-byte to avoid encoding changes that break the loader

## Diagnostic Checklist

When a session won't resume:
1. Check events.jsonl size — if >5 MB, likely needs compaction
2. Check for 0 checkpoints with many user messages — needs compaction
3. Search for orphaned tool events (execution_complete before assistant.message)
4. Search for events with `"model": "unknown"` or empty `"id": ""`
5. Verify all tool_use blocks have matching tool_result
6. Check rewind-snapshots/index.json for references to nonexistent events

## Plugin Management Cmdlets

- `Get-CopilotPlugin` — parses `copilot plugin list` output into typed `CopilotPlugin` objects (Name, FullName, Marketplace, Version). Supports `-Name` with wildcards.
- `Install-CopilotPlugin` — installs from owner/repo, plugin@marketplace, or URL. Idempotent — skips if already installed.
- `Uninstall-CopilotPlugin` — removes by name or pipeline from `Get-CopilotPlugin`.
- `Update-CopilotPlugin` — updates per plugin. Accepts pipeline from `Get-CopilotPlugin`. Returns `CopilotPluginUpdateResult` objects.
- All use `Resolve-CliExe` from shared `CliExeHelpers.ps1` to resolve the real exe (bypassing the `copilot` alias).
- Integrated into `Update-Apps` as the `'Copilot Plugins'` step with per-plugin `Write-Progress` (nested `-Id 0` under outer `-Id 1`).

### Agency Plugin Cmdlets

- `Get-AgencyPlugin` / `Install-AgencyPlugin` / `Uninstall-AgencyPlugin` — use the **native** `agency plugin list`/`install`/`uninstall`. `Get-AgencyPlugin` parses the native list (richer `AgencyPlugin` objects: Name, Source, Marketplace, Engines, Scope — no Version). There is **no `Update-AgencyPlugin`**: Agency has no `plugin update` command (only `agency copilot plugin update`, which is the Copilot path, not a real Agency command).
- Share the same `CliExeHelpers.ps1` parsing logic — Agency output format is identical to Copilot CLI.
- Integrated into `Update-Apps` as the `'Agency Plugins'` step with per-plugin `Write-Progress`.
- **Marketplace plugins** are installed via Agency (`agency plugin install market:name@location --engine copilot --fetch-mode background`) for background caching. Direct-install plugins (ADO URLs, GitHub) remain in Copilot CLI. `Update-Apps` has a `'Copilot Plugins'` step that updates only non-Agency plugins.
- **Background auto-refresh needs `--cache-policy auto --cache-ttl <seconds>`.** `--fetch-mode background` alone does NOT update plugins: the default cache policy is `no-refresh` ("use cached copy regardless of age"), so the background fetch never triggers. Only `cache_policy = auto` (with a TTL, e.g. `86400` for daily) makes a session serve the cache instantly and refresh stale plugins in the background. There is no `agency plugin update` and no single global default — per-plugin policy lives in `~\AppData\Local\agency\agency.toml` under the `[[plugins.default]]` array.
- **`copilot plugin update` on marketplace plugins can fail with `EBUSY: resource busy or locked, rmdir`.** Marketplace plugins are updated by deleting and re-fetching the plugin directory; if **another running Copilot process** (a second session, or a stale one) has handles open on that directory, the `rmdir` fails. Direct-install plugins live under `installed-plugins\_direct\` and don't hit this. Fix: close other Copilot sessions (check for stale ones with `Get-CopilotSession`) before updating, or let Agency's background cache refresh handle it instead of an interactive update. Don't pipe the update through `2>&1 | Out-Null` — that swallows the EBUSY error and makes the failure silent (`Update-CopilotPlugin` was fixed to surface it).
- **Migrating plugins (e.g. splitting one plugin into several) is uninstall-then-install — there is no in-place path.** Agency has no `plugin update`, and the DSC **`AgencyPlugin` resource is install-only** (`Set()` only runs `agency plugin install`; no `Ensure=Absent`), so re-running the DSC **adds** the new plugins but can never **remove** the old one — the uninstall must be explicit (`Uninstall-AgencyPlugin -Name <old>`). Uninstall the old one *first* to avoid a window where the same skills exist in two installed plugins.
- **After a marketplace split, the cached catalog is stale.** Installs default to `--cache-ttl 86400`, so a plugin that only exists *after* the split may fail to resolve ("plugin not found") because Agency is reading a pre-split cached catalog flagged `stale`/`expired`. Clear it first, then install with a fresh fetch: `Get-AgencyPluginCache | Where-Object Marketplace -match <repo> | Remove-AgencyPluginCache -Force`, or install with `-NoConfigCache`. **`Remove-AgencyPluginCache` takes `-Spec` / `-InputObject`, NOT `-Name`** — pass the cache object down the pipeline (or the full `market:<name>@<url>` spec); `-Name` throws *"A parameter cannot be found that matches parameter name 'Name'."*
- **Re-sync profiles after any add/remove** with `Update-AgencyProfile`. `agency plugin install/uninstall` maintains only the base `[[plugins.default]]`; the global `agency.toml` `[profiles.*]` blocks are synced from the tracked `Configuration/agency-profiles.toml`, so until you re-sync they keep referencing a plugin you just removed (or omit one you just added).

## Marketplace Management Cmdlets

- `Get-CopilotMarketplace` — lists registered marketplaces (Name, Repository). Parses both `GitHub:` and `URL:` source formats.
- `Register-CopilotMarketplace` — registers from owner/repo or URL. Idempotent — skips if already registered.
- `Unregister-CopilotMarketplace` — removes by name or pipeline.
- `Get-CopilotMarketplacePlugin` — browses available plugins in a marketplace. Returns Name, Description, Marketplace.

### Agency Marketplace Cmdlets

- `Register-AgencyMarketplace` — wraps the **native** `agency marketplace add` (`-Marketplace`/alias `-Source`: presets curated/playground/all or a custom owner-repo/URL, repeatable; `-Engine`; `-FixGitAuth`; `-NoConfigCache`). Agency's native `marketplace` command has **only `add`** — there is no native `marketplace list`/`remove`/`browse`, so there are **no** `Get-AgencyMarketplace`, `Unregister-AgencyMarketplace`, or `Get-AgencyMarketplacePlugin` cmdlets. Use the Copilot marketplace cmdlets (`Get-CopilotMarketplace`, `Unregister-CopilotMarketplace`, `Get-CopilotMarketplacePlugin`) to list/remove/browse.

### Agency Plugin Profiles (different plugins for different work)

Agency natively supports plugin **profiles** — `[[profiles.<name>.plugins.default]]` tables in the agency config, activated with `agency copilot --profile <name>` (deep-merge over base) or `--profile-only <name>` (the profile is the ONLY plugin set; also narrows MCP to non-ambient + the profile's plugins). There is **no** native install-to-profile (`agency plugin install` only writes base `plugins.default`), so membership is managed via a tracked file.

- **Source of truth:** keep a tracked `agency-profiles.toml` defining profiles such as `core`, `development`, and `data`. `full` can remain virtual (= base `plugins.default`, every installed plugin; maps to no `--profile-only`).
- **Cmdlets:** `Get-AgencyProfile` (list profiles + plugins), `Update-AgencyProfile` (idempotently merge the tracked `[profiles.*]` into the global `~/AppData/Local/agency/agency.toml` between sentinel comments — never touches `[[plugins.default]]`; validates via `agency config check`), `Add-AgencyProfilePlugin` / `Remove-AgencyProfilePlugin` (edit a profile's list + re-sync), and `Install-AgencyPlugin -Profile <name[]>` (install + add to profile(s)).
- **Selection:** `Start-Copilot -Agency -AgencyProfile <name>` maps to `--profile-only <name>` by default; `-MergeProfile` maps to `--profile`. A wrapper can select a default profile through configuration or an environment variable.
- **Apply on a new machine:** the DSC "Agency Plugin Profiles" resource runs the merge; or run `Update-AgencyProfile` manually.
- **Gotcha:** `--profile-only` narrows MCP too — if a lean profile drops an MCP you need, use `-MergeProfile` or add the MCP to the profile.

## MCP Server Management Cmdlets

- `Get-CopilotMcpServer` — parses `copilot mcp list --json` into typed objects (Name, Type, Command, Args, Url, Source). Supports `-Name` wildcards and `-Source` filter (user/workspace/plugin/builtin).
- `Register-CopilotMcpServer` — wraps `copilot mcp add` with typed params (`-Transport`, `-Command`, `-ArgumentList`, `-Url`, `-Env`, `-Header`).
- `Unregister-CopilotMcpServer` — wraps `copilot mcp remove` with pipeline support.

### autoConnect Path Globs
The `autoConnect` property in `mcp-config.json` supports three forms:
- `false` — server is always disabled at startup
- `true` or absent — server is always enabled
- `["D:\\path\\*", ...]` — server is enabled only when the CWD matches a glob pattern

`Start-Copilot` reads this at launch and passes `--disable-mcp-server` for non-matching servers. `-EnableMcpServer` overrides any autoConnect policy.

## Start-Copilot Parameters

Key parameters beyond the standard CLI flags:
- `-NoResume` — skip session resume picker and start a new session
- `-NoAllowAll` — don't pass `--allow-all` (default behavior passes it)
- `-ResumeLatest` — resume the most recent session without prompting
- `-Agency` / `-DetectAgency` — Agency integration (routes through `agency copilot` instead of `copilot`)
- `-SessionId` — resume or create a session with a specific UUID
- `-NoColor` — disable color output
- `-Banner` — show the animated startup banner

**Auto-resume selection** (when neither `-NoResume` nor `-ResumeLatest` is set): candidate sessions are matched by `cwd` (preferring the current git branch) with auto-generated maintenance sessions skipped (the context_board, session-insights, and session-summary — `Session File Path:` — workers). One candidate → resume it; multiple → interactive picker — **except** when exactly one candidate is *named* (the rest being unnamed `(no summary)` stubs), in which case that lone named session is auto-resumed.
- `-NoAutoUpdate` — skip auto-update check
- `-DisallowTempDir` — prevent automatic temp directory access
- `-ReasoningEffort` — `none`, `low`, `medium`, `high`, `xhigh`, `max`
- `-ChangeDir` — set working directory before starting

### Agency-Only Parameters

These require `-Agency` (enforced via parameter sets):
- `-AgencyAgent` — load a named agent (`plugin:agent` syntax, e.g., `my-plugin:my-agent`)
- `-AgencyProfile` — activate a named configuration profile from agency config
- `-AgencyMcp` — add built-in Agency MCPs (`ado`, `bluebird`, `icm`, `watson`, `enghub`, etc.)
- `-NoDefaultMcps` — skip loading default Agency MCPs (bluebird, workiq)
- `-NoInstalledPlugins` — skip auto-loading installed plugins
- `-AgencyPlugin` — load specific plugin specs (`local:./path`, `github:owner/repo`, `cat:catalog`)
- `-AgencySource` — agent resolution source: `personal`, `repo`, `organization`, `company`, `playground`, `spec`
- `-AgencyInput` — input variable assignments in `VAR=VALUE` format
- `-AgencyVerbosity` — Agency log verbosity: `off`, `error`, `warn` (default), `info`, `debug`, `trace`
- `-NoAgencyConfigCache` — bypass on-disk remote config cache

### Agency Plugin Install Syntax

Install plugins via Agency CLI directly (outside a session):
```powershell
agency plugin install market:my-plugin@https://github.com/myorg/plugins --engine copilot
```

Or via PowerShell cmdlets (recommended — typed, full native flags):
```powershell
Install-AgencyPlugin -Name my-plugin -Marketplace https://github.com/myorg/plugins -Engine copilot
```

## Custom Status Line

The CLI supports a custom status line at the bottom of the terminal. Configuration in `~/.copilot/settings.json`:
```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.copilot/statusline.cmd",
    "padding": 1
  },
  "feature_flags": { "enabled": ["STATUS_LINE"] }
}
```
- The `command` script receives session status JSON on stdin (contains `cwd`, `context_window`, `cost`, `ai_used`)
- A `.cmd` wrapper is required on Windows — inline `pwsh -File ...` is unreliable
- Enable with `/statusline` → pick **Custom** → `/restart`
- The `feature_flags.enabled: ["STATUS_LINE"]` may be required alongside `experimental: true`
- **Layout**: Left-right alignment — git info left, context/cost/AI Credits right, space-padded to terminal width (minus 4-char margin). Falls back to linear layout if terminal is too narrow.
- **Width detection**: `(Get-Host).UI.RawUI.WindowSize.Width` works with redirected stdin; `[Console]::WindowWidth` fails ("handle is invalid").

### Stdin JSON Payload

The CLI pipes this JSON to the command on each refresh:

```json
{
  "cwd": "D:\\path\\to\\repo",
  "session_id": "uuid",
  "session_name": "session summary text",
  "transcript_path": "C:\\Users\\...\\session-state\\uuid",
  "model": { "id": "claude-opus-4.6-1m", "display_name": "Claude Opus 4.6 ..." },
  "workspace": { "current_dir": "D:\\path" },
  "username": null,
  "remote": { "connected": false },
  "version": "1.0.55-1",
  "cost": {
    "total_api_duration_ms": 3423165,
    "total_lines_added": 3127,
    "total_lines_removed": 789,
    "total_duration_ms": 733477340,
    "total_premium_requests": 132
  },
  "context_window": {
    "current_context_tokens": 51669,
    "displayed_context_limit": 200000,
    "current_context_used_percentage": 26,
    "context_window_size": 1000000,
    "used_percentage": 5,
    "remaining_tokens": 947532,
    "last_call_input_tokens": 52368,
    "last_call_output_tokens": 100,
    "total_input_tokens": 41236365,
    "total_output_tokens": 187093,
    "total_cache_read_tokens": 39195989,
    "total_cache_write_tokens": 1640566,
    "total_reasoning_tokens": 7327,
    "total_tokens": 41423458
  },
  "ai_used": { "total_nano_aiu": 3688502975000, "formatted": "3689" }
}
```

**Fields used by `copilot-statusline.ps1`**: `cwd` (git status), `context_window.current_context_tokens`/`displayed_context_limit`/`current_context_used_percentage` (ctx bar), `cost.total_premium_requests`/`total_lines_added`/`total_lines_removed` (cost segment), `ai_used.formatted` (AI Credits).

**Available but unused**: `session_name`, `model.display_name`, `version`, `remote.connected`, `cost.total_api_duration_ms`/`total_duration_ms`, `context_window.remaining_tokens`.

## Denied Git Operations

`Start-Copilot` blocks destructive git operations via `--deny-tool` rules (takes precedence over `--allow-all`):
- `git push --force` / `-f` / `--force-with-lease`
- `git checkout --force` / `-f`
- `git clean --force` / `-f`
- `git reset --hard`
- `git commit --amend` / `-a --amend`
- `git rebase` / `-i` / `--interactive`
- `git pull` — prevents merge commits in worktree-based workflows; use `Sync-GitRemote` (fetch + fast-forward) instead
