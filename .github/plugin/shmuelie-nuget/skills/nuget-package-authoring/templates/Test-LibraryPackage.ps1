#Requires -Version 7.4
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ArtifactDirectory,
    [Parameter(Mandatory)][string]$PolicyPath,
    [Parameter(Mandatory)][string]$Commit
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$policy = Get-Content -LiteralPath $PolicyPath -Raw | ConvertFrom-Json
if ($policy.packageId -notmatch '^[A-Za-z0-9_][A-Za-z0-9_.-]*$' -or
    $policy.repository -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' -or
    $Commit -cnotmatch '^[0-9a-f]{40}$') { throw 'Invalid package policy or source commit.' }
if (@($policy.frameworks).Count -eq 0) { throw 'Package policy must declare supported frameworks.' }
$packages = @(Get-ChildItem -LiteralPath $ArtifactDirectory -File -Filter '*.nupkg')
$symbols = @(Get-ChildItem -LiteralPath $ArtifactDirectory -File -Filter '*.snupkg')
if ($packages.Count -ne 1 -or $symbols.Count -ne 1) { throw 'Inspect exactly one package and its symbol package.' }

function Read-ZipXml {
    param($Entry)
    if ($null -eq $Entry) { throw 'Required XML entry is missing.' }
    $settings = [Xml.XmlReaderSettings]::new()
    $settings.DtdProcessing = [Xml.DtdProcessing]::Prohibit
    $stream = $Entry.Open()
    $reader = [Xml.XmlReader]::Create($stream, $settings)
    try {
        $xml = [Xml.XmlDocument]::new()
        $xml.XmlResolver = $null
        $xml.Load($reader)
        return ,$xml
    } finally { $reader.Dispose(); $stream.Dispose() }
}

function Get-RequiredMetadata {
    param($Metadata, [string]$Name)
    $nodes = @($Metadata.SelectNodes("*[local-name()='$Name']"))
    if ($nodes.Count -ne 1 -or [string]::IsNullOrWhiteSpace($nodes[0].InnerText)) {
        throw "Missing or ambiguous package metadata: $Name"
    }
    return $nodes[0].InnerText
}

function Read-ZipBytes {
    param($Entry)
    if ($null -eq $Entry -or $Entry.Length -eq 0) { throw 'Required package asset is missing or empty.' }
    $memory = [IO.MemoryStream]::new()
    $stream = $Entry.Open()
    try { $stream.CopyTo($memory); $memory.Position = 0; return ,$memory }
    catch { $memory.Dispose(); throw }
    finally { $stream.Dispose() }
}

$package = [IO.Compression.ZipFile]::OpenRead($packages[0].FullName)
$symbolPackage = [IO.Compression.ZipFile]::OpenRead($symbols[0].FullName)
try {
    foreach ($zip in $package, $symbolPackage) {
        if (@($zip.Entries | Group-Object FullName -CaseSensitive | Where-Object Count -gt 1).Count) {
            throw 'Duplicate package entries are not allowed.'
        }
        if (@($zip.Entries | Where-Object {
            $_.FullName.Replace('\', '/') -match '^(runtimes|native|ref|analyzers|build|buildTransitive|buildMultiTargeting|content|contentFiles|tools)/'
        }).Count) { throw 'Unsupported package layout: the policy permits ordinary pure-managed library assets only.' }
    }
    $nuspecs = @($package.Entries | Where-Object FullName -like '*.nuspec')
    if ($nuspecs.Count -ne 1) { throw 'Expected one package nuspec.' }
    $xml = Read-ZipXml $nuspecs[0]
    $metadata = $xml.SelectSingleNode('/*[local-name()="package"]/*[local-name()="metadata"]')
    if ($null -eq $metadata) { throw 'Package metadata is missing.' }
    $id = Get-RequiredMetadata $metadata 'id'
    $version = Get-RequiredMetadata $metadata 'version'
    $null = Get-RequiredMetadata $metadata 'authors'
    $null = Get-RequiredMetadata $metadata 'description'
    if ($id -cne $policy.packageId) { throw 'Package ID does not match the reviewed policy.' }
    $readme = Get-RequiredMetadata $metadata 'readme'
    if ($null -eq $package.GetEntry($readme) -or $package.GetEntry($readme).Length -eq 0) {
        throw 'Declared package README is missing or empty.'
    }
    $license = Get-RequiredMetadata $metadata 'license'
    $licenseNode = $metadata.SelectSingleNode('*[local-name()="license"]')
    if ($licenseNode.GetAttribute('type') -cne $policy.license.type -or $license -cne $policy.license.value) {
        throw 'Package license does not match the reviewed policy.'
    }
    if ($policy.license.type -ceq 'file') {
        if ($null -eq $package.GetEntry($license) -or $package.GetEntry($license).Length -eq 0) { throw 'Declared license file is missing.' }
    } elseif ($policy.license.type -cne 'expression') { throw 'Unsupported license policy.' }
    $repository = $metadata.SelectSingleNode('*[local-name()="repository"]')
    if ($null -eq $repository -or $repository.GetAttribute('type') -cne 'git' -or
        $repository.GetAttribute('commit') -cne $Commit -or
        $repository.GetAttribute('url').TrimEnd('/') -cnotin @("https://github.com/$($policy.repository)", "https://github.com/$($policy.repository).git")) {
        throw 'Repository metadata does not identify the reviewed source.'
    }
    $symbolSpecs = @($symbolPackage.Entries | Where-Object FullName -like '*.nuspec')
    if ($symbolSpecs.Count -ne 1) { throw 'Expected one symbol nuspec.' }
    $symbolXml = Read-ZipXml $symbolSpecs[0]
    $symbolMetadata = $symbolXml.SelectSingleNode('/*[local-name()="package"]/*[local-name()="metadata"]')
    if ((Get-RequiredMetadata $symbolMetadata 'id') -cne $id -or (Get-RequiredMetadata $symbolMetadata 'version') -cne $version) {
        throw 'Symbol package identity differs from the library.'
    }

    $expectedDlls = [Collections.Generic.List[string]]::new()
    $groups = @($metadata.SelectNodes('*[local-name()="dependencies"]/*[local-name()="group"]'))
    if (@($metadata.SelectNodes('*[local-name()="dependencies"]/*[local-name()="dependency"]')).Count) {
        throw 'Use explicit framework dependency groups.'
    }
    $seenFrameworks = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($framework in $policy.frameworks) {
        if ($framework.tfm -notmatch '^[A-Za-z0-9.-]+$' -or -not $seenFrameworks.Add($framework.tfm) -or @($framework.assemblies).Count -eq 0) {
            throw 'Invalid, duplicate, or empty framework policy.'
        }
        $matching = @($groups | Where-Object { $_.GetAttribute('targetFramework') -ceq $framework.tfm })
        if ($matching.Count -ne 1) { throw "Expected one dependency group for $($framework.tfm)." }
        $actualDependencies = @($matching[0].SelectNodes('*[local-name()="dependency"]') | ForEach-Object {
            "$($_.GetAttribute('id'))|$($_.GetAttribute('version'))|$($_.GetAttribute('include'))|$($_.GetAttribute('exclude'))"
        })
        $expectedDependencies = @($framework.dependencies | ForEach-Object { "$($_.id)|$($_.version)|$($_.include)|$($_.exclude)" })
        if ((($actualDependencies | Sort-Object -CaseSensitive) -join "`n") -cne (($expectedDependencies | Sort-Object -CaseSensitive) -join "`n")) {
            throw "Dependency exposure differs from the policy for $($framework.tfm)."
        }
        foreach ($assembly in $framework.assemblies) {
            if ($assembly -notmatch '^[A-Za-z0-9_.-]+$') { throw 'Invalid assembly name in policy.' }
            $base = "lib/$($framework.tfm)/$assembly"
            $expectedDlls.Add("$base.dll")
            $dllStream = Read-ZipBytes $package.GetEntry("$base.dll")
            $pe = [Reflection.PortableExecutable.PEReader]::new($dllStream)
            try {
                $codeViews = @($pe.ReadDebugDirectory() | Where-Object Type -eq CodeView)
                if ($codeViews.Count -ne 1) { throw 'Assembly must identify one portable PDB.' }
                $pdbGuid = $pe.ReadCodeViewDebugDirectoryData($codeViews[0]).Guid
            } finally { $pe.Dispose(); $dllStream.Dispose() }
            $doc = Read-ZipXml $package.GetEntry("$base.xml")
            if ($doc.doc.assembly.name -cne $assembly -or @($doc.SelectNodes('/doc/members/member')).Count -eq 0) {
                throw "Public XML documentation is missing for $assembly."
            }
            $pdbStream = Read-ZipBytes $symbolPackage.GetEntry("$base.pdb")
            $provider = [Reflection.Metadata.MetadataReaderProvider]::FromPortablePdbStream($pdbStream)
            try {
                $reader = $provider.GetMetadataReader()
                if ([guid]::new([byte[]]@($reader.DebugMetadataHeader.Id[0..15])) -ne $pdbGuid) {
                    throw 'Symbols do not match the packaged assembly.'
                }
                $found = $false
                foreach ($handle in $reader.CustomDebugInformation) {
                    $info = $reader.GetCustomDebugInformation($handle)
                    if ($reader.GetGuid($info.Kind) -eq [guid]'CC110556-A091-4D38-9FEC-25AB9A351A6A') {
                        $link = [Text.Encoding]::UTF8.GetString($reader.GetBlobBytes($info.Value)) | ConvertFrom-Json
                        $urls = @($link.documents.PSObject.Properties.Value)
                        $prefix = "https://raw.githubusercontent.com/$($policy.repository)/$Commit/"
                        if ($urls.Count -eq 0 -or @($urls | Where-Object { $_ -isnot [string] -or -not $_.StartsWith($prefix, [StringComparison]::Ordinal) }).Count) {
                            throw 'Source Link does not identify the reviewed source commit.'
                        }
                        $mappings = @($link.documents.PSObject.Properties)
                        foreach ($mapping in $mappings) {
                            $keyStars = @($mapping.Name.ToCharArray() | Where-Object { $_ -eq '*' }).Count
                            $urlStars = @($mapping.Value.ToCharArray() | Where-Object { $_ -eq '*' }).Count
                            if ($keyStars -gt 1 -or $keyStars -ne $urlStars -or
                                ($keyStars -eq 1 -and (-not $mapping.Name.EndsWith('*') -or -not $mapping.Value.EndsWith('*')))) {
                                throw 'Unsupported Source Link mapping pattern.'
                            }
                        }
                        foreach ($documentHandle in $reader.Documents) {
                            $embedded = $false
                            foreach ($customHandle in $reader.GetCustomDebugInformation([Reflection.Metadata.EntityHandle]$documentHandle)) {
                                $custom = $reader.GetCustomDebugInformation($customHandle)
                                if ($reader.GetGuid($custom.Kind) -eq [guid]'0E8A571B-6926-466E-B4AD-8AB04611F5FE') { $embedded = $true }
                            }
                            if ($embedded) { continue }
                            $document = $reader.GetDocument($documentHandle)
                            $name = $reader.GetString($document.Name)
                            $covered = @($mappings | Where-Object {
                                if ($_.Name.EndsWith('*')) {
                                    $name.StartsWith($_.Name.Substring(0, $_.Name.Length - 1), [StringComparison]::Ordinal)
                                } else { $name -ceq $_.Name }
                            }).Count -gt 0
                            if (-not $covered) { throw "Source Link does not cover non-embedded document: $name" }
                        }
                        $found = $true
                    }
                }
                if (-not $found) { throw 'Portable PDB has no Source Link record.' }
            } finally { $provider.Dispose(); $pdbStream.Dispose() }
        }
    }
    if ($groups.Count -ne $seenFrameworks.Count) { throw 'Unexpected dependency framework groups.' }
    $actualDlls = @($package.Entries.FullName | Where-Object { $_ -clike '*.dll' })
    if ((($actualDlls | Sort-Object -CaseSensitive) -join "`n") -cne (($expectedDlls | Sort-Object -CaseSensitive) -join "`n")) {
        throw 'Framework/assembly assets differ from the reviewed policy.'
    }
    Write-Host "Package inspection passed: $id $version; metadata, frameworks, dependencies, documentation, symbols, and Source Link."
} finally { $symbolPackage.Dispose(); $package.Dispose() }
