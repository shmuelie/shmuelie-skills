---
name: plugin-authoring
description: "Author a repository as a Copilot CLI / Agency plugin and marketplace — plugin.json and marketplace.json manifests, the .github/skills auto-discovery symlink, SKILL.md and prompt-template conventions, version-sync rules, and install/distribution. Use when asked to set up a repo as a plugin source, create a skills marketplace, package skills for sharing, or configure a repo for Agency/Copilot plugin install."
---

When setting up a repository so its skills and prompts can be installed as a Copilot CLI / Agency plugin, apply this domain knowledge. This repo is now a **multi-plugin marketplace** (8 grouped plugins under `.github/plugin/<name>/`) — see "Multi-plugin marketplace" below; the single-plugin layout shown first is the simplest starting point (paths shown are from the author's setup; yours will differ).

# Authoring a Copilot CLI / Agency Plugin Marketplace

## Repository Layout

```
<repo>/
├── .github/
│   ├── plugin/
│   │   ├── plugin.json          # plugin manifest (NOTE: no functional `hooks` field)
│   │   ├── README.md            # per-plugin README (ships in the source dir; skills/prompts/deps)
│   │   ├── marketplace.json     # marketplace catalog metadata
│   │   ├── agency.json          # optional: cross-engine hint {engines, platforms}
│   │   ├── copilot-hooks.json   # Copilot/Agency hooks (camelCase events)
│   │   └── hooks/               # hook scripts + Claude hooks file
│   │       ├── hooks.json           # Claude/VS Code hooks (PascalCase events)
│   │       └── <renderer/launcher scripts>
│   └── skills -> ../skills      # symlink: auto-discovery when working IN this repo
├── skills/
│   ├── <skill-name>/SKILL.md
│   └── <skill-name>/<prompt>.prompt.md
├── CHANGELOG.md
└── README.md
```

## plugin.json

The plugin manifest. `skills` points at the directory containing skill folders (relative to repo root):

```json
{
  "name": "my-skills",
  "description": "What this plugin provides",
  "version": "1.0.0",
  "author": { "name": "Your Name", "url": "https://dev.azure.com/org/project/_git/Repo" },
  "license": "MIT",
  "keywords": ["domain", "keywords", "for", "discovery"],
  "skills": ["skills/"]
}
```

Optional `"readme": "./README.md"` points at a per-plugin README (see below). Unknown manifest
keys are **silently ignored** by the Copilot CLI plugin loader (the same way it drops a
functional `hooks` field), so a `readme` pointer is safe even where the schema doesn't formally
define it — verified by loading the dir with `copilot --plugin-dir <dir>` (exit 0, no warning).

## Per-plugin README convention

Each plugin directory ships its own **`README.md`** (it lives inside the plugin's `source` dir,
so Agency copies it on install). Keep the depth there — skill table (from each `SKILL.md`
frontmatter), prompt-template list, install command, dependencies, and the in-repo
`.github/skills` discovery note. In a **multi-plugin marketplace**, the marketplace
`README.md` (at `.github/plugin/README.md`) is a **catalog**: an intro, a one-row-per-plugin
table linking to each plugin's README, and the cross-cutting mechanics (install, engine-aware
manifests, structure) — it does **not** duplicate the per-plugin skill tables. Single source of
truth: a skill's description lives in its `SKILL.md` and its plugin README, not also in the
catalog.

## marketplace.json

Catalog metadata so the repo can be registered as a marketplace. **`source` points at the plugin manifest directory** (`.github/plugin`):

```json
{
  "name": "my-skills",
  "owner": { "name": "Your Name" },
  "metadata": {
    "description": "Short catalog description",
    "version": "1.0.0"
  },
  "plugins": [
    {
      "name": "my-skills",
      "description": "Plugin description",
      "version": "1.0.0",
      "source": ".github/plugin"
    }
  ]
}
```

### Multi-plugin marketplace

One marketplace can publish **several plugins** — list each in `plugins[]` with its own
`source` dir, `name`, and `version`. Group related skills into focused plugins so users
install only what they need. For example, a marketplace can contain
`.github/plugin/shmuelie-copilot/`, `shmuelie-devenv/`, and a hooks-only
`shmuelie-notifications/`.

Rules that change vs. a single plugin:
- **Each plugin dir must be self-contained** — Agency copies only the one `source` dir, so
  a plugin's skills/hooks/scripts must live inside it. Keep the marketplace manifests OUT
  of the individual plugin dirs (they stay at the hardcoded engine paths).
- **Per-plugin versions**: bump the changed plugin's `plugin.json` `version` and its
  `plugins[].version` entry; bump the catalog `metadata.version` only when the plugin *set* changes.
- **In-repo auto-discovery** can't use one `.github/skills` symlink (skills are spread
  across N dirs) — make `.github/skills/` a real directory with one symlink per skill
  pointing into its plugin (`<skill>` → `../plugin/<group>/skills/<skill>`).
- **A hooks-only plugin** (no skills) sets `"skills": []` and carries `copilot-hooks.json`
  + `hooks/` at its root; installing it via Agency is what loads the hooks globally.

### Remote ("forwarded") plugin sources

The `source` field also accepts a **remote** object instead of a local path, letting one marketplace re-list ("forward") a plugin that actually lives in another repo:

```json
{ "name": "external-plugin", "source": { "source": "github", "repo": "some-org/external-skills-repo" }, "version": "1.0.0", ... }
```

There is **no single "import another marketplace" directive** — you forward plugins one entry at a time. Gotchas:
- The marketplace **format** accepts remote sources, but a repo's **CI validator may reject them** — this repo's validator only allows local-path sources (it resolves `source` against `pluginRoot` on disk). Check/loosen the validator before adding a forwarded entry.
- A forwarded entry's `version` is independent of the upstream plugin's real version; it can go stale. Local-path entries are the convention here precisely to avoid that drift.

## Agency Marketplace (engine-aware: `.github/plugin/marketplace.json` + `.claude-plugin/marketplace.json`)

**Agency installs are engine-aware: it downloads a *different* marketplace manifest per engine.** Confirmed from a debug install (`agency --verbosity debug plugin install … --engine copilot`): for `--engine copilot` Agency fetches **`.github/plugin/marketplace.json`** (the Copilot CLI marketplace format), and for `--engine claude` it fetches **`.claude-plugin/marketplace.json`**. If the manifest for the requested engine is missing, install fails with `Manifest unavailable for engine="Copilot" … 404 … .github/plugin/marketplace.json` / "not available in the Copilot manifest". So a cross-engine plugin must ship **both**:

```jsonc
// .github/plugin/marketplace.json  (Copilot engine)
{ "name": "my-skills", "owner": { "name": "..." },
  "metadata": { "description": "...", "version": "1.0.0" },
  "plugins": [ { "name": "my-skills", "description": "...", "version": "1.0.0", "source": ".github/plugin" } ] }

// .claude-plugin/marketplace.json  (Claude engine)
{ "name": "my-skills", "owner": { "name": "..." },
  "metadata": { "description": "...", "version": "1.0.0" },
  "plugins": [ { "name": "my-skills", "source": "./.github/plugin", "description": "..." } ] }
```

**Critical: Agency installs a plugin by copying its `source` directory**, so that directory must be **self-contained** — `skills/`, hooks, and scripts must live *inside* it (paths in `plugin.json` are relative to the plugin dir, e.g. `"skills": ["./skills/"]`). Skills outside the `source` dir (e.g. at the repo root) are NOT copied and won't load. If your skills live at the repo root, move the real dir into the plugin dir and use a back-compat symlink at the root (Agency reads the real dir, never the symlink, so there's no symlink-resolution risk). The installed plugin lands at `~/.copilot/installed-plugins/<marketplace>/<plugin>/`, and Agency loads it into a copilot session via `--plugin-dir <temp>/<plugin>`.

- Install: `agency plugin install "market:<name>@<repo-url>" --engine copilot --cache-policy auto --cache-ttl 86400`. Agency fetches the manifest from the **remote** (push first).
- Why go Agency for a plugin with hooks: the Copilot CLI plugin loader drops `plugin.json` hooks and a *direct* install isn't managed by Agency, so its `copilot-hooks.json` is never injected. Only an **Agency-managed** install injects the hooks globally (see Plugin Hooks).
- **The engine-aware manifest is necessary but NOT sufficient for Claude — each *plugin `source` dir* also needs its own `.claude-plugin/plugin.json`.** The catalog `.claude-plugin/marketplace.json` only lists plugins; when Agency actually acquires a plugin for the Claude engine it validates the plugin directory and fails with **`Not a valid Claude plugin directory (missing .claude-plugin/plugin.json): <source-dir>`**. So a *multi-plugin* marketplace where each plugin lives at `.github/plugin/<name>/` is Copilot-installable but **not Claude-installable** until every `<name>/` also carries a `.claude-plugin/plugin.json` (a Copilot-only split is fine — just don't advertise Claude support the per-plugin dirs can't honor).
- **`Install-AgencyPlugin` / `agency plugin install` without `--engine` attempts BOTH engines**, and surfaces the Claude leg's failure as a **hard error even when Copilot succeeded** ("Plugin install partially succeeded: succeeded for Copilot, failed for Claude"). For a Copilot-only plugin, **always pass `--engine copilot`** (as the DSC `AgencyPlugin` resource does) so the missing-Claude-manifest failure doesn't mask a good install.

## Agency Config, Profiles, and Native CLI (verified)

The Agency config (`agency.yaml` / `agency.toml`) controls which plugins/MCPs load. Verified facts useful when authoring config or profiles:

- **Discovery & merge:** Agency merges a **global** config (`~/AppData/Local/agency/agency.toml`) and a **workspace** `./agency.toml` in the cwd (lowest→highest priority). There is **no `include` directive** — to share config you append/merge text or generate it.
- **Plugins live under `[[plugins.default]]`** (array-of-tables): `plugin = "market:<name>@<location>"`, optional `engines = ["copilot"]`, `cache_policy`, `fetch_mode`. `agency plugin install` writes here.
- **Profiles = different plugin sets for different work.** `[[profiles.<name>.plugins.default]]` (same entry shape) defines a profile; activate with `agency copilot --profile <name>` (deep-merge over base) or `--profile-only <name>` (the profile is the ONLY config — replaces base `plugins.default` **and narrows MCP** to non-ambient sources + the profile's plugins). `--no-config-plugins` suppresses `plugins.default` so only `--plugin` ones load.
- **No native "install into a profile":** `agency plugin install` has no `--profile` flag — it only writes base `plugins.default`. Manage profile membership by editing the config (`[[profiles.<name>.plugins.default]]`) and re-merging.
- **`agency marketplace` has ONLY `add`** (no native `list`/`remove`/`browse` — those exist only at the engine level, `agency copilot plugin marketplace …`). `marketplace add` takes `--marketplace` (presets curated/playground/all or a source, repeatable), `--engine`, `--fix-git-auth`.
- **Config commands:** `agency config get <dot-path>` reads (e.g. `profiles.os.plugins.default`); `agency config check` validates; `agency config set <dot-path> <yaml>` writes — but **`set` targets the repo-root config and requires a git repo** (errors "Failed to resolve repo-root config path (are you in a git repo?)" otherwise), and complex array values are awkward to quote, so editing the TOML directly + validating with `config check` is more robust.

## The `.github/skills` Auto-Discovery Symlink

Create `.github/skills` as a symlink to the real skills directory. Copilot CLI looks for skills under `.github/skills/` and **auto-discovers** them when you work inside the repo — no install required.

```powershell
# If skills live at the repo root:
New-Item -ItemType SymbolicLink -Path .github/skills -Target ../skills
# If skills live inside the plugin dir (Agency self-contained layout):
New-Item -ItemType SymbolicLink -Path .github/skills -Target plugin/skills
```

When the real skills dir is moved into the plugin dir (for Agency), also add a repo-root `skills` symlink back to it so existing `skills/...` references and doc-check globs keep resolving.

## SKILL.md Conventions

- Path: `skills/<kebab-name>/SKILL.md`.
- YAML frontmatter with `name` (kebab-case, ≤ 64 chars, `[a-z0-9-]` only) and `description` (≤ 1024 chars).
- The `description` is the **discovery surface** — include trigger phrases ("Use when asked to…") so the model invokes it at the right time.
- Body: patterns, gotchas, error messages, code examples.
- **Frontmatter must be valid YAML** — quote any `description` containing a colon (`:`), or the skill fails to load with "mapping values are not allowed in this context". A skill with no frontmatter fails with "missing or malformed YAML frontmatter".

## Prompt Templates

- Path: `skills/<name>/<prompt-name>.prompt.md`.
- YAML frontmatter with a `description`; markdown body is the runnable workflow.
- Invocable from the CLI as a slash command.

## Plugin Hooks

A plugin can run commands on agent lifecycle events. **The Copilot CLI plugin
loader does NOT read a `hooks` field from `plugin.json`** — its plugin-entry
assembly only propagates `skills`, `mcpServers`, `agents`, and `commands`, so a
`hooks` key in `plugin.json` is silently dropped. The mechanisms that actually
work:

- **Workspace hooks** — `<gitRoot>/.github/hooks/*.json`, loaded for anyone
  working in that repo (raw `copilot` and Agency).
- **Agency `copilot-hooks.json` convention** — a `copilot-hooks.json` at the
  plugin root is acquired by Agency and the plugin is passed to the session via
  `copilot --plugin-dir <cached-plugin>`; the CLI then **loads that plugin's
  hooks** (verified in the session log: `Loaded N hook(s) from M plugin(s)`).
  This is how cross-engine plugins ship Copilot hooks globally. Pair it with an
  `agency.json` (`{"engines":["claude","copilot"],"platforms":["windows"]}`).
  A *direct* (`_direct/`) Copilot install is NOT managed by Agency, so its
  `copilot-hooks.json` is never injected — only an Agency-managed install works.

At runtime the CLI exposes the plugin directory as **`${PLUGIN_ROOT}`** (Claude
Code uses **`${CLAUDE_PLUGIN_ROOT}`**).

**Two formats — there are two distinct hook systems** (a cross-engine plugin
ships one file for each, like other cross-engine reference plugins:
`agent-terminal-notifications`):

- **Copilot CLI** (`copilot-hooks.json` at plugin root) — `version: 1`,
  **camelCase** events:
  ```json
  {
    "version": 1,
    "hooks": {
      "sessionEnd":    [ { "type": "command", "powershell": "...", "bash": "...", "timeoutSec": 10 } ],
      "errorOccurred": [ { "type": "command", "powershell": "..." } ]
    }
  }
  ```
  Each command needs `powershell` and/or `bash` (on Windows the CLI runs
  `powershell`); optional `cwd`, `env`, `timeoutSec` (default 30). Events:
  **`sessionStart`, `sessionEnd`, `userPromptSubmitted`, `preToolUse`,
  `postToolUse`, `errorOccurred`**.
- **Claude Code / VS Code** (`hooks/hooks.json`) — **PascalCase** events, nested
  `hooks` arrays, `command` field, optional `"async": true`:
  ```json
  { "hooks": { "Notification": [ { "hooks": [ { "type": "command", "command": "...", "async": true } ] } ] } }
  ```
  Events include `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `Stop`,
  `SessionEnd`, and **`Notification`** (with `notification_type:
  "permission_prompt"` when the agent needs your approval/input).

**Gotchas / learnings:**
- The hook **payload arrives on stdin** as JSON (snake_case fields:
  `hook_event_name`, `notification_type`, `message`, `session_id`). Detect the
  engine by event-name casing (PascalCase ⇒ Claude, camelCase ⇒ Copilot).
- **Copilot CLI has NO permission/notification event** — "the agent is waiting
  for your input" is only observable on Claude/VS Code via `Notification`
  (fires for both permission prompts and idle-waiting). On Copilot CLI the
  closest signals are `sessionEnd` (done) and `errorOccurred`.
- **For a *notification* hook, decide what's "attention needed" in the renderer,
  not by which events you subscribe to.** Two viable designs: (a) hook only the
  attention events (`errorOccurred` on Copilot, `Notification` on Claude), or
  (b) subscribe to **all** events and let the renderer map each to a state and
  only toast on `error`/`permission` (keeping `working`/`completed`/`exit`
  silent). This repo uses (b) — it's more flexible (one place to change policy)
  at the cost of more process spawns. Per-tool/working events
  (`userPromptSubmitted`, `pre/postToolUse`) must stay **silent** or you toast on
  every tool call. A finished **main-agent turn** (Claude `Stop`) CAN be a
  legitimate "your turn" toast — but you must distinguish it from noise: a
  **sub-agent** turn-end arrives as a separate event (Claude `SubagentStop`) that
  you keep silent, and a **subconscious/maintenance worker** finishing a turn is
  detectable by resolving its `session_id` to the workspace.yaml `name` and
  matching the maintenance markers (`context_board`, `session insights`,
  `Analyze the session file`) — suppress those. Copilot CLI has **no** turn-end
  event (its `sessionEnd` is teardown), so a "your turn" toast is Claude/VS Code
  only. **Caveat for `preToolUse`:** Copilot *awaits*
  the `preToolUse` hook (it can return a permission decision), so hooking it adds
  a per-tool process spawn to every tool call — keep the launcher strictly
  fire-and-forget (return immediately, no decision) so the await stays brief.
- **Launch heavy work fire-and-forget** (e.g. `Start-Process … -WindowStyle
  Hidden` with no `-Wait`) so the hook returns instantly and never blocks the
  session — important when the first invocation compiles (e.g. `dotnet run` of a
  file-based app). A thin PowerShell launcher that forwards stdin to the real
  renderer keeps the hooks file simple (the reference plugin uses this shape).
- File-based C# apps (`dotnet run app.cs` with `#:property TargetFramework=…`)
  build to a cached artifacts dir, so they don't litter the repo with `bin/obj`.
- Unpackaged toasts: `CommunityToolkit`/`ToastNotificationManagerCompat` fails
  to initialize from a transient process ("Failed initializing notifications").
  Instead register a lightweight HKCU `AppUserModelId` and show a raw WinRT
  `ToastNotification` against it (built into the `net*-windows10.0.x` TFM).
- **The toast *header* app icon must be a `.ico`** — set it as the `IconUri`
  value under `HKCU\Software\Classes\AppUserModelId\<Aumid>`. A `.png` is
  silently rejected for the header slot (it only works for an inline
  `appLogoOverride` image, which renders in the body, not the header). Bundle a
  `.ico` and pass its path to the renderer (e.g. via an env var the launcher
  sets) so it works regardless of install location.
- **Friendly attribution from the session id**: the payload's `session_id`
  resolves to a human name by parsing
  `~/.copilot/session-state/<id>/workspace.yaml` — prefer the `name:` field
  (handle YAML block scalars `|-`/`>-`), fall back to the legacy `summary:`
  field, then to a shortened id. Mirrors the `Get-CopilotSession` parse.
- **One toast per session (dedup)**: set the `ToastNotification`'s `Tag` (and a
  constant `Group`) to a per-session key — showing a new toast with the **same
  `Tag`+`Group` on the same AUMID supersedes** the session's previous toast, so a
  session that hits several attention events shows at most one live toast instead
  of stacking. `Tag`/`Group` are capped at **64 chars** (Win10 1511+), so sanitize
  the session GUID (strip the dashes → 32 hex chars). On session end
  (`sessionEnd`/`exit`), proactively clear the session's lingering toast from the
  Action Center with `ToastNotificationManager.History.Remove(tag, group, Aumid)`
  (wrap in try/catch — a cleanup failure must never break the fire-and-forget hook).
- **GOTCHA — interactive Copilot CLI hook payloads carry no `session_id`.** Only
  the Claude Code events include `session_id`; the Copilot CLI events
  (`sessionStart`/`userPromptSubmitted`/`pre`/`postToolUse`/`errorOccurred`/`sessionEnd`)
  carry just `timestamp` + `cwd` (+ event-specific fields), and there's no session-id
  env var for interactive hooks (`COPILOT_AGENT_SESSION_ID` is the background
  SWE-agent, not the CLI). So a session-id-keyed toast tag is **always null on
  Copilot** — toasts stack and `History.Remove` on `sessionEnd` no-ops (nothing is
  cleared). Fall back to a **hash of the `cwd`** (present in every Copilot payload,
  including `sessionEnd`) for the per-session key: `Tag = session_id ?? hash(cwd)`.
  Normalize the cwd (trim/lowercase/strip trailing slash) so the start and end
  payloads hash identically. Caveat: two sessions in the same cwd then share a key
  (they supersede/clear each other) — acceptable since there's nothing else to
  disambiguate them by.
- **Defer to the host agent's own notifications setting**: Copilot CLI has a
  built-in `notifications` setting (defaults off) that raises its *own* OS toast
  "when user attention is required and when the agent finishes". Gate the custom
  toast on it so you don't double-notify — read `~/.copilot/settings.json` **and**
  `config.json` (the sibling `beep` lives in settings.json; check both for
  robustness) and fire only when `notifications` is explicitly off. Use a **tri-state**
  read (on / off / undetermined) and **fail closed** — suppress when it's on *or*
  can't be determined (files missing or unparseable), so a transient read failure
  never produces a duplicate toast. Wrap all IO in try/catch (config reads must not
  break the hook).

## Version-Sync Rule (critical)

Keep one plugin's version synchronized across its own engine-specific surfaces:
- `<plugin>/plugin.json` is the authoritative plugin version.
- The matching `plugins[]` entry in the Copilot marketplace uses that version.
- Any Claude plugin manifest for the same plugin uses that version.

Focused plugins are versioned independently. The catalog's `metadata.version`
changes only when the plugin set or catalog contract changes; it does not need
to match every plugin version. Add a matching entry to `CHANGELOG.md`.

## Install & Distribution

- **Copilot CLI** (direct, ADO/GitHub URL):
  ```
  /plugin install https://dev.azure.com/org/project/_git/Repo
  ```
- **Agency** (as a marketplace plugin, cached + background-refreshed):
  ```
  agency plugin install market:<name>@https://dev.azure.com/org/project/_git/Repo --engine copilot
  ```
- Agency-installed plugins with `--engine copilot` load **only** under `agency copilot` sessions, not bare `copilot`. For a plugin you want available everywhere, install it directly in Copilot CLI. (See `copilot-session-management`.)

## Cross-Engine Marketplace (Agency + Copilot + VS Code + Claude)

A repo can serve as a shared marketplace installable across engines by layering:
- **Agency base** (winpx.copilot convention): `agency.toml` + `agency-configs/` for Agency-specific config.
- **Catalog**: a `marketplace.json` file listing one or more plugins.
- A **template/example plugin** (`plugins/<example>/plugin.json` + a sample `skills/<skill>/SKILL.md` + per-skill and shared scripts) plus a `CONTRIBUTING.md` so other contributors can add plugins.
- A repo-level `.github/copilot-instructions.md` describing the marketplace conventions.

Keep governance minimal and the structure generic so any team can contribute plugins.

## Gotchas

- **Trailing-whitespace / indentation in JSON** is harmless but keep `plugins[0].version` aligned — it's easy to miss when bumping versions.
- The `.github/skills` symlink must be committed as a symlink (git stores it correctly on Windows when `core.symlinks=true`).
- When adding a new skill: update `.github/plugin/README.md` (table + structure listing), bump all three version fields, and add a CHANGELOG entry — see `skill-scanning` for the full release checklist.
