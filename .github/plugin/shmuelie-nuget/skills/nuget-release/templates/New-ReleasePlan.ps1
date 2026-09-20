#Requires -Version 7.4
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Project,
    [Parameter(Mandatory)][string]$ChangelogPath,
    [Parameter(Mandatory)][string]$ArtifactDirectory,
    [Parameter(Mandatory)][string]$Repository,
    [Parameter(Mandatory)][string]$EventName,
    [Parameter(Mandatory)][string]$Ref,
    [Parameter(Mandatory)][string]$Commit
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Release.Common.ps1')
$raw = & dotnet msbuild $Project -nologo -p:Configuration=Release -getProperty:PackageVersion,PackageId
if ($LASTEXITCODE -ne 0) { throw 'Failed to evaluate package properties.' }
$properties = ($raw -join "`n" | ConvertFrom-Json).Properties
$plan = New-LibraryReleasePlan -Repository $Repository -EventName $EventName -Ref $Ref -Commit $Commit `
    -ProjectVersion $properties.PackageVersion -PackageId $properties.PackageId `
    -Changelog ([IO.File]::ReadAllText((Resolve-Path -LiteralPath $ChangelogPath))) -ArtifactDirectory $ArtifactDirectory
$planPath = Join-Path $ArtifactDirectory 'release-plan.json'
if (Test-Path -LiteralPath $planPath) { throw 'A release plan already exists; inspect the original attempt.' }
$plan | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $planPath -Encoding utf8
$plan.Notes | Set-Content -LiteralPath (Join-Path $ArtifactDirectory 'release-notes.md') -Encoding utf8
$names = @($plan.Artifacts.Name) + @('release-plan.json', 'release-notes.md')
$sums = foreach ($name in $names) { "$((Get-FileHash -LiteralPath (Join-Path $ArtifactDirectory $name)).Hash.ToLowerInvariant())  $name" }
$sums | Set-Content -LiteralPath (Join-Path $ArtifactDirectory 'SHA256SUMS') -Encoding utf8
Write-Host "Validated $($plan.PackageId) $($plan.Version) at $($plan.Commit); no publication performed."
