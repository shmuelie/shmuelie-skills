#Requires -Version 7.4
[CmdletBinding()]
param([Parameter(Mandatory)][string]$ScratchRoot, [switch]$KeepArtifacts)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$parent = Get-Item -LiteralPath $ScratchRoot
if (-not $parent.PSIsContainer -or $parent.Attributes -band [IO.FileAttributes]::ReparsePoint) {
    throw 'ScratchRoot must be an existing non-link directory.'
}
$work = Join-Path $parent.FullName ("library-fixture-" + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $work
$oldCache = $env:NUGET_PACKAGES
$passed = $false
function Invoke-Checked {
    param([string]$Program, [string[]]$Arguments)
    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Program failed (exit $LASTEXITCODE)." }
}
try {
    foreach ($directory in 'src', 'tests', 'consumer') {
        # Copy source only, never stale builds from a prior local run.
        foreach ($file in Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot $directory) -Recurse -File |
            Where-Object { $_.FullName -notmatch '[\\/](bin|obj|TestResults)[\\/]' }) {
            $relative = [IO.Path]::GetRelativePath($PSScriptRoot, $file.FullName)
            $destination = Join-Path $work $relative
            $null = New-Item -ItemType Directory -Force -Path (Split-Path $destination)
            Copy-Item -LiteralPath $file.FullName -Destination $destination
        }
    }
    foreach ($name in 'global.json', 'Directory.Build.props', 'CHANGELOG.md', 'package-policy.json') {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination $work
    }
    $env:NUGET_PACKAGES = Join-Path $work '.packages'
    Push-Location $work
    try {
        Invoke-Checked git @('init', '--quiet')
        Invoke-Checked git @('config', 'user.name', 'Fixture')
        Invoke-Checked git @('config', 'user.email', 'fixture@example.invalid')
        Invoke-Checked git @('remote', 'add', 'origin', 'https://github.com/example/library.git')
        Invoke-Checked git @('add', '.')
        Invoke-Checked git @('-c', 'commit.gpgsign=false', 'commit', '--quiet', '-m', 'Synthetic local fixture')
        $commit = (& git rev-parse HEAD).Trim()
        if ($LASTEXITCODE -ne 0) { throw 'Could not obtain fixture commit.' }
        Invoke-Checked dotnet @('test', 'tests/Fixture.Library.Tests/Fixture.Library.Tests.csproj', '-c', 'Release', '--nologo')
        Invoke-Checked dotnet @('pack', 'src/Fixture.Library/Fixture.Library.csproj', '-c', 'Release', '-o', 'artifacts',
            '-p:ContinuousIntegrationBuild=true', "-p:RepositoryCommit=$commit")
        $releaseTools = Join-Path $PSScriptRoot '..\..\nuget-release\templates'
        . (Join-Path $releaseTools 'Release.Common.ps1')
        & (Join-Path $releaseTools 'New-ReleasePlan.ps1') -Project 'src/Fixture.Library/Fixture.Library.csproj' `
            -ChangelogPath 'CHANGELOG.md' -ArtifactDirectory 'artifacts' -Repository 'example/library' `
            -EventName push -Ref 'refs/tags/v0.1.0' -Commit $commit
        $inspection = Join-Path $PSScriptRoot '..\..\nuget-package-authoring\examples\Test-PackageInspection.ps1'
        & $inspection -ArtifactDirectory (Join-Path $work 'artifacts') -PolicyPath (Join-Path $work 'package-policy.json') `
            -Commit $commit -ScratchRoot $work
        Invoke-Checked dotnet @('restore', 'consumer/Fixture.Consumer/Fixture.Consumer.csproj', '--source', (Join-Path $work 'artifacts'))
        Invoke-Checked dotnet @('run', '--project', 'consumer/Fixture.Consumer/Fixture.Consumer.csproj', '-c', 'Release', '--no-restore')
        $plan = Get-Content artifacts\release-plan.json -Raw | ConvertFrom-Json
        $result = Invoke-LibraryRelease -Plan $plan -ArtifactDirectory (Join-Path $work 'artifacts') -WhatIf `
            -Transport { throw 'A WhatIf fixture must never call the transport.' }
        if ($result.Status -ne 'NotPublished') { throw 'WhatIf returned an unexpected status.' }
        $passed = $true
        Write-Host 'Fixture passed: tests, pack, metadata, local package consumer, and no-publication WhatIf.'
    } finally { Pop-Location }
} finally {
    $env:NUGET_PACKAGES = $oldCache
    if ($passed -and -not $KeepArtifacts) { Remove-Item -LiteralPath $work -Recurse -Force }
    else { Write-Host "Fixture artifacts retained at $work" }
}
