# shmuelie-notifications

Windows toast notification hooks packaged for Copilot CLI. The renderer also
understands Claude / VS Code hook payloads for manual or workspace-hook use.
Toasts appear **only when the agent needs your attention**.

This plugin ships **no skills** — it's lifecycle hooks only.

**Version:** 0.1.0 · Part of the [`shmuelie-skills`](../../../../README.md) marketplace.

## Install — must be Agency

```
agency plugin install "market:shmuelie-notifications@https://github.com/shmuelie/shmuelie-skills" --engine copilot --cache-policy auto --cache-ttl 86400
```

**Hooks only load via an Agency-managed install** (Agency passes the cached plugin with
`copilot --plugin-dir`, and the CLI loads its `copilot-hooks.json`). The Copilot CLI plugin
loader **drops** any `hooks` field in `plugin.json`, and a *direct* (`_direct/`) install is not
Agency-managed — so a direct install does **not** get the hooks. In-repo, a workspace
`<gitRoot>/.github/hooks/` also loads them.

## Files

| File | Role |
|------|------|
| `copilot-hooks.json` | **Copilot CLI** hook config (camelCase events); at the plugin root so Agency injects it via `--plugin-dir`. |
| `hooks/hooks.json` | Optional Claude Code / VS Code workspace-hook config; not advertised as an Agency engine. |
| `hooks/Invoke-CopilotToast.ps1` | Thin launcher: reads the hook payload from stdin, fire-and-forget launches the renderer. |
| `hooks/Show-CopilotToast.cs` | .NET 10 single-file app that renders the toast via raw WinRT. |
| `hooks/hook-payload.schema.json` | JSON Schema for the stdin hook payload (per-event contract). |

## Events → states

Both configs hook **every** available event; the renderer normalizes each to an internal state
and only `error` / `permission` / `done` raise a toast:

| Engine | Event(s) | State | Toast |
|--------|----------|-------|-------|
| Copilot CLI | `errorOccurred` | `error` | "Copilot hit an error" |
| Copilot CLI | `sessionStart`, `userPromptSubmitted`, `preToolUse`, `postToolUse` | `working` | *(silent)* |
| Copilot CLI | `sessionEnd` | `exit` | *(silent)* |
| Claude / VS Code | `Notification` | `permission` | "Copilot needs your input" |
| Claude / VS Code | `Stop` | `done` | "Copilot finished — your turn" (suppressed for maintenance workers) |
| Claude / VS Code | `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse` | `working` | *(silent)* |
| Claude / VS Code | `SessionEnd` | `exit` | *(silent)* |

Copilot CLI has **no** permission/your-turn event, so an error is the only attention signal
there. `${PLUGIN_ROOT}` (Copilot) / `${CLAUDE_PLUGIN_ROOT}` (Claude) expose the installed plugin
dir. Set `COPILOT_TOAST_DEBUG=1` to log raw stdin + decisions to
`%TEMP%\copilot-toast-debug\toast.log`.

## Dependencies

- **.NET 10 SDK** — the single-file `Show-CopilotToast.cs` renderer (raw WinRT toast).
- **PowerShell** — the `Invoke-CopilotToast.ps1` launcher.
