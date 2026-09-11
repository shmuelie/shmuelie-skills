[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $ScratchRoot,

    [string] $TrimmedRuntimeIdentifier,

    [switch] $KeepArtifacts
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$parent = Get-Item -LiteralPath ([IO.Path]::GetFullPath($ScratchRoot)) -Force -ErrorAction Stop
if ($parent -isnot [IO.DirectoryInfo]) { throw 'ScratchRoot must be an existing disposable parent directory.' }
$ancestor = $parent
while ($null -ne $ancestor) {
    if ($ancestor.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        throw 'ScratchRoot must not traverse a reparse point.'
    }
    $ancestor = $ancestor.Parent
}
$scratch = Join-Path $parent.FullName ('openapi-run-' + [guid]::NewGuid().ToString('N'))
$skillRoot = [IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent))
if ($scratch.StartsWith(
        $skillRoot + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase)) {
    throw 'ScratchRoot must be outside the checked skill directory.'
}

$manifest = Join-Path $PSScriptRoot '.config\dotnet-tools.json'
$project = Join-Path $PSScriptRoot 'OpenApiClientFixture.csproj'
$first = Join-Path $scratch 'first'
$second = Join-Path $scratch 'second'
$baseOutput = (Join-Path $scratch 'build\bin') + [IO.Path]::DirectorySeparatorChar
$baseIntermediateOutput =
    (Join-Path $scratch 'build\obj') + [IO.Path]::DirectorySeparatorChar
$null = New-Item -ItemType Directory -Path $scratch
$completed = $false

function Get-TreeFingerprint([string] $Path) {
    Get-ChildItem $Path -Recurse -File |
        Sort-Object FullName |
        ForEach-Object {
            $relative = [IO.Path]::GetRelativePath($Path, $_.FullName)
            $hash = (Get-FileHash $_.FullName -Algorithm SHA256).Hash
            "$relative`t$hash"
        }
}

try {
    & dotnet tool restore `
        --tool-manifest $manifest `
        --add-source https://api.nuget.org/v3/index.json

    & (Join-Path $PSScriptRoot 'Generate-Client.ps1') -OutputPath $first
    & (Join-Path $PSScriptRoot 'Generate-Client.ps1') -OutputPath $second

    $difference = Compare-Object `
        (Get-TreeFingerprint $first) `
        (Get-TreeFingerprint $second)
    if ($difference) {
        throw "Regeneration was not idempotent:`n$($difference | Out-String)"
    }

    & dotnet build $project `
        --configuration Release `
        --source https://api.nuget.org/v3/index.json `
        "-bl:$(Join-Path $scratch 'build-{}.binlog')" `
        "-p:BaseOutputPath=$baseOutput" `
        "-p:BaseIntermediateOutputPath=$baseIntermediateOutput" `
        "-p:GeneratedClientDir=$first"
    & dotnet (Join-Path $baseOutput 'Release\net10.0\OpenApiClientFixture.dll')

    Write-Host 'PASS: two clean generations have identical paths and SHA-256 hashes'

    if ($TrimmedRuntimeIdentifier) {
        $trimmedOutput =
            (Join-Path $scratch 'trimmed\bin') + [IO.Path]::DirectorySeparatorChar
        $trimmedIntermediate =
            (Join-Path $scratch 'trimmed\obj') + [IO.Path]::DirectorySeparatorChar
        $trimmedPublish = Join-Path $scratch 'trimmed\publish'

        & dotnet publish $project `
            --configuration Release `
            --runtime $TrimmedRuntimeIdentifier `
            --self-contained true `
            --source https://api.nuget.org/v3/index.json `
            "-bl:$(Join-Path $scratch 'publish-{}.binlog')" `
            --output $trimmedPublish `
            -p:PublishTrimmed=true `
            -p:ILLinkTreatWarningsAsErrors=true `
            "-p:BaseOutputPath=$trimmedOutput" `
            "-p:BaseIntermediateOutputPath=$trimmedIntermediate" `
            "-p:GeneratedClientDir=$first"

        $executableName = if ($TrimmedRuntimeIdentifier.StartsWith(
                'win-',
                [StringComparison]::OrdinalIgnoreCase)) {
            'OpenApiClientFixture.exe'
        }
        else {
            'OpenApiClientFixture'
        }
        & (Join-Path $trimmedPublish $executableName)
        Write-Host "PASS: trimmed publish and run for $TrimmedRuntimeIdentifier"
    }
    $completed = $true
}
finally {
    if ($completed -and -not $KeepArtifacts) {
        Remove-Item -LiteralPath $scratch -Recurse -Force
    }
    else {
        Write-Information "Fixture artifacts retained at $scratch" -InformationAction Continue
    }
}
