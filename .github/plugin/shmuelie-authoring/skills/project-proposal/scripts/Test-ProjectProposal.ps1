[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Path
)

$ErrorActionPreference = 'Stop'
$packageRoot = [IO.Path]::GetFullPath($Path)
$identityPath = Join-Path $packageRoot '.project-proposal.json'

function Assert-NotReparsePoint {
    param([string] $ItemPath, [string] $Context)

    $item = Get-Item -LiteralPath $ItemPath -Force
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Reparse-point traversal is not allowed for ${Context}: $ItemPath"
    }
}

if (-not (Test-Path -LiteralPath $packageRoot -PathType Container)) {
    throw "Proposal package not found: $packageRoot"
}
Assert-NotReparsePoint $packageRoot 'proposal package'
if (-not (Test-Path -LiteralPath $identityPath -PathType Leaf)) {
    throw "Proposal identity file not found: $identityPath"
}
Assert-NotReparsePoint $identityPath 'proposal identity'

$identity = Get-Content -LiteralPath $identityPath -Raw | ConvertFrom-Json
if ($identity.schemaVersion -ne 2 -or
    [string]::IsNullOrWhiteSpace([string] $identity.projectId) -or
    $identity.layout -notin @('Compact', 'Split') -or
    $identity.sourceFingerprint -notmatch '^[0-9a-f]{64}$' -or
    $identity.schemaFingerprint -notmatch '^[0-9a-f]{64}$' -or
    $identity.templateFingerprint -notmatch '^[0-9a-f]{64}$') {
    throw "Proposal identity is invalid: $identityPath"
}

$expectedFiles = if ($identity.layout -eq 'Compact') {
    @('README.md', 'PROPOSAL.md', 'SUBMISSION.md')
}
else {
    @('README.md', 'SPEC.md', 'DELIVERY.md', 'RISKS.md', 'SUBMISSION.md')
}
if (@($identity.files).Count -ne $expectedFiles.Count -or
    @($expectedFiles | Where-Object { $_ -notin @($identity.files) }).Count -gt 0) {
    throw "Identity file list does not match the $($identity.layout) layout."
}

$documents = [ordered]@{}
foreach ($name in $expectedFiles) {
    $documentPath = Join-Path $packageRoot $name
    if (-not (Test-Path -LiteralPath $documentPath -PathType Leaf)) {
        throw "Expected proposal document is missing: $documentPath"
    }
    Assert-NotReparsePoint $documentPath "proposal document '$name'"
    $content = Get-Content -LiteralPath $documentPath -Raw
    if ($content.Length -lt 120) {
        throw "Proposal document is not substantive enough for structural review: $documentPath"
    }
    if ($content -match '(?im)\b(?:TODO|TBD)\b|<replace[^>]*>|\{\{[A-Z0-9_]+\}\}') {
        throw "Proposal document contains an unresolved placeholder: $documentPath"
    }
    $documents[$name] = $content
}

$readme = $documents['README.md']
if ($readme -notmatch 'No prototype, repository, event entry, portal\s+record, or submission is claimed' -or
    $readme -notmatch 'Structural readiness does not establish\s+feasibility or implementation') {
    throw 'README.md must distinguish the local package from implementation and submission.'
}
$submission = $documents['SUBMISSION.md']
if ($submission -notmatch 'Nothing was sent to a portal or event' -or
    $submission -notmatch 'Feasibility, implementation, eligibility, and\s+acceptance remain unverified') {
    throw 'SUBMISSION.md must retain local-draft and unverified-status language.'
}

$requiredHeadings = if ($identity.layout -eq 'Compact') {
    @{
        'PROPOSAL.md' = @(
            '## Capability Classification',
            '### Verified Capabilities',
            '### Proposals',
            '### Assumptions',
            '### Open Questions',
            '### Completed Work',
            '## Specification',
            '## Decisions',
            '## Delivery Milestones',
            '## Risks'
        )
    }
}
else {
    @{
        'SPEC.md' = @(
            '## Capability Classification',
            '### Verified Capabilities',
            '### Proposals',
            '### Assumptions',
            '### Open Questions',
            '### Completed Work',
            '## Proposed Behavior',
            '## Decisions'
        )
        'DELIVERY.md' = @('## Delivery Milestones', '## Completed Work')
        'RISKS.md' = @('## Risks and Mitigations', '## Assumptions to Validate')
    }
}
foreach ($name in $requiredHeadings.Keys) {
    foreach ($heading in $requiredHeadings[$name]) {
        if ($documents[$name] -notmatch "(?m)^$([regex]::Escape($heading))\s*$") {
            throw "$name is missing required heading '$heading'."
        }
    }
}

function Get-TextUnitCount {
    param([string] $Value, [string] $Counting)

    if ($Counting -eq 'Utf16CodeUnits') {
        return $Value.Length
    }
    if ($Counting -eq 'Graphemes') {
        return [Globalization.StringInfo]::ParseCombiningCharacters($Value).Count
    }
    if ($Counting -ne 'Characters') {
        throw "Unsupported counting convention '$Counting' in package identity."
    }
    $count = $Value.Length
    for ($index = 0; $index -lt ($Value.Length - 1); $index++) {
        if ([char]::IsHighSurrogate($Value[$index]) -and
            [char]::IsLowSurrogate($Value[$index + 1])) {
            $count--
            $index++
        }
    }
    $count
}

$fieldResults = @()
foreach ($field in @($identity.shortFields)) {
    $fieldName = ([string] $field.name).Replace('|', '\|')
    $fieldPattern = "(?m)^\|\s*$([regex]::Escape($fieldName))\s*\|\s*(\d+)\s*/\s*(\d+)\s*\|\s*([A-Za-z0-9]+)\s*\|\s*(.*?)\s*\|\r?$"
    $fieldMatch = [regex]::Match($submission, $fieldPattern)
    if (-not $fieldMatch.Success) {
        throw "SUBMISSION.md is missing configured short field '$($field.name)'."
    }
    $displayedCount = [int] $fieldMatch.Groups[1].Value
    $displayedLimit = [int] $fieldMatch.Groups[2].Value
    $displayedCounting = $fieldMatch.Groups[3].Value
    $authoredValue = $fieldMatch.Groups[4].Value.Replace('\|', '|')
    if ($displayedLimit -ne [int] $field.maxUnits -or
        $displayedCounting -ne [string] $field.counting) {
        throw "SUBMISSION.md changed the configured limit or counting convention for short field '$($field.name)'."
    }
    $actualCount = Get-TextUnitCount $authoredValue $displayedCounting
    if ($actualCount -ne $displayedCount) {
        throw "SUBMISSION.md shows an incorrect count for short field '$($field.name)'."
    }
    if ($actualCount -gt $displayedLimit) {
        throw "Short field '$($field.name)' exceeds its configured limit."
    }
    $fieldResults += [pscustomobject]@{
        Name = $field.name
        Count = $actualCount
        Limit = $displayedLimit
        Counting = $displayedCounting
    }
}

$rootPrefix = $packageRoot.TrimEnd(
    [IO.Path]::DirectorySeparatorChar,
    [IO.Path]::AltDirectorySeparatorChar
) + [IO.Path]::DirectorySeparatorChar

function Get-HeadingAnchors {
    param([string] $Content)

    $anchors = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $occurrences = @{}
    foreach ($match in [regex]::Matches($Content, '(?m)^\s{0,3}#{1,6}\s+(.+?)\s*#*\s*$')) {
        $base = $match.Groups[1].Value.ToLowerInvariant()
        $base = [regex]::Replace($base, '[^\p{L}\p{Nd}\s_-]', '')
        $base = [regex]::Replace($base.Trim(), '\s+', '-')
        $base = [regex]::Replace($base, '-{2,}', '-')
        if ([string]::IsNullOrWhiteSpace($base)) {
            throw 'Unsupported Markdown heading: unable to derive a local fragment anchor.'
        }
        $index = if ($occurrences.ContainsKey($base)) { [int] $occurrences[$base] + 1 } else { 0 }
        $occurrences[$base] = $index
        $anchor = if ($index -eq 0) { $base } else { "$base-$index" }
        $null = $anchors.Add($anchor)
    }
    return ,$anchors
}

function Resolve-SafeLocalTarget {
    param([string] $SourceName, [string] $RelativePath)

    if ($RelativePath -match '^(?:\\\\[?.]\\|[/\\])' -or
        [IO.Path]::IsPathRooted($RelativePath) -or
        $RelativePath -match '^[A-Za-z][A-Za-z0-9+.-]*:') {
        throw "Rooted, device, and non-HTTP URI paths are not allowed in ${SourceName}: $RelativePath"
    }
    if ($RelativePath.Contains('?')) {
        throw "Unsupported local link query in ${SourceName}: $RelativePath"
    }
    $segments = @($RelativePath -split '[/\\]')
    if ($segments.Count -eq 0 -or @($segments | Where-Object { $_ -in @('', '.', '..') }).Count -gt 0) {
        throw "Local link traversal is not allowed in ${SourceName}: $RelativePath"
    }
    $targetPath = [IO.Path]::GetFullPath((Join-Path $packageRoot $RelativePath))
    if (-not $targetPath.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Local link escapes the proposal package in ${SourceName}: $RelativePath"
    }

    $currentPath = $packageRoot
    foreach ($segment in $segments) {
        $currentPath = Join-Path $currentPath $segment
        if (-not (Test-Path -LiteralPath $currentPath)) {
            throw "Broken local link in ${SourceName}: $RelativePath"
        }
        Assert-NotReparsePoint $currentPath "local link in '$SourceName'"
    }
    if (-not (Test-Path -LiteralPath $targetPath -PathType Leaf)) {
        throw "Local link must target a file in ${SourceName}: $RelativePath"
    }
    $targetPath
}

$documentByPath = @{}
foreach ($name in $documents.Keys) {
    $documentByPath[[IO.Path]::GetFullPath((Join-Path $packageRoot $name))] = $documents[$name]
}

$localLinks = 0
$externalLinks = 0
foreach ($name in $documents.Keys) {
    $content = $documents[$name]
    if ($content -match '!\[' -or $content -match '<https?://') {
        throw "Unsupported Markdown link construct in ${name}; use simple inline or full/collapsed reference links."
    }

    $references = @{}
    foreach ($candidate in [regex]::Matches($content, '(?m)^\s{0,3}\[[^\]\r\n]+\]:.*$')) {
        $definition = [regex]::Match($candidate.Value, '^\s{0,3}\[([^\]\r\n]+)\]:\s*(\S+)\s*$')
        if (-not $definition.Success) {
            throw "Unsupported Markdown reference definition in ${name}: $($candidate.Value.Trim())"
        }
        $label = $definition.Groups[1].Value.Trim().ToLowerInvariant()
        if ($references.ContainsKey($label)) {
            throw "Duplicate Markdown reference label in ${name}: $label"
        }
        $references[$label] = $definition.Groups[2].Value
    }

    $links = @()
    foreach ($candidate in [regex]::Matches($content, '(?<!!)\[[^\]\r\n]+\]\([^)\r\n]*\)')) {
        $inline = [regex]::Match($candidate.Value, '^\[([^\]\r\n]+)\]\(([^()\s]+)\)$')
        if (-not $inline.Success) {
            throw "Unsupported Markdown inline link in ${name}: $($candidate.Value)"
        }
        $links += $inline.Groups[2].Value
    }
    foreach ($candidate in [regex]::Matches($content, '(?<!!)\[[^\]\r\n]+\]\[[^\]\r\n]*\]')) {
        $reference = [regex]::Match($candidate.Value, '^\[([^\]\r\n]+)\]\[([^\]\r\n]*)\]$')
        $label = if ([string]::IsNullOrWhiteSpace($reference.Groups[2].Value)) {
            $reference.Groups[1].Value.Trim().ToLowerInvariant()
        }
        else {
            $reference.Groups[2].Value.Trim().ToLowerInvariant()
        }
        if (-not $references.ContainsKey($label)) {
            throw "Undefined Markdown reference label in ${name}: $label"
        }
        $links += $references[$label]
    }
    foreach ($label in $references.Keys) {
        $shortcutPattern = "(?im)(?<!!)(?<!\])\[$([regex]::Escape($label))\](?!\s*(?:\(|\[|:))"
        foreach ($shortcut in [regex]::Matches($content, $shortcutPattern)) {
            $links += $references[$label]
        }
    }

    foreach ($target in $links) {
        if ($target -match '^(?i:https?)://') {
            $externalLinks++
            continue
        }
        if ($target -match '^[A-Za-z][A-Za-z0-9+.-]*:') {
            throw "Unsupported external link scheme in ${name}: $target"
        }

        $parts = $target -split '#', 2
        $relativeTarget = [Uri]::UnescapeDataString($parts[0])
        $fragment = if ($parts.Count -eq 2) { [Uri]::UnescapeDataString($parts[1]) } else { $null }
        if ([string]::IsNullOrWhiteSpace($relativeTarget)) {
            if ($null -eq $fragment) {
                throw "Empty local link in ${name}."
            }
            $targetPath = [IO.Path]::GetFullPath((Join-Path $packageRoot $name))
        }
        else {
            $targetPath = Resolve-SafeLocalTarget $name $relativeTarget
        }

        if ($null -ne $fragment) {
            if ([string]::IsNullOrWhiteSpace($fragment)) {
                throw "Empty local fragment in ${name}: $target"
            }
            $targetContent = if ($documentByPath.ContainsKey($targetPath)) {
                $documentByPath[$targetPath]
            }
            elseif ([IO.Path]::GetExtension($targetPath) -ieq '.md') {
                Get-Content -LiteralPath $targetPath -Raw
            }
            else {
                throw "Local fragments require a Markdown target in ${name}: $target"
            }
            $anchors = Get-HeadingAnchors $targetContent
            if (-not $anchors.Contains($fragment)) {
                throw "Broken local fragment in ${name}: $target"
            }
        }
        $localLinks++
    }
}

[pscustomobject]@{
    Path = $packageRoot
    ProjectId = $identity.projectId
    Layout = $identity.layout
    StructurallyReady = $true
    Assessment = 'Structurally ready; feasibility and implementation remain unverified.'
    Documents = $expectedFiles
    ShortFields = $fieldResults
    LocalLinksChecked = $localLinks
    ExternalLinksNotFetched = $externalLinks
}
