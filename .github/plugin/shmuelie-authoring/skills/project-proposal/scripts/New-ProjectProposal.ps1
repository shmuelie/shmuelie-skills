[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string] $BriefPath,

    [Parameter(Mandatory)]
    [string] $Destination,

    [ValidateSet('Compact', 'Split')]
    [string] $Layout = 'Compact',

    [Parameter(DontShow)]
    [string] $TemplateSourceRoot,

    [Parameter(DontShow)]
    [int] $TestFailAfterFileWrites = -1
)

$ErrorActionPreference = 'Stop'
$skillRoot = Split-Path $PSScriptRoot -Parent
$templateSourceRootFull = if ([string]::IsNullOrWhiteSpace($TemplateSourceRoot)) {
    Join-Path $skillRoot 'templates'
}
else {
    [IO.Path]::GetFullPath($TemplateSourceRoot)
}
$templateRoot = Join-Path $templateSourceRootFull $Layout.ToLowerInvariant()
$sharedTemplateRoot = Join-Path $templateSourceRootFull 'shared'
$briefFullPath = [IO.Path]::GetFullPath($BriefPath)
$destinationFullPath = [IO.Path]::GetFullPath($Destination)
$identityPath = Join-Path $destinationFullPath '.project-proposal.json'
$validatorPath = Join-Path $PSScriptRoot 'Test-ProjectProposal.ps1'
$schemaDescriptor = 'project-proposal-v2|strings:projectId,title,summary,problem|text-arrays:audience,verifiedCapabilities,proposals,assumptions,openQuestions,completedWork|object-arrays:decisions(decision,rationale),milestones(name,outcome),risks(risk,mitigation),submission.shortFields(name,value,maxUnits,counting)|submission.body'

function Get-RequiredString {
    param([object] $Object, [string] $Name)

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property -or
        $property.Value -isnot [string] -or
        [string]::IsNullOrWhiteSpace($property.Value)) {
        throw "Brief field '$Name' must be a non-empty string."
    }
    $property.Value
}

function Get-RequiredJsonArray {
    param([object] $Object, [string] $Name)

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property -or $property.Value -isnot [Array]) {
        throw "Brief field '$Name' must be an array."
    }
    @($property.Value)
}

function Get-StringArray {
    param([object] $Object, [string] $Name)

    $items = Get-RequiredJsonArray $Object $Name
    foreach ($item in $items) {
        if ($item -isnot [string] -or [string]::IsNullOrWhiteSpace($item)) {
            throw "Brief field '$Name' must contain only non-empty strings."
        }
    }
    $items
}

function Get-ObjectArray {
    param([object] $Object, [string] $Name)

    $items = Get-RequiredJsonArray $Object $Name
    foreach ($item in $items) {
        if ($item -isnot [pscustomobject]) {
            throw "Brief field '$Name' must contain only objects."
        }
    }
    $items
}

function Get-TextFingerprint {
    param([string] $Value)

    $sha256 = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($Value)
        ([BitConverter]::ToString($sha256.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha256.Dispose()
    }
}

function ConvertTo-MarkdownList {
    param([object[]] $Items, [string] $EmptyText = 'None stated in the brief.')

    if ($Items.Count -eq 0) {
        return "_${EmptyText}_"
    }
    (@($Items | ForEach-Object { "- $([string] $_)" }) -join [Environment]::NewLine)
}

function ConvertTo-MarkdownCell {
    param([object] $Value)

    ([string] $Value).Replace('|', '\|').Replace("`r", ' ').Replace("`n", ' ')
}

function Get-TextUnitCount {
    param(
        [string] $Value,
        [ValidateSet('Utf16CodeUnits', 'Characters', 'Graphemes')]
        [string] $Counting
    )

    if ($Counting -eq 'Utf16CodeUnits') {
        return $Value.Length
    }
    if ($Counting -eq 'Graphemes') {
        return [Globalization.StringInfo]::ParseCombiningCharacters($Value).Count
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

if (-not (Test-Path -LiteralPath $briefFullPath -PathType Leaf)) {
    throw "Brief file not found: $briefFullPath"
}
$brief = Get-Content -LiteralPath $briefFullPath -Raw | ConvertFrom-Json
$projectId = Get-RequiredString $brief 'projectId'
if ($projectId -cnotmatch '^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$') {
    throw "Brief field 'projectId' must be 1-63 lowercase letters, digits, or hyphens."
}

$title = Get-RequiredString $brief 'title'
$summary = Get-RequiredString $brief 'summary'
$problem = Get-RequiredString $brief 'problem'
$audience = Get-StringArray $brief 'audience'
$verified = Get-StringArray $brief 'verifiedCapabilities'
$proposals = Get-StringArray $brief 'proposals'
$assumptions = Get-StringArray $brief 'assumptions'
$openQuestions = Get-StringArray $brief 'openQuestions'
$completedWork = Get-StringArray $brief 'completedWork'
$decisions = Get-ObjectArray $brief 'decisions'
$milestones = Get-ObjectArray $brief 'milestones'
$risks = Get-ObjectArray $brief 'risks'

if ($brief.submission -isnot [pscustomobject]) {
    throw "Brief field 'submission' must be an object."
}
$submissionBody = Get-RequiredString $brief.submission 'body'
$shortFields = Get-ObjectArray $brief.submission 'shortFields'

$decisionLines = @($decisions | ForEach-Object {
        $decision = Get-RequiredString $_ 'decision'
        $rationale = Get-RequiredString $_ 'rationale'
        "**$decision** Rationale: $rationale"
    })
$milestoneLines = @($milestones | ForEach-Object {
        $name = Get-RequiredString $_ 'name'
        $outcome = Get-RequiredString $_ 'outcome'
        "**${name}:** $outcome"
    })
$riskLines = @($risks | ForEach-Object {
        $risk = Get-RequiredString $_ 'risk'
        $mitigation = Get-RequiredString $_ 'mitigation'
        "**Risk:** $risk`n  **Mitigation:** $mitigation"
    })

$fieldRows = @()
$fieldMetadata = @()
foreach ($field in $shortFields) {
    $name = Get-RequiredString $field 'name'
    $value = Get-RequiredString $field 'value'
    $counting = Get-RequiredString $field 'counting'
    if ($counting -notin @('Utf16CodeUnits', 'Characters', 'Graphemes')) {
        throw "Short field '$name' has unsupported counting convention '$counting'."
    }
    $maxUnitsProperty = $field.PSObject.Properties['maxUnits']
    $integralTypes = @(
        [TypeCode]::Byte, [TypeCode]::SByte, [TypeCode]::Int16, [TypeCode]::UInt16,
        [TypeCode]::Int32, [TypeCode]::UInt32, [TypeCode]::Int64, [TypeCode]::UInt64
    )
    if ($null -eq $maxUnitsProperty -or
        [Convert]::GetTypeCode($maxUnitsProperty.Value) -notin $integralTypes -or
        [long] $maxUnitsProperty.Value -lt 1 -or
        [long] $maxUnitsProperty.Value -gt [int]::MaxValue) {
        throw "Short field '$name' must have a positive maxUnits value."
    }
    $maxUnits = [int] $maxUnitsProperty.Value
    $count = Get-TextUnitCount $value $counting
    if ($count -gt $maxUnits) {
        throw "Short field '$name' is $count $counting, exceeding its configured limit of $maxUnits."
    }
    $fieldRows += "| $(ConvertTo-MarkdownCell $name) | $count / $maxUnits | $counting | $(ConvertTo-MarkdownCell $value) |"
    $fieldMetadata += [ordered]@{
        name = $name
        value = $value
        maxUnits = $maxUnits
        counting = $counting
        count = $count
    }
}
$shortFieldTable = if ($fieldRows.Count -eq 0) {
    '_No short fields or limits were supplied in the brief._'
}
else {
    @(
        '| Field | Count / Limit | Convention | Copy |'
        '| --- | ---: | --- | --- |'
        $fieldRows
    ) -join [Environment]::NewLine
}

$tokens = [ordered]@{
    '{{PROJECT_ID}}' = $projectId
    '{{TITLE}}' = $title
    '{{SUMMARY}}' = $summary
    '{{PROBLEM}}' = $problem
    '{{AUDIENCE}}' = ConvertTo-MarkdownList $audience
    '{{VERIFIED_CAPABILITIES}}' = ConvertTo-MarkdownList $verified
    '{{PROPOSALS}}' = ConvertTo-MarkdownList $proposals
    '{{ASSUMPTIONS}}' = ConvertTo-MarkdownList $assumptions
    '{{OPEN_QUESTIONS}}' = ConvertTo-MarkdownList $openQuestions
    '{{COMPLETED_WORK}}' = ConvertTo-MarkdownList $completedWork
    '{{DECISIONS}}' = ConvertTo-MarkdownList $decisionLines
    '{{MILESTONES}}' = ConvertTo-MarkdownList $milestoneLines
    '{{RISKS}}' = ConvertTo-MarkdownList $riskLines
    '{{SHORT_FIELDS}}' = $shortFieldTable
    '{{SUBMISSION_BODY}}' = $submissionBody
}

$templateFiles = @()
$templateFiles += Get-ChildItem -LiteralPath $templateRoot -Filter '*.template' -File
$templateFiles += Get-ChildItem -LiteralPath $sharedTemplateRoot -Filter '*.template' -File
$templateFiles = @($templateFiles | Sort-Object FullName)
$templateFingerprintSource = @($templateFiles | ForEach-Object {
        $relativePath = $_.FullName.Substring($templateSourceRootFull.TrimEnd('\').Length).TrimStart('\')
        "$relativePath`0$(Get-Content -LiteralPath $_.FullName -Raw)`0"
    }) -join ''
$sourceFingerprint = (Get-FileHash -LiteralPath $briefFullPath -Algorithm SHA256).Hash.ToLowerInvariant()
$schemaFingerprint = Get-TextFingerprint $schemaDescriptor
$templateFingerprint = Get-TextFingerprint $templateFingerprintSource
$renderedFiles = [ordered]@{}
foreach ($templateFile in $templateFiles) {
    $content = Get-Content -LiteralPath $templateFile.FullName -Raw
    foreach ($token in $tokens.Keys) {
        $content = $content.Replace($token, [string] $tokens[$token])
    }
    if ($content -match '\{\{[A-Z0-9_]+\}\}') {
        throw "Template '$($templateFile.FullName)' contains an unresolved token."
    }
    $name = $templateFile.BaseName
    $renderedFiles[$name] = $content.TrimEnd() + [Environment]::NewLine
}

$identity = [ordered]@{
    schemaVersion = 2
    projectId = $projectId
    layout = $Layout
    sourceFingerprint = $sourceFingerprint
    schemaFingerprint = $schemaFingerprint
    templateFingerprint = $templateFingerprint
    files = @($renderedFiles.Keys)
    shortFields = $fieldMetadata
}
$identityContent = ($identity | ConvertTo-Json -Depth 8) + [Environment]::NewLine

$destinationExists = Test-Path -LiteralPath $destinationFullPath
if ($destinationExists) {
    if (-not (Test-Path -LiteralPath $destinationFullPath -PathType Container)) {
        throw "Destination exists and is not a directory: $destinationFullPath"
    }
    if (-not (Test-Path -LiteralPath $identityPath -PathType Leaf)) {
        throw "Destination exists but is not an identified project-proposal package: $destinationFullPath"
    }
    $existingIdentity = Get-Content -LiteralPath $identityPath -Raw | ConvertFrom-Json
    if ($existingIdentity.projectId -cne $projectId -or $existingIdentity.layout -ne $Layout) {
        throw "Destination identity conflict: expected '$projectId'/$Layout, found '$($existingIdentity.projectId)'/$($existingIdentity.layout)."
    }
    $fingerprintChanges = @(
        if ($existingIdentity.sourceFingerprint -ne $sourceFingerprint) { 'brief' }
        if ($existingIdentity.schemaFingerprint -ne $schemaFingerprint) { 'schema' }
        if ($existingIdentity.templateFingerprint -ne $templateFingerprint) { 'templates' }
    )
    if ($fingerprintChanges.Count -gt 0) {
        throw "Stale-source conflict for $destinationFullPath ($($fingerprintChanges -join ', ') changed). Existing files are preserved. Deliberately reconcile authored documents and identity metadata, or create a new destination."
    }
}

$planned = @()
if (-not $destinationExists) {
    $planned += $destinationFullPath
}
if (-not (Test-Path -LiteralPath $identityPath)) {
    $planned += $identityPath
}
foreach ($name in $renderedFiles.Keys) {
    $path = Join-Path $destinationFullPath $name
    if (-not (Test-Path -LiteralPath $path)) {
        $planned += $path
    }
}

if ($WhatIfPreference) {
    foreach ($path in $planned) {
        $null = $PSCmdlet.ShouldProcess($path, 'Create proposal artifact')
    }
    return [pscustomobject]@{
        Destination = $destinationFullPath
        ProjectId = $projectId
        Layout = $Layout
        Status = if ($destinationExists) { 'RepairPreview' } else { 'CreatePreview' }
        PlannedWrites = $planned
        PreservedFiles = @($renderedFiles.Keys | Where-Object {
            Test-Path -LiteralPath (Join-Path $destinationFullPath $_)
        })
    }
}

if (-not (Test-Path -LiteralPath (Split-Path $destinationFullPath -Parent) -PathType Container)) {
    throw "Destination parent directory must already exist: $(Split-Path $destinationFullPath -Parent)"
}

$script:ownedWriteCount = 0
function Write-OwnedFile {
    param([string] $Path, [string] $Content)

    $encoding = [Text.UTF8Encoding]::new($false)
    $bytes = $encoding.GetBytes($Content)
    $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $stream.Write($bytes, 0, $bytes.Length)
    }
    finally {
        $stream.Dispose()
    }
    if ([IO.File]::ReadAllText($Path, $encoding) -cne $Content) {
        throw "Failed to verify complete file write: $Path"
    }
    $script:ownedWriteCount++
    if ($TestFailAfterFileWrites -ge 0 -and $script:ownedWriteCount -ge $TestFailAfterFileWrites) {
        throw "Injected proposal write failure after $script:ownedWriteCount file write(s)."
    }
}

$createdFiles = @()
$preservedFiles = @($renderedFiles.Keys | Where-Object {
        Test-Path -LiteralPath (Join-Path $destinationFullPath $_)
    })
$missingFiles = @($renderedFiles.Keys | Where-Object {
        -not (Test-Path -LiteralPath (Join-Path $destinationFullPath $_))
    })

if (-not $destinationExists) {
    if (-not $PSCmdlet.ShouldProcess($destinationFullPath, 'Create complete proposal package atomically')) {
        return
    }
    $parentPath = Split-Path $destinationFullPath -Parent
    $leafName = Split-Path $destinationFullPath -Leaf
    $stagingPath = Join-Path $parentPath ".$leafName.project-proposal-stage-$([guid]::NewGuid().ToString('N'))"
    try {
        $null = New-Item -Path $stagingPath -ItemType Directory
        foreach ($name in $renderedFiles.Keys) {
            Write-OwnedFile (Join-Path $stagingPath $name) $renderedFiles[$name]
        }
        Write-OwnedFile (Join-Path $stagingPath '.project-proposal.json') $identityContent
        $null = & $validatorPath -Path $stagingPath
        [IO.Directory]::Move($stagingPath, $destinationFullPath)
        $createdFiles = @($renderedFiles.Keys)
    }
    finally {
        if (Test-Path -LiteralPath $stagingPath) {
            Remove-Item -LiteralPath $stagingPath -Recurse -Force
        }
    }
}
else {
    foreach ($name in $missingFiles) {
        $path = Join-Path $destinationFullPath $name
        if (-not $PSCmdlet.ShouldProcess($path, 'Repair missing proposal document without replacement')) {
            continue
        }
        $temporaryPath = Join-Path $destinationFullPath ".$name.project-proposal-temp-$([guid]::NewGuid().ToString('N'))"
        try {
            Write-OwnedFile $temporaryPath $renderedFiles[$name]
            [IO.File]::Move($temporaryPath, $path)
            $createdFiles += $name
        }
        finally {
            if (Test-Path -LiteralPath $temporaryPath) {
                Remove-Item -LiteralPath $temporaryPath -Force
            }
        }
    }
}

$validation = & $validatorPath -Path $destinationFullPath
[pscustomobject]@{
    Destination = $destinationFullPath
    ProjectId = $projectId
    Layout = $Layout
    Status = if ($destinationExists -and $createdFiles.Count -gt 0) { 'RepairedAndValidated' }
        elseif ($destinationExists) { 'UnchangedAndValidated' }
        else { 'CreatedAndValidated' }
    CreatedFiles = $createdFiles
    PreservedFiles = $preservedFiles
    ShortFields = $fieldMetadata
    StructurallyReady = $validation.StructurallyReady
}
