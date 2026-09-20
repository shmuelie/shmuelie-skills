#Requires -Version 7.4
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param([Parameter(Mandatory)][string]$ArtifactDirectory)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Release.Common.ps1')
$ArtifactDirectory = (Resolve-Path -LiteralPath $ArtifactDirectory).Path
$plan = Get-Content -LiteralPath (Join-Path $ArtifactDirectory 'release-plan.json') -Raw | ConvertFrom-Json
Assert-ReleaseArtifacts $plan $ArtifactDirectory
if ($plan.Repository -cne $env:GITHUB_REPOSITORY -or $plan.Repository -cne $env:RELEASE_REPOSITORY -or
    $plan.Commit -cne $env:GITHUB_SHA -or $env:GITHUB_EVENT_NAME -cne 'push' -or
    $env:GITHUB_REF -cne "refs/tags/$($plan.Tag)") { throw 'Publication context does not match the approved release plan.' }
if ($plan.PackageId -like 'ShmuelieSkills.Fixture.*' -or $plan.Repository -like 'example/*') {
    throw 'Replace the fictional fixture identity before configuring publication.'
}
$assetNames = @($plan.Artifacts.Name) + @('release-plan.json', 'release-notes.md', 'SHA256SUMS')
$expectedHashes = @{}
foreach ($name in $assetNames) {
    $file = Get-Item -LiteralPath (Join-Path $ArtifactDirectory $name)
    if ($file.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Asset links are not allowed.' }
    $expectedHashes[$name] = (Get-FileHash -LiteralPath $file.FullName).Hash
}
if (-not $PSCmdlet.ShouldProcess("$($plan.Repository) $($plan.Tag)", 'Publish the validated release')) { return }
if ([string]::IsNullOrWhiteSpace($env:NUGET_API_KEY)) { throw 'A short-lived NuGet API key (or explicitly configured alternative) is required.' }

function Invoke-Gh {
    param([string[]]$Arguments)
    $output = & gh @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) { throw "GitHub operation failed (exit $LASTEXITCODE): $($output -join "`n")" }
    return ($output -join "`n")
}

function Assert-RemoteTag {
    param($CurrentPlan)
    $reference = Invoke-Gh @('api', "repos/$($CurrentPlan.Repository)/git/ref/tags/$($CurrentPlan.Tag)") | ConvertFrom-Json
    $target = $reference.object
    for ($depth = 0; $target.type -eq 'tag' -and $depth -lt 10; $depth++) {
        $target = (Invoke-Gh @('api', "repos/$($CurrentPlan.Repository)/git/tags/$($target.sha)") | ConvertFrom-Json).object
    }
    if ($target.type -ne 'commit' -or $target.sha -cne $CurrentPlan.Commit) { throw 'Remote tag does not resolve to the validated commit.' }
}

$state = @{ Latest = $false }
$transport = {
    param($step, $current, $directory)
    switch ($step) {
        'Preflight' {
            Assert-RemoteTag $current
            $pages = Invoke-Gh @('api', '--paginate', '--slurp', "repos/$($current.Repository)/releases?per_page=100") | ConvertFrom-Json -NoEnumerate
            $releases = @($pages | ForEach-Object { foreach ($release in $_) { $release } })
            if (@($releases | Where-Object tag_name -ceq $current.Tag).Count) { throw 'Release/draft already exists; use explicit recovery.' }
            $stable = @($releases | Where-Object { -not $_.draft -and -not $_.prerelease } | ForEach-Object {
                if (-not $_.tag_name.StartsWith('v', [StringComparison]::Ordinal)) { throw 'Existing release tags require an explicit latest-version policy.' }
                $_.tag_name.Substring(1)
            })
            $state.Latest = Test-ReleaseIsLatest $current.Version $stable
            $uri = "https://api.nuget.org/v3-flatcontainer/$($current.PackageId.ToLowerInvariant())/index.json"
            $response = Invoke-WebRequest -Uri $uri -SkipHttpErrorCheck -TimeoutSec 30
            if ([int]$response.StatusCode -eq 200) {
                if ($current.Version -in ($response.Content | ConvertFrom-Json).versions) { throw 'NuGet version already exists; inspect the previous attempt.' }
            } elseif ([int]$response.StatusCode -ne 404) { throw "NuGet preflight failed: HTTP $($response.StatusCode)." }
        }
        'CreateDraft' {
            Assert-RemoteTag $current
            $null = Invoke-Gh @('release', 'create', $current.Tag, '--repo', $current.Repository, '--verify-tag', '--draft',
                '--title', $current.Tag, '--notes-file', (Join-Path $directory 'release-notes.md'))
        }
        'UploadAssets' {
            $paths = @($assetNames | ForEach-Object { Join-Path $directory $_ })
            $null = Invoke-Gh (@('release', 'upload', $current.Tag, '--repo', $current.Repository) + $paths)
        }
        'VerifyAssets' {
            $temp = [IO.Directory]::CreateTempSubdirectory('nuget-release-verify-')
            try {
                foreach ($name in $assetNames) {
                    $null = Invoke-Gh @('release', 'download', $current.Tag, '--repo', $current.Repository,
                        '--pattern', $name, '--dir', $temp.FullName)
                    if ((Get-FileHash -LiteralPath (Join-Path $temp.FullName $name)).Hash -cne $expectedHashes[$name]) {
                        throw "Uploaded asset differs: $name"
                    }
                }
            } finally {
                # This directory was allocated by this invocation, never supplied by a caller.
                Remove-Item -LiteralPath $temp.FullName -Recurse -Force
            }
        }
        { $_ -in 'PushPackage', 'PushSymbols' } {
            Assert-RemoteTag $current
            Assert-ReleaseArtifacts $current $directory
            $extension = if ($step -eq 'PushPackage') { '.nupkg' } else { '.snupkg' }
            $path = Join-Path $directory "$($current.PackageId).$($current.Version)$extension"
            $pushArgs = @('nuget', 'push', $path, '--source', 'https://api.nuget.org/v3/index.json', '--api-key', $env:NUGET_API_KEY)
            if ($step -eq 'PushPackage') { $pushArgs += '--no-symbols' }
            & dotnet @pushArgs
            if ($LASTEXITCODE -ne 0) { throw "$step failed (exit $LASTEXITCODE); no duplicate-skipping or rollback attempted." }
        }
        'PublishRelease' {
            Assert-RemoteTag $current
            $args = @('release', 'edit', $current.Tag, '--repo', $current.Repository, '--draft=false',
                "--prerelease=$($current.Prerelease.ToString().ToLowerInvariant())",
                "--latest=$($state.Latest.ToString().ToLowerInvariant())")
            $null = Invoke-Gh $args
        }
        'VerifyRelease' {
            $result = Invoke-Gh @('release', 'view', $current.Tag, '--repo', $current.Repository, '--json', 'tagName,isDraft,isPrerelease,assets') | ConvertFrom-Json
            if ($result.isDraft -or $result.isPrerelease -ne $current.Prerelease -or $result.tagName -cne $current.Tag) {
                throw 'Published release state did not match the plan.'
            }
            if (@(Compare-Object @($result.assets.name) $assetNames).Count) { throw 'Published asset set did not match the plan.' }
        }
        default { throw "Unknown publication step: $step" }
    }
}
Invoke-LibraryRelease -Plan $plan -ArtifactDirectory $ArtifactDirectory -Transport $transport -Confirm:$false
