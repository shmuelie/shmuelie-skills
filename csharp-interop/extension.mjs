import { joinSession } from "@github/copilot-sdk/extension";

const SKILL_KNOWLEDGE = `
# C# Native Interop — Domain Knowledge

## CsWin32 (Microsoft.Windows.CsWin32)
- Preferred over hand-written P/Invoke for Windows APIs.
- Add as \`<PackageReference Include="Microsoft.Windows.CsWin32" Version="0.3.269" PrivateAssets="all" />\`.
- Create \`NativeMethods.txt\` at project root listing needed Win32 functions/types, one per line.
- Generates safe, AOT-compatible wrappers with SafeHandle and proper marshalling.
- Works with \`PublishAot=true\` and \`DisableRuntimeMarshalling=true\`.

## LibraryImport (modern P/Invoke)
- Use \`[LibraryImport]\` instead of \`[DllImport]\` for new code — it's source-generated,
  AOT-compatible, and avoids runtime marshalling overhead.
- Requires \`AllowUnsafeBlocks=true\` in the csproj.
- String marshalling: specify \`[LibraryImport("lib", StringMarshalling = StringMarshalling.Utf16)]\`
  explicitly — there is no default.

## NativeLibrary.SetDllImportResolver
- Use for DLLs not on PATH (e.g., VoiceMeeter at "C:\\Program Files (x86)\\VB\\Voicemeeter\\").
- Register in a static constructor or module initializer.
- Look up install paths via Windows Registry (e.g., UninstallString under WOW6432Node).
- Example pattern:
  \`\`\`csharp
  NativeLibrary.SetDllImportResolver(typeof(MyInterop).Assembly, (name, asm, paths) => {
      if (name == "MyLib.dll") {
          string path = GetPathFromRegistry();
          return NativeLibrary.Load(path);
      }
      return IntPtr.Zero;
  });
  \`\`\`

## ConPTY (Windows Pseudo Console) — CRITICAL BUG PATTERN
- \`UpdateProcThreadAttribute\` for \`PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE\`:
  the API expects the HPCON value ITSELF as \`lpValue\`, NOT a pointer to it.
- WRONG: \`ReadOnlySpan<byte>(&hpcHandle)\` — causes double indirection → 0xC0000142 in all child processes.
- RIGHT: \`(void*)hpcHandle\` via raw pointer overload.
- This bug manifests as "all spawned processes exit with 0xC0000142" and looks like a Windows regression
  but is actually a calling convention error.

## Native AOT + Trimming
- Set \`<PublishAot>true</PublishAot>\` and \`<PublishTrimmed>true</PublishTrimmed>\`.
- Set \`<IsAotCompatible>true</IsAotCompatible>\` for libraries.
- Use \`<DisableRuntimeMarshalling>true</DisableRuntimeMarshalling>\` for modern interop
  (avoids the legacy marshalling layer entirely).
- WinUI 3 apps: the WindowsAppSDK auto-initializer conflicts with AOT — may need
  \`<Compile Remove="**\\*AutoInitializer*.cs" />\` in certain contexts.
- COM hosting: \`<EnableComHosting>true</EnableComHosting>\` for COM servers.

## VT Escape Sequence Parsing in C#
- C# string \`"\\x1bE"\` is actually character U+01BE (single char), NOT ESC followed by 'E'.
- Always use string concatenation: \`"\\x1b" + "E"\` for test sequences.
- Colon sub-parameters (\`ESC[38:2:R:G:Bm\`) should be treated as semicolons.
- Erased cells must use current SGR background attributes, not hardcoded defaults.

## IPC Message Patterns
- Use \`System.Text.Json\` with \`[JsonDerivedType]\` for polymorphic IPC messages.
- Length-prefixed framing: concurrent writes from multiple threads can corrupt framing
  without a WriteLock.
- Ensure response messages arrive before any streaming data (e.g., CreateSessionResponse
  must arrive before ScreenUpdate messages).

## Plugin Security
- Path validation: always append \`Path.DirectorySeparatorChar\` to the canonical plugin directory
  before \`StartsWith\` check; otherwise "plugins-evil/" passes validation for "plugins/".
- Shell commands: use \`-EncodedCommand\` with Base64 encoding to prevent PowerShell injection.
- Kill processes after timeout (e.g., 5 seconds for run-shell commands).

## Event Handler Cleanup
- Always unsubscribe event handlers in Close/Dispose methods (ClosePane, CloseWindow,
  DetachClient, etc.) — otherwise disposed objects accumulate and cause leaks/crashes.
`.trim();

const session = await joinSession({
    hooks: {
        onUserPromptSubmitted: async (input) => {
            const prompt = input.prompt.toLowerCase();
            const triggers = [
                "cswin32", "libraryimport", "dllimport", "p/invoke", "pinvoke",
                "nativelibrary", "conpty", "pseudoconsole", "hpcon",
                "nativeaot", "native aot", "publishaot",
                "disableruntimemarshalling", "enablecomhosting",
                "interop", "marshal",
            ];
            if (triggers.some((t) => prompt.includes(t))) {
                return { additionalContext: SKILL_KNOWLEDGE };
            }
        },
    },
    tools: [
        {
            name: "csharp_interop_guidance",
            description:
                "Get domain knowledge about C# native interop: CsWin32, LibraryImport, ConPTY, Native AOT, runtime marshalling, plugin security. Use when working on C# P/Invoke or native interop.",
            parameters: {
                type: "object",
                properties: {
                    topic: {
                        type: "string",
                        description:
                            "The topic: 'cswin32', 'libraryimport', 'conpty', 'nativeaot', 'vt-parsing', 'ipc', 'security', or 'all'",
                        enum: ["cswin32", "libraryimport", "conpty", "nativeaot", "vt-parsing", "ipc", "security", "all"],
                    },
                },
                required: ["topic"],
            },
            handler: async (args) => {
                if (args.topic === "all") return SKILL_KNOWLEDGE;
                const headings = {
                    cswin32: "## CsWin32",
                    libraryimport: "## LibraryImport",
                    conpty: "## ConPTY",
                    nativeaot: "## Native AOT",
                    "vt-parsing": "## VT Escape",
                    ipc: "## IPC Message",
                    security: "## Plugin Security",
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
