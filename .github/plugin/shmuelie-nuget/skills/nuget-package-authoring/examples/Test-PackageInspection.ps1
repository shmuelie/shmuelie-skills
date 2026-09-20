#Requires -Version 7.4
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ArtifactDirectory,
    [Parameter(Mandatory)][string]$PolicyPath,
    [Parameter(Mandatory)][string]$Commit,
    [Parameter(Mandatory)][string]$ScratchRoot
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$inspector = Join-Path $PSScriptRoot '..\templates\Test-LibraryPackage.ps1'
$parent = Get-Item -LiteralPath $ScratchRoot
if (-not $parent.PSIsContainer -or $parent.Attributes -band [IO.FileAttributes]::ReparsePoint) {
    throw 'ScratchRoot must be an existing non-link directory.'
}
& $inspector -ArtifactDirectory $ArtifactDirectory -PolicyPath $PolicyPath -Commit $Commit
$work = Join-Path $parent.FullName ('package-inspection-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $work
$passed = $false
$cases = @(
    @{ Name = 'MissingLicense'; Xml = { param($m) $null = $m.RemoveChild($m.license) }; Error = 'Missing or ambiguous package metadata: license' },
    @{ Name = 'WrongLicense'; Xml = { param($m) $m.license.InnerText = 'Apache-2.0' }; Error = 'Package license does not match' },
    @{ Name = 'MissingReadmeMetadata'; Xml = { param($m) $null = $m.RemoveChild($m.SelectSingleNode('*[local-name()="readme"]')) }; Error = 'Missing or ambiguous package metadata: readme' },
    @{ Name = 'MissingReadmeAsset'; Delete = 'README.md'; Error = 'Declared package README is missing' },
    @{ Name = 'MissingAuthors'; Xml = { param($m) $null = $m.RemoveChild($m.SelectSingleNode('*[local-name()="authors"]')) }; Error = 'Missing or ambiguous package metadata: authors' },
    @{ Name = 'MissingDescription'; Xml = { param($m) $null = $m.RemoveChild($m.SelectSingleNode('*[local-name()="description"]')) }; Error = 'Missing or ambiguous package metadata: description' },
    @{ Name = 'WrongRepository'; Xml = { param($m) $m.repository.SetAttribute('url', 'https://github.com/other/source') }; Error = 'Repository metadata does not identify' },
    @{ Name = 'WrongCommit'; Xml = { param($m) $m.repository.SetAttribute('commit', ('0' * 40)) }; Error = 'Repository metadata does not identify' },
    @{ Name = 'UnexpectedDependency'; Xml = {
        param($m)
        $dep = $m.OwnerDocument.CreateElement('dependency', $m.NamespaceURI)
        $dep.SetAttribute('id', 'Unexpected.Runtime')
        $dep.SetAttribute('version', '1.0.0')
        $null = $m.dependencies.group.AppendChild($dep)
    }; Error = 'Dependency exposure differs' },
    @{ Name = 'UnexpectedFrameworkGroup'; Xml = { param($m) $m.dependencies.group.SetAttribute('targetFramework', 'net8.0') }; Error = 'Expected one dependency group' },
    @{ Name = 'MissingXmlDocs'; Delete = 'lib/net10.0/Fixture.Library.xml'; Error = 'Required XML entry is missing' },
    @{ Name = 'MissingAssembly'; Delete = 'lib/net10.0/Fixture.Library.dll'; Error = 'Required package asset is missing' },
    @{ Name = 'MissingSymbols'; Symbols = $true; Delete = 'lib/net10.0/Fixture.Library.pdb'; Error = 'Required package asset is missing' },
    @{ Name = 'MissingSourceLink'; Symbols = $true; RemoveSourceLink = $true; Error = 'Portable PDB has no Source Link record' },
    @{ Name = 'UnmappedSourceLink'; Symbols = $true; UnmappedSourceLink = $true; Error = 'Source Link does not cover non-embedded document' },
    @{ Name = 'UnexpectedNativeAsset'; AddEntry = 'runtimes/linux-x64/native/libUnexpected.so'; Error = 'Unsupported package layout' },
    @{ Name = 'UnexpectedNativeDylib'; AddEntry = 'runtimes/osx-arm64/native/libUnexpected.dylib'; Error = 'Unsupported package layout' },
    @{ Name = 'UnexpectedBuildTarget'; AddEntry = 'build/Unexpected.targets'; Error = 'Unsupported package layout' }
)
try {
    foreach ($case in $cases) {
        $directory = Join-Path $work $case.Name
        $null = New-Item -ItemType Directory -Path $directory
        Get-ChildItem -LiteralPath $ArtifactDirectory -File |
            Where-Object Extension -in '.nupkg', '.snupkg' |
            Copy-Item -Destination $directory
        $extension = if ($case.ContainsKey('Symbols')) { '.snupkg' } else { '.nupkg' }
        $archive = @(Get-ChildItem -LiteralPath $directory -File | Where-Object Extension -eq $extension)[0]
        $zip = [IO.Compression.ZipFile]::Open($archive.FullName, [IO.Compression.ZipArchiveMode]::Update)
        try {
            if ($case.ContainsKey('Xml')) {
                $entry = @($zip.Entries | Where-Object FullName -like '*.nuspec')[0]
                $name = $entry.FullName
                $reader = [IO.StreamReader]::new($entry.Open())
                try { [xml]$xml = $reader.ReadToEnd() } finally { $reader.Dispose() }
                & $case.Xml $xml.package.metadata
                $entry.Delete()
                $writer = [IO.StreamWriter]::new($zip.CreateEntry($name).Open())
                try { $writer.Write($xml.OuterXml) } finally { $writer.Dispose() }
            } elseif ($case.ContainsKey('Delete')) {
                $zip.GetEntry($case.Delete).Delete()
            } elseif ($case.ContainsKey('AddEntry')) {
                $writer = [IO.StreamWriter]::new($zip.CreateEntry($case.AddEntry).Open())
                try { $writer.Write('Undeclared asset') } finally { $writer.Dispose() }
            } else {
                $entry = $zip.GetEntry('lib/net10.0/Fixture.Library.pdb')
                $memory = [IO.MemoryStream]::new()
                $stream = $entry.Open()
                try { $stream.CopyTo($memory); $bytes = $memory.ToArray() }
                finally { $stream.Dispose(); $memory.Dispose() }
                $needle = if ($case.ContainsKey('UnmappedSourceLink')) {
                    [Text.Encoding]::UTF8.GetBytes('"documents":{"/_/*"')
                } else { ([guid]'CC110556-A091-4D38-9FEC-25AB9A351A6A').ToByteArray() }
                $found = $false
                for ($i = 0; $i -le $bytes.Length - $needle.Length; $i++) {
                    if ([Linq.Enumerable]::SequenceEqual([byte[]]$bytes[$i..($i + $needle.Length - 1)], [byte[]]$needle)) {
                        if ($case.ContainsKey('UnmappedSourceLink')) {
                            $bytes[$i + $needle.Length - 4] = [byte][char]'x'
                        } else { $bytes[$i] = $bytes[$i] -bxor 1 }
                        $found = $true
                        break
                    }
                }
                if (-not $found) { throw 'Test fixture has no expected Source Link bytes to mutate.' }
                $entry.Delete()
                $stream = $zip.CreateEntry('lib/net10.0/Fixture.Library.pdb').Open()
                try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
            }
        } finally { $zip.Dispose() }
        $caught = $null
        try { & $inspector -ArtifactDirectory $directory -PolicyPath $PolicyPath -Commit $Commit }
        catch { $caught = $_ }
        if ($null -eq $caught -or -not $caught.Exception.Message.Contains($case.Error, [StringComparison]::Ordinal)) {
            throw "Inspection case $($case.Name) did not reject the intended defect: $caught"
        }
        Write-Host "PASS PackageInspection/$($case.Name)"
    }
    $passed = $true
    Write-Host "Package inspection passed: valid archives plus $($cases.Count) negative cases; no network or publication."
} finally {
    if ($passed) { Remove-Item -LiteralPath $work -Recurse -Force }
    else { Write-Host "Inspection fixtures retained at $work" }
}
