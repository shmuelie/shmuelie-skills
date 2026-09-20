#Requires -Version 7.4
Set-StrictMode -Version Latest

function ConvertTo-ReleaseVersion {
    param([Parameter(Mandatory)][string]$Value)
    if ($Value -cnotmatch '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?$') {
        throw "Not a canonical release version: $Value"
    }
    try { return [System.Management.Automation.SemanticVersion]::Parse($Value) }
    catch [System.FormatException] { throw "Not a canonical release version: $Value" }
}

function Read-PackageIdentity {
    param([Parameter(Mandatory)][string]$Path)
    $zip = [IO.Compression.ZipFile]::OpenRead($Path)
    try {
        $entries = @($zip.Entries | Where-Object FullName -like '*.nuspec')
        if ($entries.Count -ne 1) { throw 'Package must contain exactly one nuspec.' }
        $settings = [Xml.XmlReaderSettings]::new()
        $settings.DtdProcessing = [Xml.DtdProcessing]::Prohibit
        $stream = $entries[0].Open()
        $reader = [Xml.XmlReader]::Create($stream, $settings)
        try {
            $xml = [Xml.XmlDocument]::new()
            $xml.XmlResolver = $null
            $xml.Load($reader)
        } finally { $reader.Dispose(); $stream.Dispose() }
        $metadata = $xml.SelectSingleNode('/*[local-name()="package"]/*[local-name()="metadata"]')
        if ($null -eq $metadata) { throw 'Package metadata is missing.' }
        $id = $metadata.SelectSingleNode('*[local-name()="id"]')
        $version = $metadata.SelectSingleNode('*[local-name()="version"]')
        $repository = $metadata.SelectSingleNode('*[local-name()="repository"]')
        if ($null -eq $id -or $null -eq $version -or $null -eq $repository) {
            throw 'Package id, version, and repository metadata are required.'
        }
        [pscustomobject]@{
            Id = $id.InnerText
            Version = $version.InnerText
            Commit = $repository.GetAttribute('commit')
            Entries = @($zip.Entries.FullName)
        }
    } finally { $zip.Dispose() }
}

function New-LibraryReleasePlan {
    param(
        [Parameter(Mandatory)][string]$Repository,
        [Parameter(Mandatory)][string]$EventName,
        [Parameter(Mandatory)][string]$Ref,
        [Parameter(Mandatory)][string]$Commit,
        [Parameter(Mandatory)][string]$ProjectVersion,
        [Parameter(Mandatory)][string]$PackageId,
        [Parameter(Mandatory)][string]$Changelog,
        [Parameter(Mandatory)][string]$ArtifactDirectory
    )
    if ($Repository -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') { throw 'Invalid repository.' }
    if ($EventName -cne 'push' -or -not $Ref.StartsWith('refs/tags/v', [StringComparison]::Ordinal)) {
        throw 'Only a version-tag push may publish.'
    }
    if ($Commit -cnotmatch '^[0-9a-f]{40}$') { throw 'Expected the exact source commit SHA.' }
    if ($PackageId -notmatch '^[A-Za-z0-9_][A-Za-z0-9_.-]*$') { throw 'Invalid package ID.' }
    $tag = $Ref.Substring('refs/tags/'.Length)
    $version = $tag.Substring(1)
    $parsed = ConvertTo-ReleaseVersion $version
    $null = ConvertTo-ReleaseVersion $ProjectVersion
    if ($ProjectVersion -cne $version) { throw 'Tag and evaluated project version differ.' }
    $pattern = '(?m)^## \[' + [regex]::Escape($version) + '\] - (\d{4}-\d{2}-\d{2})\r?$'
    $headers = [regex]::Matches($Changelog, $pattern)
    if ($headers.Count -ne 1) { throw 'Expected exactly one dated changelog section for the version.' }
    $null = [DateTime]::ParseExact($headers[0].Groups[1].Value, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
    $notes = $Changelog.Substring($headers[0].Index + $headers[0].Length)
    $next = [regex]::Match($notes, '(?m)^## ')
    if ($next.Success) { $notes = $notes.Substring(0, $next.Index) }
    if ([string]::IsNullOrWhiteSpace($notes)) { throw 'Release notes are empty.' }
    $packages = @(Get-ChildItem -LiteralPath $ArtifactDirectory -File | Where-Object Extension -in '.nupkg', '.snupkg')
    if ($packages.Count -ne 2) { throw 'Expected one nupkg and its snupkg, and no other packages.' }
    $artifacts = foreach ($extension in '.nupkg', '.snupkg') {
        $name = "$PackageId.$version$extension"
        $file = $packages | Where-Object Name -ceq $name
        if ($null -eq $file) { throw "Missing expected artifact: $name" }
        $identity = Read-PackageIdentity $file.FullName
        if ($identity.Id -cne $PackageId -or $identity.Version -cne $version -or $identity.Commit -cne $Commit) {
            throw "Package identity/provenance mismatch: $name"
        }
        if ($extension -eq '.snupkg' -and -not @($identity.Entries | Where-Object { $_ -like '*.pdb' }).Count) {
            throw 'The symbol package contains no PDB.'
        }
        [pscustomobject]@{ Name = $name; Sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
    }
    [pscustomobject]@{
        SchemaVersion = 1; Repository = $Repository; Tag = $tag; Version = $version
        Commit = $Commit; PackageId = $PackageId; Prerelease = -not [string]::IsNullOrEmpty($parsed.PreReleaseLabel)
        Notes = $notes.Trim(); Artifacts = @($artifacts)
    }
}

function Test-ReleaseIsLatest {
    param([Parameter(Mandatory)][string]$Version, [string[]]$PublishedStableVersions = @())
    $candidate = ConvertTo-ReleaseVersion $Version
    if ($candidate.PreReleaseLabel) { return $false }
    foreach ($other in $PublishedStableVersions) {
        $stable = ConvertTo-ReleaseVersion $other
        if ($stable.PreReleaseLabel) { throw 'Stable release list contains a prerelease.' }
        if ($stable -ge $candidate) { return $false }
    }
    return $true
}

function Assert-ReleaseArtifacts {
    param([Parameter(Mandatory)]$Plan, [Parameter(Mandatory)][string]$ArtifactDirectory)
    if (($Plan.SchemaVersion -isnot [int] -and $Plan.SchemaVersion -isnot [long]) -or $Plan.SchemaVersion -ne 1) {
        throw 'Unsupported release plan schema.'
    }
    $parsed = ConvertTo-ReleaseVersion $Plan.Version
    if ($Plan.Prerelease -isnot [bool] -or $Plan.Prerelease -ne (-not [string]::IsNullOrEmpty($parsed.PreReleaseLabel))) {
        throw 'Invalid prerelease flag.'
    }
    if ($Plan.Tag -cne "v$($Plan.Version)" -or $Plan.Commit -cnotmatch '^[0-9a-f]{40}$' -or
        $Plan.Repository -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' -or
        $Plan.PackageId -notmatch '^[A-Za-z0-9_][A-Za-z0-9_.-]*$') { throw 'Invalid release plan identity.' }
    if (@($Plan.Artifacts).Count -ne 2) { throw 'Expected two package artifacts.' }
    foreach ($extension in '.nupkg', '.snupkg') {
        $name = "$($Plan.PackageId).$($Plan.Version)$extension"
        $entry = @($Plan.Artifacts | Where-Object Name -ceq $name)
        if ($entry.Count -ne 1 -or $entry[0].Sha256 -cnotmatch '^[a-f0-9]{64}$') { throw 'Invalid artifact manifest.' }
        $file = Get-Item -LiteralPath (Join-Path $ArtifactDirectory $name)
        if ($file.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Artifact links are not allowed.' }
        if ((Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant() -cne $entry[0].Sha256) {
            throw "Artifact checksum mismatch: $name"
        }
        $identity = Read-PackageIdentity $file.FullName
        if ($identity.Id -cne $Plan.PackageId -or $identity.Version -cne $Plan.Version -or $identity.Commit -cne $Plan.Commit) {
            throw "Artifact provenance mismatch: $name"
        }
    }
}

function Invoke-LibraryRelease {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)]$Plan,
        [Parameter(Mandatory)][string]$ArtifactDirectory,
        [Parameter(Mandatory)][scriptblock]$Transport
    )
    Assert-ReleaseArtifacts $Plan $ArtifactDirectory
    if (-not $PSCmdlet.ShouldProcess("$($Plan.Repository) $($Plan.Tag)", 'Stage artifacts and publish NuGet/GitHub release')) {
        return [pscustomobject]@{ Status = 'NotPublished'; Completed = @() }
    }
    $completed = [Collections.Generic.List[string]]::new()
    foreach ($step in 'Preflight', 'CreateDraft', 'UploadAssets', 'VerifyAssets', 'PushPackage', 'PushSymbols', 'PublishRelease', 'VerifyRelease') {
        try { $null = & $Transport $step $Plan $ArtifactDirectory }
        catch { throw "Release failed at $step. Completed: $($completed -join ', '). Keep original artifacts and draft for explicit recovery. $($_.Exception.Message)" }
        $completed.Add($step)
    }
    [pscustomobject]@{ Status = 'Published'; Completed = $completed.ToArray() }
}
