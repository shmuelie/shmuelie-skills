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
}
