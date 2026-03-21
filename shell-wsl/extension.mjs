import { joinSession } from "@github/copilot-sdk/extension";

const SKILL_KNOWLEDGE = `
# Shell Scripting & WSL — Domain Knowledge

## Shell Script Bug Patterns

### exit vs return
- \`return\` only works in **sourced** scripts or functions.
- When a script is **executed** (\`./script.sh\` or \`bash script.sh\`), \`return\` is invalid.
- Use \`exit 1\` for executable scripts, \`return 1\` inside functions.
- \`return -1\` is technically undefined behavior — use \`exit 1\` or \`return 1\`.

### Variable Quoting (CRITICAL)
- Always quote variables: \`"$var"\`, \`"$@"\`, \`"$file"\`.
- Unquoted variables cause word splitting on spaces/newlines.
- \`$@\` → \`"$@"\` — preserves argument boundaries.
- \`rm /path/$var/*\` → \`rm "/path/$var/"*\` — prevents glob expansion of empty var.

### Directory Safety
- Always \`mkdir -p\` before writing to directories that may not exist.
- \`rm dir/*\` fails if directory is empty — use \`rm -f dir/* 2>/dev/null || true\`
  or check first: \`[ -d dir ] && find dir -type f -delete\`.

### Error Handling
- \`set -euo pipefail\` at the top of scripts:
  - \`-e\`: exit on error
  - \`-u\`: treat unset variables as errors
  - \`-o pipefail\`: pipe fails if any command fails (not just the last)
- Chain with \`&&\` when you want dependent commands to stop on failure.

## Upgrade / Update Script Patterns

### git_pull_and_build Helper
\`\`\`bash
git_pull_and_build() {
    local repo_dir="$1"; shift
    local old_head new_head
    cd "$repo_dir"
    old_head=$(git rev-parse HEAD)
    git pull --ff-only
    new_head=$(git rev-parse HEAD)
    if [ "$old_head" = "$new_head" ]; then
        echo "No changes, skipping rebuild"
        return 0
    fi
    "$@"  # Run build commands passed as remaining args
}
\`\`\`
- Only rebuilds when \`git pull\` brings new commits.
- Build commands passed as trailing arguments for flexibility.

### Dependency Ordering
- Build in dependency order: e.g., ncurses → tmux, nano (both depend on ncurses).
- Each section is independent — failures propagate via \`set -e\`.

### Package Manager Detection
\`\`\`bash
# Only run if the command exists
command -v snap >/dev/null 2>&1 && snap refresh
command -v npm  >/dev/null 2>&1 && sudo npm update -g
command -v pip3 >/dev/null 2>&1 && pip3 install --user --upgrade <packages>
command -v rustup >/dev/null 2>&1 && rustup update
command -v cargo >/dev/null 2>&1 && cargo install-update --all
\`\`\`
- Guard each section with \`command -v\` — silently skipped if not installed.
- \`npm update -g\` needs \`sudo\` when global prefix is root-owned (\`/usr/local\`).

### Systemd Detection
\`\`\`bash
# Check for systemd (important for WSL where it may not be PID 1)
if [ -d /run/systemd/system ]; then
    sudo fwupdmgr refresh && sudo fwupdmgr update
fi
\`\`\`
- \`fwupdmgr\` needs \`sudo\` to bypass polkit (unavailable without systemd).
- Snap requires systemd — won't function in WSL without it.

## WSL-Specific Quirks

### Systemd in WSL
- By default, WSL2 does NOT run systemd as PID 1.
- To enable: add to \`/etc/wsl.conf\`:
  \`\`\`ini
  [boot]
  systemd=true
  \`\`\`
- Then restart: \`wsl --shutdown\` from PowerShell.
- Without systemd: snap, polkit, fwupd, and other systemd-dependent tools fail.

### Terminal / Progress Indicators
- \`TERM=xterm-color\` is too limited — causes Copilot CLI to skip progress indicators.
- Fix: set \`TERM=xterm-256color\` in tmux config:
  \`\`\`
  set -g default-terminal "xterm-256color"
  \`\`\`
- Then restart tmux (\`tmux kill-server\`).

### APT Troubleshooting
- **Broken repo files**: Check \`/etc/apt/sources.list.d/\` for wrong URLs
  (e.g., Edge repo pointing at Chrome URL).
- **Legacy keyrings**: \`/etc/apt/trusted.gpg\` is deprecated — migrate keys to
  \`/etc/apt/trusted.gpg.d/\` as individual \`.gpg\` files.
- **Stale local repos**: Check \`/var/cuda-repo-*\` and similar — can waste gigabytes.
  Remove the \`.list\` file and the local repo directory.
- \`apt-key\` is deprecated — use \`signed-by=\` in repo definitions.

### Cross-Compilation from WSL
- Rsync sources to WSL native filesystem for better build performance
  (avoid Windows filesystem overhead via \`/mnt/c/\`).
- Visual Studio remote development presets work with WSL via CMake vendor settings.

## Embedded Device Shell Patterns (mFi/OpenWrt)

### Symlink-Based Config
- DRY principle: shared files (profile, rc.poststart, mqtt.ini) aren't duplicated.
- Device directories contain only symlinks to shared files + device-specific configs.
- \`add.sh\` bootstraps a new device directory with appropriate symlinks.

### Deployment Pipeline
\`\`\`bash
# 1. Archive device config
tar czf /tmp/config.tar.gz -C device_dir .
# 2. SCP to device
scp /tmp/config.tar.gz ubnt@device.local:/tmp/
# 3. SSH: stop, deploy, commit, restart
ssh ubnt@device.local 'cd /var/etc/persistent && \\
    /usr/bin/mfi-mqtt-client stop && \\
    tar xzf /tmp/config.tar.gz -C bin/ && \\
    cfgmtd -w -p /etc/ && \\
    /var/etc/persistent/rc.poststart'
\`\`\`

### Startup System
- \`rc.poststart\` runs all executable scripts in \`rc.poststart.d/\` in parallel (\`&\`).
- Modular: add new services by dropping scripts into the directory.
- Non-executable files are skipped.

## Rust/Cargo Patterns (from WSL-Hello-sudo)
- \`clippy -- -D warnings\` treats all warnings as errors (strict linting).
- \`Cow<str>\` → \`Cow<'_, str>\` — always make elided lifetimes explicit.
- \`#[allow(dead_code)]\` on enum variant fields that are matched structurally
  but never read directly.
- \`Some(code) if code == 0\` → \`Some(0)\` — simplify redundant guards.
- \`bindgen\` for C FFI bindings generation.
`.trim();

const session = await joinSession({
    hooks: {
        onUserPromptSubmitted: async (input) => {
            const prompt = input.prompt.toLowerCase();
            const triggers = [
                "shell script", "bash script", "upgrade.sh",
                "wsl", "systemd", "apt", "snap",
                "set -e", "pipefail", "quoting",
                "embedded deploy", "cfgmtd", "rc.poststart",
                "clippy", "rustup", "cargo",
                "xterm-256color", "term=",
            ];
            if (triggers.some((t) => prompt.includes(t))) {
                return { additionalContext: SKILL_KNOWLEDGE };
            }
        },
    },
    tools: [
        {
            name: "shell_wsl_guidance",
            description:
                "Get domain knowledge about shell scripting patterns, WSL quirks, embedded device deployment, and Rust/Cargo. Use for bash/shell scripts, WSL configuration, or embedded Linux deployment.",
            parameters: {
                type: "object",
                properties: {
                    topic: {
                        type: "string",
                        description:
                            "The topic: 'shell-bugs', 'upgrade-scripts', 'wsl', 'apt', 'embedded-deploy', 'rust', or 'all'",
                        enum: ["shell-bugs", "upgrade-scripts", "wsl", "apt", "embedded-deploy", "rust", "all"],
                    },
                },
                required: ["topic"],
            },
            handler: async (args) => {
                if (args.topic === "all") return SKILL_KNOWLEDGE;
                const headings = {
                    "shell-bugs": "## Shell Script Bug",
                    "upgrade-scripts": "## Upgrade / Update",
                    wsl: "## WSL-Specific",
                    apt: "### APT Troubleshooting",
                    "embedded-deploy": "## Embedded Device Shell",
                    rust: "## Rust/Cargo",
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
