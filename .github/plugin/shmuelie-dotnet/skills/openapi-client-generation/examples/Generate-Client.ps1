[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $OutputPath
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$exampleRoot = $PSScriptRoot
$skillRoot = Split-Path $exampleRoot -Parent
$original = Join-Path $exampleRoot 'openapi.original.yaml'
$enriched = Join-Path $exampleRoot 'openapi.enriched.yaml'
$fullOutputPath = [IO.Path]::GetFullPath($OutputPath)

if ($fullOutputPath -eq [IO.Path]::GetFullPath($skillRoot) -or $fullOutputPath.StartsWith(
        [IO.Path]::GetFullPath($skillRoot) + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Generated output must be outside the checked skill directory.'
}
if (Test-Path -LiteralPath $fullOutputPath) {
    throw 'OutputPath must not already exist; generation never cleans an existing directory.'
}
$ancestor = Get-Item -LiteralPath (Split-Path $fullOutputPath -Parent) -Force -ErrorAction Stop
while ($null -ne $ancestor) {
    if ($ancestor.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        throw 'OutputPath must not traverse a reparse point.'
    }
    $ancestor = $ancestor.Parent
}

$normalizedCommand = @(
    'dotnet tool run kiota'
    '--'
    'generate --language CSharp --class-name WidgetApiClient'
    '--namespace-name OpenApiClientFixture.Generated'
    '--openapi openapi.enriched.yaml --output <OUTPUT>'
    '--exclude-backward-compatible'
) -join ' '
$coreRuntimeVersion = & dotnet --list-runtimes |
    ForEach-Object {
        if ($_ -match '^Microsoft\.NETCore\.App\s+(10\.\d+\.\d+)\s') {
            [Version] $Matches[1]
        }
    } |
    Sort-Object -Descending |
    Select-Object -First 1
if (-not $coreRuntimeVersion) {
    throw 'Microsoft.NETCore.App 10.x is required by this fixture.'
}

Push-Location $exampleRoot
try {
    & dotnet tool run kiota -- `
        generate `
        --language CSharp `
        --class-name WidgetApiClient `
        --namespace-name OpenApiClientFixture.Generated `
        --openapi $enriched `
        --output $fullOutputPath `
        --exclude-backward-compatible

    $toolVersion = (& dotnet tool run kiota -- --version |
        Select-Object -Last 1).Trim()
}
finally {
    Pop-Location
}

$provenance = [ordered]@{
    generator = 'Microsoft.OpenApi.Kiota'
    generatorVersion = $toolVersion
    sdkVersion = (& dotnet --version).Trim()
    targetFramework = 'net10.0'
    installedRuntimeCandidate = $coreRuntimeVersion.ToString()
    runtimePackage = 'Microsoft.Kiota.Bundle'
    runtimePackageVersion = '2.0.0'
    originalInput = 'openapi.original.yaml'
    originalSha256 = (Get-FileHash $original -Algorithm SHA256).Hash.ToLowerInvariant()
    enrichedInput = 'openapi.enriched.yaml'
    enrichedSha256 = (Get-FileHash $enriched -Algorithm SHA256).Hash.ToLowerInvariant()
    command = $normalizedCommand
}

$provenance | ConvertTo-Json |
    Set-Content (Join-Path $fullOutputPath 'provenance.json') -Encoding utf8NoBOM
