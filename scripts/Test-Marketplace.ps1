[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent

foreach ($json in Get-ChildItem $repoRoot -Recurse -Filter '*.json' -File) {
    Get-Content $json.FullName -Raw | ConvertFrom-Json | Out-Null
}

$marketplace = Get-Content (Join-Path $repoRoot '.github\plugin\marketplace.json') -Raw | ConvertFrom-Json
foreach ($entry in $marketplace.plugins) {
    $pluginRoot = if ($entry.source -eq '.') { $repoRoot } else { Join-Path $repoRoot $entry.source }
    $manifest = Get-Content (Join-Path $pluginRoot 'plugin.json') -Raw | ConvertFrom-Json
    if ($manifest.name -ne $entry.name) {
        throw "Marketplace name '$($entry.name)' does not match manifest '$($manifest.name)'."
    }
    if ($manifest.version -ne $entry.version) {
        throw "Version mismatch for $($entry.name): marketplace $($entry.version), manifest $($manifest.version)."
    }
    foreach ($skillsPath in $manifest.skills) {
        if (-not (Test-Path (Join-Path $pluginRoot $skillsPath))) {
            throw "Missing skills path '$skillsPath' for $($entry.name)."
        }
    }
    if ($entry.source -ne '.') {
        $readmePath = Join-Path $pluginRoot 'README.md'
        $readme = Get-Content $readmePath -Raw
        if ($readme -notmatch '\*\*Version:\*\*\s+([0-9]+\.[0-9]+\.[0-9]+)') {
            throw "Missing README version for $($entry.name)."
        }
        if ($Matches[1] -ne $manifest.version) {
            throw "README version mismatch for $($entry.name): README $($Matches[1]), manifest $($manifest.version)."
        }
    }
}

foreach ($skill in Get-ChildItem $repoRoot -Recurse -Filter 'SKILL.md' -File) {
    $content = Get-Content $skill.FullName -Raw
    if ($content -notmatch '\A---\r?\n(?s:.*?)\r?\n---\r?\n') {
        throw "Missing YAML frontmatter: $($skill.FullName)"
    }
    if ($content -notmatch '(?m)^name:\s*[a-z0-9-]+\s*$') {
        throw "Invalid or missing skill name: $($skill.FullName)"
    }
    if ($content -notmatch '(?m)^description:\s*.+$') {
        throw "Missing skill description: $($skill.FullName)"
    }
    $skillChangelog = Join-Path $skill.DirectoryName 'CHANGELOG.md'
    if (-not (Test-Path $skillChangelog)) {
        throw "Each skill must have its own CHANGELOG.md: missing $skillChangelog"
    }
}

if (Test-Path (Join-Path $repoRoot 'skills')) {
    throw 'Root skills/ is not allowed; every skill must belong to a focused plugin.'
}

$focusedSkills = Get-ChildItem (Join-Path $repoRoot '.github\plugin') -Directory |
    ForEach-Object { Get-ChildItem (Join-Path $_.FullName 'skills') -Directory -ErrorAction SilentlyContinue }
$duplicates = $focusedSkills | Group-Object Name | Where-Object Count -gt 1
if ($duplicates) {
    throw "Skills must have one focused owner. Duplicates: $($duplicates.Name -join ', ')"
}

# Reverse check 1: every plugin directory on disk must have a marketplace entry.
$marketplaceNames = @($marketplace.plugins.name)
Get-ChildItem (Join-Path $repoRoot '.github\plugin') -Directory |
    Where-Object { Test-Path (Join-Path $_.FullName 'plugin.json') } |
    ForEach-Object {
        $diskManifest = Get-Content (Join-Path $_.FullName 'plugin.json') -Raw | ConvertFrom-Json
        if ($diskManifest.name -notin $marketplaceNames) {
            throw "Plugin directory '$($_.Name)' has a plugin.json but no marketplace entry."
        }
    }

# Reverse check 2: the aggregate plugin's skills must equal the union of the
# focused plugins' skills directories, so adding/removing a focused plugin can
# never leave the aggregate out of sync.
$aggregateEntry = @($marketplace.plugins | Where-Object { $_.source -eq '.' })
if ($aggregateEntry.Count -ne 1) {
    throw "Expected exactly one aggregate plugin (source '.') in the marketplace; found $($aggregateEntry.Count)."
}
$aggregateManifest = Get-Content (Join-Path $repoRoot 'plugin.json') -Raw | ConvertFrom-Json
$aggregateSkillPaths = @($aggregateManifest.skills | ForEach-Object { $_.TrimEnd('/').Replace('\', '/') })
$focusedSkillPaths = @(
    $marketplace.plugins |
        Where-Object { $_.source -ne '.' } |
        ForEach-Object { "$($_.source)/skills".Replace('\', '/') }
)
$missingFromAggregate = @($focusedSkillPaths | Where-Object { $_ -notin $aggregateSkillPaths })
$extraInAggregate = @($aggregateSkillPaths | Where-Object { $_ -notin $focusedSkillPaths })
if ($missingFromAggregate -or $extraInAggregate) {
    throw ("Aggregate plugin skills must equal the union of focused plugin skills. " +
        "Missing: $($missingFromAggregate -join ', '); Unexpected: $($extraInAggregate -join ', ').")
}

foreach ($docFile in @('index.md', 'installation.md', 'plugins.md', 'contributing.md', '_config.yml')) {
    if (-not (Test-Path (Join-Path $repoRoot "docs\$docFile"))) {
        throw "Missing documentation site file: docs/$docFile"
    }
}

if (Get-ChildItem (Join-Path $repoRoot 'docs') -Filter '*.html' -File -ErrorAction SilentlyContinue) {
    throw 'Documentation must be authored in Markdown; remove HTML files from docs/.'
}

$markdownFiles = @()
$markdownFiles += Get-Item (Join-Path $repoRoot 'README.md')
$markdownFiles += Get-ChildItem (Join-Path $repoRoot '.github\plugin') -Recurse -Filter 'README.md' -File
$markdownFiles += Get-ChildItem (Join-Path $repoRoot '.github\plugin') -Recurse -Filter 'CHANGELOG.md' -File
$markdownFiles += Get-ChildItem (Join-Path $repoRoot 'docs') -Filter '*.md' -File
foreach ($markdown in $markdownFiles) {
    $content = Get-Content $markdown.FullName -Raw
    foreach ($match in [regex]::Matches($content, '\[[^\]]*\]\(([^)]+)\)')) {
        $target = $match.Groups[1].Value.Trim()
        if ($target -match '^(?:https?:|mailto:|#)') { continue }
        $localPath = ($target -split '#', 2)[0]
        if ($localPath -and -not (Test-Path (Join-Path $markdown.DirectoryName $localPath))) {
            throw "Broken local link in $($markdown.FullName): $target"
        }
    }
}

# Every changelog (repository, per-skill) must carry an [Unreleased] section, so
# content changes land there instead of forcing a version bump between releases.
$changelogs = @()
$changelogs += Get-Item (Join-Path $repoRoot 'CHANGELOG.md')
$changelogs += Get-ChildItem (Join-Path $repoRoot '.github\plugin') -Recurse -Filter 'CHANGELOG.md' -File
foreach ($changelog in $changelogs) {
    if ((Get-Content $changelog.FullName -Raw) -notmatch '(?m)^##\s*\[Unreleased\]') {
        throw "Changelog is missing an [Unreleased] section: $($changelog.FullName)"
    }
}

