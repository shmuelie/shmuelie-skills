import { joinSession } from "@github/copilot-sdk/extension";

const SKILL_KNOWLEDGE = `
# .NET Project Initialization — Domain Knowledge

## Directory.Build.props (Centralized Build Config)
- Place at repo root to share settings across all projects.
- Common properties to centralize:
  \`\`\`xml
  <Project>
    <PropertyGroup>
      <TargetFramework>net10.0-windows</TargetFramework>
      <Nullable>enable</Nullable>
      <ImplicitUsings>enable</ImplicitUsings>
      <LangVersion>preview</LangVersion>
      <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
    </PropertyGroup>
  </Project>
  \`\`\`
- Use \`<TargetFramework>\` conditions in .targets (not .props) — they silently fail
  for single-targeting projects in .props due to evaluation order.
- For multi-platform apps (x64/ARM64), set \`<Platforms>x64;ARM64</Platforms>\`.
- Set \`<RuntimeIdentifiers>win-x64;win-arm64</RuntimeIdentifiers>\` for platform-specific builds.

## Project Configuration Patterns

### Modern .NET (10+)
- \`global.json\`: Include \`"test": { "runner": "Microsoft.Testing.Platform" }\` for .NET 10+
  test discovery with Microsoft.Testing.Platform runner.
- Test SDK: Use \`Microsoft.NET.Test.Sdk\` + MSTest/xUnit/NUnit + MTP runner package.
- For AOT-compatible projects: \`<IsAotCompatible>true</IsAotCompatible>\`.

### WinUI 3 Projects
- SDK: \`Microsoft.NET.Sdk\` (not \`Microsoft.NET.Sdk.WindowsDesktop\`).
- TFM: \`net10.0-windows10.0.22621\` (or appropriate Windows SDK version).
- \`<UseWinUI>true</UseWinUI>\` enables WinUI 3 support.
- \`<EnableMsixTooling>true</EnableMsixTooling>\` for MSIX packaging.

### Windows Service Projects
- SDK: \`Microsoft.NET.Sdk.Web\` for ASP.NET-based services.
- Add \`Microsoft.Extensions.Hosting.WindowsServices\` for Windows service hosting.

### COM Server Projects
- \`<EnableComHosting>true</EnableComHosting>\` for COM server support.
- Platform-specific builds required (not AnyCPU).

## NuGet Package Patterns
- Plugin projects: use \`<ExcludeAssets>runtime</ExcludeAssets>\` on host framework references
  to avoid bundling the host's assemblies.
- Test projects: full asset inclusion is fine.
- For tools/analyzers: \`PrivateAssets="all"\` prevents transitive dependency.

## CI Workflow Patterns (GitHub Actions)

### .NET Build + Test
\`\`\`yaml
name: CI
on: [push, pull_request]
concurrency:
  group: ci-\${{ github.ref }}
  cancel-in-progress: true
jobs:
  build:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '10.0.x'
      - run: dotnet restore
      - run: dotnet build --no-restore -c Release
      - run: dotnet test --no-build -c Release
\`\`\`

### MSIX-Specific CI
- MSIX builds may require \`msbuild\` instead of \`dotnet build\`.
- Use \`microsoft/setup-msbuild@v2\` action.
- Build with \`-p:Platform=x64\` (or ARM64) — not AnyCPU.
- For tests: \`dotnet test --project Tests.csproj -p:Platform=x64\`.

### Multi-Platform Matrix
\`\`\`yaml
strategy:
  matrix:
    platform: [x64, ARM64]
steps:
  - run: msbuild App.csproj -p:Platform=\${{ matrix.platform }} -p:Configuration=Release
\`\`\`

## copilot-instructions.md Pattern
- Always create \`.github/copilot-instructions.md\` in new repos.
- Include: build/test commands, architecture overview, key conventions, gotchas.
- Update when architecture changes significantly.
`.trim();

const session = await joinSession({
    hooks: {
        onUserPromptSubmitted: async (input) => {
            const prompt = input.prompt.toLowerCase();
            const triggers = [
                "directory.build", "directory.packages",
                "new project", "scaffold", "project init", "project setup",
                "global.json", "ci workflow", "github actions",
                "copilot-instructions",
                "treatwarningsaserrors",
            ];
            if (triggers.some((t) => prompt.includes(t))) {
                return { additionalContext: SKILL_KNOWLEDGE };
            }
        },
    },
    tools: [
        {
            name: "dotnet_project_init_guidance",
            description:
                "Get domain knowledge about .NET project initialization: Directory.Build.props, CI workflows, project scaffolding, copilot-instructions.md. Use when setting up new .NET projects.",
            parameters: {
                type: "object",
                properties: {
                    topic: {
                        type: "string",
                        description:
                            "The topic: 'directory-build', 'project-config', 'nuget', 'ci', 'copilot-instructions', or 'all'",
                        enum: ["directory-build", "project-config", "nuget", "ci", "copilot-instructions", "all"],
                    },
                },
                required: ["topic"],
            },
            handler: async (args) => {
                if (args.topic === "all") return SKILL_KNOWLEDGE;
                const headings = {
                    "directory-build": "## Directory.Build.props",
                    "project-config": "## Project Configuration",
                    nuget: "## NuGet Package",
                    ci: "## CI Workflow",
                    "copilot-instructions": "## copilot-instructions.md",
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
