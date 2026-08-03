#:property TargetFramework=net10.0-windows10.0.19041.0

// Show-CopilotToast.cs
//
// A .NET 10 file-based single-file app that renders a Windows toast notification
// for AI coding-agent hook events (Copilot CLI and Claude Code / VS Code).
//
// It reads the hook payload as JSON from stdin, normalizes the event to an
// internal state (working / done / subagent / permission / error / exit) using
// the same casing-based engine detection used by cross-engine reference plugins
// `agent-terminal-notifications` reference plugin, and only raises a toast for
// the "attention" states (permission, error, and done = the main agent finished
// its turn). A finished turn from a subconscious/maintenance worker session, and
// sub-agent turn-ends (SubagentStop -> "subagent"), are suppressed. Working/exit
// states are also silent, so there's no toast spam on every tool call.
//
// One toast per session: each toast is tagged with a per-session key (Tag =
// session id when present, else a hash of the cwd, since interactive Copilot CLI
// hook payloads carry no session id; Group = "copilot-cli"), so a new toast for a
// session supersedes that session's previous toast — at most one live toast per
// session in the Action Center. Toasts with neither id nor cwd are shown untagged
// and stack as before. On session end (the "exit" state) the session's toast is
// removed from the Action Center so a closed session leaves nothing behind.
//
// It also defers to Copilot's own notifications: a toast is raised only when the
// CLI's `notifications` setting is OFF (read from ~/.copilot/settings.json and
// config.json). When that setting is ON — or can't be determined — Copilot already
// raises its own OS toast, so this hook stays silent to avoid duplicates.
//
// The toast is shown with raw WinRT (Windows.UI.Notifications) against a
// lightweight HKCU-registered AppUserModelId, which works for an *unpackaged*,
// transient `dotnet run` process (no Start-menu shortcut / MSIX required).
//
// Invoked by the plugin hook launchers (see copilot-hooks.json / hooks.json).
// Designed to be launched fire-and-forget so it never blocks the agent session.
//
// Debug: set COPILOT_TOAST_DEBUG=1 to append the raw stdin + decision to
// %TEMP%\copilot-toast-debug\toast.log (use this to confirm payload field names
// on a given CLI build).

using System;
using System.IO;
using System.Security;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.Win32;
using Windows.Data.Xml.Dom;
using Windows.UI.Notifications;

const string Aumid = "Shmuelie.CopilotCLI.Toast";

// Toasts are grouped under a single constant so that reusing a per-session Tag
// (see SessionKey) supersedes a session's previous toast — at most one live toast
// per session in the Action Center.
const string ToastGroup = "copilot-cli";

static string? DebugDir() =>
    Environment.GetEnvironmentVariable("COPILOT_TOAST_DEBUG") == "1"
        ? Path.Combine(Path.GetTempPath(), "copilot-toast-debug")
        : null;

static void DebugLog(string message)
{
    var dir = DebugDir();
    if (dir is null) return;
    try
    {
        Directory.CreateDirectory(dir);
        File.AppendAllText(
            Path.Combine(dir, "toast.log"),
            $"{DateTime.Now:HH:mm:ss.fff} {message}{Environment.NewLine}");
    }
    catch { /* never let logging break the hook */ }
}

// Toasts are Windows-only. No-op everywhere else so the hook stays harmless.
if (!OperatingSystem.IsWindows())
    return;

// Allow explicit payload-file and event overrides for detached launchers.
string? eventArg = null;
string? payloadFileArg = null;
for (int i = 0; i < args.Length - 1; i++)
{
    if (string.Equals(args[i], "--event", StringComparison.OrdinalIgnoreCase))
        eventArg = args[i + 1];
    else if (string.Equals(args[i], "--payload-file", StringComparison.OrdinalIgnoreCase))
        payloadFileArg = args[i + 1];
}

string raw = "";
if (!string.IsNullOrWhiteSpace(payloadFileArg))
{
    try { raw = File.ReadAllText(payloadFileArg); }
    catch { /* ignore */ }
    finally
    {
        try { File.Delete(payloadFileArg); } catch { /* ignore */ }
    }
}
else
{
    try { raw = Console.In.ReadToEnd(); } catch { /* ignore */ }
}
DebugLog($"raw payload: {raw}");

string hookEvent = eventArg ?? "";
string notificationType = "";
string message = "";
string sessionId = "";
string cwd = "";

if (!string.IsNullOrWhiteSpace(raw))
{
    try
    {
        using var doc = JsonDocument.Parse(raw);
        var root = doc.RootElement;
        if (eventArg is null)
            hookEvent = GetString(root, "hook_event_name", "hookEventName", "event", "type") ?? "";
        notificationType = GetString(root, "notification_type", "notificationType") ?? "";
        message = GetString(root, "message", "summary", "reason", "error") ?? "";
        sessionId = GetString(root, "session_id", "sessionId") ?? "";
        cwd = GetString(root, "cwd", "workingDir", "working_dir") ?? "";
    }
    catch (Exception ex)
    {
        DebugLog($"json parse failed: {ex.Message}");
    }
}

var (state, agent) = Normalize(hookEvent, notificationType);
DebugLog($"event={hookEvent} type={notificationType} -> state={state} agent={agent}");

// The per-session Tag: a new toast with the same Tag+Group supersedes this
// session's previous toast, so only the most recent one is ever shown. Derived
// from the session id when present (Claude), else from the cwd (Copilot CLI hook
// payloads carry no session id — only cwd), else null (untagged, stack as before).
string? tag = SessionKey(sessionId, cwd);

// On session end, proactively remove this session's lingering toast (e.g. a
// "your turn" notification) from the Action Center so a closed session doesn't
// leave a stale toast behind. Then return — sessionEnd is not itself a toast.
if (state == "exit")
{
    if (tag is not null)
    {
        try
        {
            ToastNotificationManager.History.Remove(tag, ToastGroup, Aumid);
            DebugLog($"removed session toast on exit: tag={tag}");
        }
        catch (Exception ex)
        {
            DebugLog($"history remove failed: {ex.Message}");
        }
    }
    return;
}

// A finished main-agent turn ("done") is attention-worthy ("your turn") — but
// NOT when it comes from a subconscious/maintenance worker session (those run
// the context_board / session-insights maintenance and would just be noise).
// Sub-agent turn-ends arrive as the separate SubagentStop event (state
// "subagent"), which is never toasted.
if (state == "done" && IsMaintenanceSession(sessionId))
{
    DebugLog("suppressing Stop toast: subconscious/maintenance worker session");
    return;
}

// States that genuinely need YOUR attention get a toast: a permission / input
// prompt, an error, or the main agent finishing its turn ("done"). Other states
// ("working"/"completed"/"exit"/"subagent") are silent — we do NOT notify just
// because a sub-task or sub-agent finished.
string? heading = state switch
{
    "permission" => "Copilot needs your input",
    "error"      => "Copilot hit an error",
    "done"       => "Copilot finished — your turn",
    _            => null,
};

if (heading is null)
    return;

// Only notify when Copilot's own OS notifications are OFF — otherwise Copilot
// already raises its own toast and ours would be a duplicate. Suppress when the
// setting is ON or can't be determined (fail-closed). Reached only for genuine
// toast states (permission/error/done); working/subagent/exit already returned.
bool? copilotNotifications = agent == "copilot" ? CopilotNotificationsEnabled() : false;
if (agent == "copilot" && copilotNotifications != false)
{
    DebugLog("suppressing toast: copilot notifications setting = " +
        (copilotNotifications is null ? "undetermined" : "on"));
    return;
}

string body = !string.IsNullOrWhiteSpace(message)
    ? message
    : state switch
    {
        "permission" => "The agent is waiting for your response.",
        "error"      => "The agent reported an error.",
        "done"       => "The agent finished its turn and is waiting for you.",
        _            => "",
    };

string attribution = BuildAttribution(agent, sessionId);

try
{
    EnsureAumidRegistered();
    ShowToast(heading, body, attribution, tag);
    DebugLog($"toast shown{(tag is null ? "" : $" (tag={tag})")}");
}
catch (Exception ex)
{
    // A toast failure must never surface to the agent session.
    DebugLog($"toast failed: {ex.Message}");
}

return;

// --- helpers ---

// Read the first present string property from a set of candidate names.
static string? GetString(JsonElement obj, params string[] names)
{
    foreach (var name in names)
        if (obj.ValueKind == JsonValueKind.Object &&
            obj.TryGetProperty(name, out var v) &&
            v.ValueKind == JsonValueKind.String)
            return v.GetString();
    return null;
}

static string Short(string id) =>
    id.Length > 8 ? id.Substring(0, 8) : id;

// Build the toast attribution line. When a friendly session name is available,
// show just the name (no engine prefix). Otherwise fall back to
// "<engine> · <short id>", or just the engine name when no id is available.
static string BuildAttribution(string agent, string sessionId)
{
    string engine = agent == "claude" ? "Claude Code" : "Copilot CLI";

    string? name = ResolveSessionName(sessionId);
    if (!string.IsNullOrWhiteSpace(name))
    {
        DebugLog($"attribution name={name}");
        return name;
    }

    DebugLog($"attribution fallback engine={engine} id={(string.IsNullOrWhiteSpace(sessionId) ? "<none>" : Short(sessionId))}");
    return string.IsNullOrWhiteSpace(sessionId)
        ? engine
        : $"{engine} \u00b7 {Short(sessionId)}";
}

// True when the session is a subconscious/maintenance worker (by resolved name).
// Used to suppress the "your turn" toast for a finished maintenance turn. The
// markers are substrings that only appear in the auto-generated names of the
// context_board prune / session-insights maintenance jobs (mirrors the ignore
// list in Start-Copilot's auto-resume).
static bool IsMaintenanceSession(string sessionId)
{
    string[] markers = { "context_board", "session insights", "Analyze the session file" };
    string? name = ResolveSessionName(sessionId);
    if (string.IsNullOrWhiteSpace(name))
        return false;
    foreach (var marker in markers)
        if (name.Contains(marker, StringComparison.OrdinalIgnoreCase))
            return true;
    return false;
}

// Determine whether Copilot CLI's own `notifications` setting is on, so we don't
// double-notify: when Copilot raises its own OS toast we stay silent. Tri-state:
//   true  -> `notifications: true` found in ~/.copilot/settings.json or config.json
//   false -> at least one file parsed and none set it true (absent = CLI default off)
//   null  -> neither file could be read/parsed (undetermined; caller fails closed)
// Reads both global files (settings.json is where the documented sibling `beep`
// lives; config.json read for robustness). Never throws — a config read must not
// break the fire-and-forget hook.
static bool? CopilotNotificationsEnabled()
{
    string? home = Environment.GetEnvironmentVariable("USERPROFILE")
        ?? Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
    if (string.IsNullOrWhiteSpace(home))
        return null;

    bool anyParsed = false;
    foreach (var fileName in new[] { "settings.json", "config.json" })
    {
        string path = Path.Combine(home, ".copilot", fileName);
        if (!File.Exists(path))
            continue;
        try
        {
            using var doc = JsonDocument.Parse(File.ReadAllText(path));
            anyParsed = true;
            foreach (var prop in doc.RootElement.EnumerateObject())
            {
                if (string.Equals(prop.Name, "notifications", StringComparison.OrdinalIgnoreCase) &&
                    prop.Value.ValueKind == JsonValueKind.True)
                {
                    return true;
                }
            }
        }
        catch (Exception ex)
        {
            DebugLog($"notifications read failed for {fileName}: {ex.Message}");
        }
    }

    return anyParsed ? false : (bool?)null;
}

// Resolve a session id to its friendly name by parsing
// %USERPROFILE%\.copilot\session-state\<id>\workspace.yaml. Mirrors the
// Get-CopilotSession parse: prefer `name:` (handling YAML block scalars like
// |- / >-), then fall back to the legacy `summary:` field. Returns null if the
// file or fields are missing — the caller falls back to the short session id.
static string? ResolveSessionName(string sessionId)
{
    if (string.IsNullOrWhiteSpace(sessionId))
        return null;

    try
    {
        string home = Environment.GetEnvironmentVariable("USERPROFILE")
            ?? Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        if (string.IsNullOrWhiteSpace(home))
            return null;

        string wsFile = Path.Combine(home, ".copilot", "session-state", sessionId, "workspace.yaml");
        if (!File.Exists(wsFile))
            return null;

        string content = File.ReadAllText(wsFile);

        // name: |-  /  name: >-  (block scalar) -> first indented continuation line.
        var block = Regex.Match(content, @"(?m)^name:\s*[\|>]-?\s*\r?\n(\s{2,}.+)$");
        if (block.Success)
        {
            string v = block.Groups[1].Value.Trim();
            if (v.Length > 0) return v;
        }

        // name: inline value.
        var inline = Regex.Match(content, @"(?m)^name:[ \t]+(.+)$");
        if (inline.Success)
        {
            string v = inline.Groups[1].Value.Trim();
            if (v.Length > 0 && v != "|-" && v != ">-") return v;
        }

        // Legacy: summary: inline value.
        var summary = Regex.Match(content, @"(?m)^summary:[ \t]+(.+)$");
        if (summary.Success)
        {
            string v = summary.Groups[1].Value.Trim();
            if (v.Length > 0) return v;
        }
    }
    catch (Exception ex)
    {
        DebugLog($"resolve session name failed: {ex.Message}");
    }

    return null;
}

// Resolve an optional user-provided icon path from COPILOT_TOAST_ICON.
// Returns null if unset or missing.
// NOTE: the toast *header* app icon is taken from the AUMID's registered IconUri
// and must be a .ico — a .png is silently rejected for the header (though it
// works for an inline appLogoOverride image).
static string? IconPath()
{
    string? p = Environment.GetEnvironmentVariable("COPILOT_TOAST_ICON");
    return !string.IsNullOrWhiteSpace(p) && File.Exists(p) ? p : null;
}

// Register a minimal AppUserModelId in HKCU so an unpackaged process can raise a
// toast that displays a friendly app name. Idempotent and cheap.
static void EnsureAumidRegistered()
{
    using var key = Registry.CurrentUser.CreateSubKey(
        $@"Software\Classes\AppUserModelId\{Aumid}");
    key?.SetValue("DisplayName", "Copilot CLI");

    // IconUri is the small app icon shown in the toast header / Action Center.
    // Must be a .ico for the header to honor it.
    string? icon = IconPath();
    if (icon is not null)
        key?.SetValue("IconUri", icon);
}

static void ShowToast(string heading, string body, string attribution, string? tag)
{
    string xml =
        "<toast><visual><binding template=\"ToastGeneric\">" +
        $"<text>{Escape(heading)}</text>" +
        (string.IsNullOrWhiteSpace(body) ? "" : $"<text>{Escape(body)}</text>") +
        $"<text placement=\"attribution\">{Escape(attribution)}</text>" +
        "</binding></visual></toast>";

    var doc = new XmlDocument();
    doc.LoadXml(xml);

    var toast = new ToastNotification(doc);

    // Tag + Group key the toast to its session: showing a new toast with the same
    // Tag+Group supersedes the session's previous one, so only the most recent
    // toast per session is shown. Untagged (no session id) toasts stack normally.
    if (tag is not null)
    {
        toast.Tag = tag;
        toast.Group = ToastGroup;
    }

    ToastNotificationManager.CreateToastNotifier(Aumid).Show(toast);
}

// Build the per-session toast Tag: prefer the session id (Claude), sanitized to
// alphanumeric (drops the GUID dashes, well under the 64-char Tag limit). When
// there is no session id (interactive Copilot CLI hook payloads carry none — only
// `cwd`), fall back to a stable hash of the normalized cwd so a session's toasts
// still share one Tag and can be superseded/removed on exit. Returns null only
// when neither a session id nor a cwd is available (untagged, stack as before).
static string? SessionKey(string sessionId, string cwd)
{
    if (!string.IsNullOrWhiteSpace(sessionId))
    {
        var sanitized = Regex.Replace(sessionId, "[^A-Za-z0-9]", "");
        if (sanitized.Length > 0) return sanitized;
    }

    if (!string.IsNullOrWhiteSpace(cwd))
    {
        // Normalize so the sessionStart / errorOccurred / sessionEnd payloads for
        // the same session (which all carry the same cwd) hash identically.
        string norm = cwd.Trim().TrimEnd('\\', '/').ToLowerInvariant();
        byte[] hash = System.Security.Cryptography.SHA1.HashData(System.Text.Encoding.UTF8.GetBytes(norm));
        return "cwd" + Convert.ToHexString(hash); // "cwd" + 40 hex chars = 43 (< 64 Tag limit)
    }

    return null;
}

static string Escape(string s) => SecurityElement.Escape(s) ?? s;

// Mirror of the reference plugin's ConvertTo-InternalEvent: detect the agent by
// event-name casing (PascalCase => Claude, camelCase => Copilot) and map to an
// internal state. Returns (state, agent). Only "permission" and "error" produce
// a toast (see above); everything else is silent.
static (string state, string agent) Normalize(string hookEvent, string notificationType)
{
    string agent = (hookEvent.Length > 0 && char.IsLower(hookEvent[0])) ? "copilot" : "claude";

    if (agent == "copilot")
    {
        return hookEvent switch
        {
            "sessionStart"        => ("working", agent),
            "userPromptSubmitted" => ("working", agent),
            "preToolUse"          => ("working", agent),
            "postToolUse"         => ("working", agent),
            // sessionEnd is session teardown ("finished"), NOT attention-needed —
            // keep it silent so sub-sessions/turns don't spam toasts.
            "sessionEnd"          => ("exit", agent),
            "errorOccurred"       => ("error", agent),
            _                     => ("working", agent),
        };
    }

    // Claude Code (PascalCase).
    switch (hookEvent)
    {
        case "SessionStart":
        case "UserPromptSubmit":
        case "PreToolUse":
        case "PostToolUse":
            return ("working", agent);
        // Stop = the MAIN agent finished its turn → "your turn" (attention).
        // A subconscious/maintenance worker's Stop is filtered out later by
        // session name, and a sub-agent's turn-end arrives as SubagentStop.
        case "Stop":
            return ("done", agent);
        // SubagentStop = a Task/sub-agent finished → never toast (silent).
        case "SubagentStop":
            return ("subagent", agent);
        case "SessionEnd":
            return ("exit", agent);
        // Notification fires when Claude needs permission OR has been idle waiting
        // for you — both are genuinely "your attention is needed".
        case "Notification":
            return ("permission", agent);
        default:
            return ("working", agent);
    }
}
