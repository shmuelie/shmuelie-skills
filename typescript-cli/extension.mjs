import { joinSession } from "@github/copilot-sdk/extension";

const SKILL_KNOWLEDGE = `
# TypeScript CLI Patterns — Domain Knowledge

## Process Pool Management (e.g., ExifTool)
- Spawn a pool of worker processes matching CPU count (minimum 4).
- Use a concurrency limiter (e.g., 32 concurrent operations) to avoid overwhelming the system.
- Reuse long-lived processes instead of spawning per-operation — massive perf win.
- Clean up on SIGINT/SIGTERM: kill all child processes, save state, then exit.

## Atomic Cache Writes
- NEVER write directly to the cache file — a crash mid-write corrupts it.
- Pattern: write to \`.tmp\` file, then \`fs.renameSync()\` to the real path.
- \`rename\` is atomic on most filesystems.
- Pretty-printed JSON adds ~40% to cache file size — use compact JSON for large caches.
- Large cache files (50MB+) cause event-loop blocking during JSON.stringify —
  this is synchronous and can take several seconds.

## Cache Versioning and Migration
- Store a CACHE_VERSION number in the cache file.
- On load, check version and migrate incrementally (v1→v2→v3).
- Separate concept: TAG_VERSION tracks "has this file been tagged with current logic".
- Store \`taggedFiles\` as Map<path, version> to know which files need re-tagging.

## Adaptive Rate Limiting
- Start with a base delay, increase on 429/rate-limit responses.
- Persist the current delay in the cache so it survives restarts.
- Track consecutive successes and slowly reduce delay (multiplicative decrease).
- Token refresh: attempt re-auth at most once per API call to avoid infinite loops.

## Graceful Shutdown (SIGINT/SIGTERM)
\`\`\`typescript
let shutdownRequested = false;
process.on('SIGINT', async () => {
    if (shutdownRequested) process.exit(1); // force on double Ctrl+C
    shutdownRequested = true;
    await saveState();
    process.exit(0);
});
\`\`\`
- Check \`shutdownRequested\` in processing loops to stop accepting new work.
- Save partial progress (cache offset, processed items) so work can resume.
- Second SIGINT forces immediate exit.

## File Matching Strategies (Multi-Tier)
1. **Exact CDN filename** — fastest, most reliable.
2. **ID extraction from slug/URL** — good when filenames contain deviation IDs.
3. **Normalized title matching** — fuzzy, lowercase + strip punctuation.
- For fuzzy matches, also verify file dimensions to avoid false positives.
- \`extractDeviationId()\`: require a digit in the ID to avoid matching English words
  starting with 'd' (download, digital, etc.).

## Windows-Specific Gotchas
- **PowerShell eats \`--\`** before npm sees it — all args must be positional.
- **ts-node consumes \`--flags\`** meant for the script — use
  \`node --require ts-node/register\` instead.
- **Windows Explorer** reads XP* EXIF tags (XPTitle, XPAuthor, XPComment, XPKeywords, XPSubject).
- **fs.renameSync on Windows** overwrites target instead of throwing EEXIST.
- **MAX_PATH is 260 chars** — truncate generated filenames to ~200 to leave room for path prefix.

## Common Bug Patterns
- **\`??\` vs \`||\` for empty string**: \`"" ?? "default"\` returns \`""\` (nullish coalescing
  doesn't treat empty string as nullish). Use \`||\` when empty string should fallback.
- **Race conditions in parallel rename (TOCTOU)**: Check existence then rename is unsafe —
  use try/catch with recursive retry on EEXIST.
- **Token refresh infinite loop**: Always cap re-auth attempts per call.
- **Symlink loops**: Use a visited-set (by inode/dev) when scanning directories recursively.
- **Pre-marking success**: Don't record a file as processed before the operation succeeds.
- **Tag cache serving stale data**: Invalidate cache entries when enrichment status changes.

## Progress and Status Output
- All progress/status output goes to stderr; stdout reserved for data.
- Windows Terminal supports OSC 9;4 for taskbar progress ring:
  \`\\x1b]9;4;1;{percent}\\x07\` (set) and \`\\x1b]9;4;0;0\\x07\` (clear).
- OSC 0/1/2 for window title: \`\\x1b]0;{title}\\x07\`.

## Matroska (MKV/WebM) Tagging
- Use \`mkvpropedit\` for native Matroska tags (no temp file needed).
- Build XML tag structure matching Matroska spec (Tag > Targets > Simple > Name+String).
- For images/other media, use ExifTool with EXIF/XMP/IPTC tag groups.
- ExifTool \`-fast2\` flag reads only file header — much faster for large media files.
`.trim();

const session = await joinSession({
    hooks: {
        onUserPromptSubmitted: async (input) => {
            const prompt = input.prompt.toLowerCase();
            const triggers = [
                "exiftool", "process pool", "worker pool",
                "atomic write", "cache write", "cache version",
                "rate limit", "rate-limit", "adaptive",
                "sigint", "sigterm", "graceful shutdown",
                "mkvpropedit", "matroska tag",
                "osc 9", "taskbar progress",
                "max_path", "filename truncat",
            ];
            if (triggers.some((t) => prompt.includes(t))) {
                return { additionalContext: SKILL_KNOWLEDGE };
            }
        },
    },
    tools: [
        {
            name: "typescript_cli_guidance",
            description:
                "Get domain knowledge about TypeScript CLI patterns: process pools, atomic caching, rate limiting, graceful shutdown, file matching, Windows gotchas. Use when building TypeScript CLI tools.",
            parameters: {
                type: "object",
                properties: {
                    topic: {
                        type: "string",
                        description:
                            "The topic: 'process-pool', 'caching', 'rate-limiting', 'shutdown', 'file-matching', 'windows', 'bugs', 'progress', 'matroska', or 'all'",
                        enum: [
                            "process-pool", "caching", "rate-limiting", "shutdown",
                            "file-matching", "windows", "bugs", "progress", "matroska", "all",
                        ],
                    },
                },
                required: ["topic"],
            },
            handler: async (args) => {
                if (args.topic === "all") return SKILL_KNOWLEDGE;
                const headings = {
                    "process-pool": "## Process Pool",
                    caching: "## Atomic Cache",
                    "rate-limiting": "## Adaptive Rate",
                    shutdown: "## Graceful Shutdown",
                    "file-matching": "## File Matching",
                    windows: "## Windows-Specific",
                    bugs: "## Common Bug",
                    progress: "## Progress and Status",
                    matroska: "## Matroska",
                };
                const heading = headings[args.topic];
                if (!heading) return SKILL_KNOWLEDGE;
                const start = SKILL_KNOWLEDGE.indexOf(heading);
                if (start === -1) return SKILL_KNOWLEDGE;
                const rest = SKILL_KNOWLEDGE.slice(start);
                const nextSection = rest.indexOf("\n## ", 4);
                return nextSection === -1 ? rest : rest.slice(0, nextSection);
            },
        },
    ],
});
